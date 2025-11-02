import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station.dart';

/// 前景服務任務處理器
/// 在背景持續監控多個站點資料
@pragma('vm:entry-point')
class UbikeMonitorTaskHandler extends TaskHandler {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  List<Station> _monitoredStations = [];
  Map<String, int> _lastYb2Counts = {}; // station_no -> yb2_count
  Map<String, int> _lastEybCounts = {}; // station_no -> eyb_count
  int _threshold = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('前景服務已啟動');
    await _notificationService.initialize();
    await _loadSettings();
  }

  /// 載入設定
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _threshold = prefs.getInt('threshold') ?? 0;

    // 載入所有監控站點
    final stationsJson = prefs.getStringList('monitored_stations') ?? [];
    _monitoredStations = [];

    for (var jsonStr in stationsJson) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final station = Station.fromStationListJson(json);
        _monitoredStations.add(station);

        // 載入該站點的上次車輛數
        final lastYb2 = prefs.getInt('last_yb2_${station.stationNo}');
        final lastEyb = prefs.getInt('last_eyb_${station.stationNo}');

        if (lastYb2 != null) {
          _lastYb2Counts[station.stationNo] = lastYb2;
        }
        if (lastEyb != null) {
          _lastEybCounts[station.stationNo] = lastEyb;
        }
      } catch (e) {
        print('載入站點資訊失敗: $e');
      }
    }

    print('載入設定: 監控站點數=${_monitoredStations.length}, 門檻=$_threshold');
    for (var station in _monitoredStations) {
      print('  - ${station.stationName} (${station.stationNo}): YB2=${_lastYb2Counts[station.stationNo]}, EYB=${_lastEybCounts[station.stationNo]}');
    }
  }

  /// 儲存單一站點的上次車輛數
  Future<void> _saveLastBikeCounts(String stationNo, int yb2, int eyb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_yb2_$stationNo', yb2);
    await prefs.setInt('last_eyb_$stationNo', eyb);
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (_monitoredStations.isEmpty) {
      print('沒有監控任何站點');
      return;
    }

    print('檢查 ${_monitoredStations.length} 個站點資料');

    try {
      // 批次取得所有站點詳細資訊
      final stationNos = _monitoredStations.map((s) => s.stationNo).toList();
      final baseStationsMap = {
        for (var s in _monitoredStations) s.stationNo: s
      };

      final detailsMap = await _apiService.fetchMultipleStationDetails(
        stationNos,
        baseStationsMap,
      );

      if (detailsMap.isEmpty) {
        print('無法取得任何站點詳細資料');
        return;
      }

      // 準備批次更新資料給 UI
      final List<Map<String, dynamic>> stationUpdates = [];
      final List<Map<String, dynamic>> notificationUpdates = []; // 收集需要推播的變化
      final List<String> stationSummaries = []; // 用於前景服務通知的站點摘要
      int totalBikes = 0;
      int totalEmptySpaces = 0;

      // 檢查每個站點是否有變化
      for (var stationNo in detailsMap.keys) {
        final station = detailsMap[stationNo];
        if (station == null || station.availableSpaces == null) {
          continue;
        }

        final currentYb2 = station.availableSpaces!.yb2;
        final currentEyb = station.availableSpaces!.eyb;
        final currentTotal = station.availableSpaces!.total;
        final currentEmpty = station.emptySpaces ?? 0;

        totalBikes += currentTotal;
        totalEmptySpaces += currentEmpty;

        // 建立站點摘要（前3個站點）
        if (stationSummaries.length < 3) {
          stationSummaries.add('${station.stationName}: $currentTotal台');
        }

        print('${station.stationName}: YB2=$currentYb2, EYB=$currentEyb, 總計=$currentTotal');

        // 檢查是否需要收集到推播通知中
        final lastYb2 = _lastYb2Counts[stationNo];
        final lastEyb = _lastEybCounts[stationNo];

        if (lastYb2 != null && lastEyb != null) {
          final yb2Changed = lastYb2 != currentYb2;
          final eybChanged = lastEyb != currentEyb;

          if ((yb2Changed || eybChanged) && currentTotal >= _threshold) {
            // 收集變化資訊
            notificationUpdates.add({
              'stationName': station.stationName,
              'yb2Change': currentYb2 - lastYb2,
              'eybChange': currentEyb - lastEyb,
              'totalChange': currentTotal - (lastYb2 + lastEyb),
            });
            print('記錄變化: ${station.stationName} YB2: $lastYb2→$currentYb2, EYB: $lastEyb→$currentEyb');
          }
        }

        // 更新快取的車輛數
        _lastYb2Counts[stationNo] = currentYb2;
        _lastEybCounts[stationNo] = currentEyb;
        await _saveLastBikeCounts(stationNo, currentYb2, currentEyb);

        // 加入 UI 更新資料
        stationUpdates.add({
          'station_no': station.stationNo,
          'yb2': currentYb2,
          'eyb': currentEyb,
          'empty_spaces': station.emptySpaces,
        });
      }

      // 發送整合的推播通知（如果有任何變化）
      if (notificationUpdates.isNotEmpty) {
        await _notificationService.sendConsolidatedUpdateNotification(
          updates: notificationUpdates,
        );
        print('已發送整合通知，包含 ${notificationUpdates.length} 個站點的變化');
      }

      // 建構前景服務通知內容
      String notificationTitle;
      String notificationText;

      if (_monitoredStations.length == 1) {
        // 單一站點：顯示站點名稱
        notificationTitle = '監控: ${_monitoredStations[0].stationName}';
        notificationText = '🚲 $totalBikes 台 | 🅿️ $totalEmptySpaces 位';
      } else if (_monitoredStations.length <= 3) {
        // 2-3個站點：顯示簡短列表
        notificationTitle = '監控 ${_monitoredStations.length} 個站點';
        notificationText = stationSummaries.join(' | ');
      } else {
        // 4個以上：顯示統計資訊
        notificationTitle = '監控 ${_monitoredStations.length} 個站點';
        notificationText = '🚲 $totalBikes 台 | 🅿️ $totalEmptySpaces 位';
      }

      // 更新前景服務通知內容
      FlutterForegroundTask.updateService(
        notificationTitle: notificationTitle,
        notificationText: notificationText,
      );

      // 批次發送資料到 UI
      if (stationUpdates.isNotEmpty) {
        FlutterForegroundTask.sendDataToMain({
          'stations': stationUpdates,
        });
      }

      print('完成檢查，已更新 ${stationUpdates.length} 個站點${notificationUpdates.isNotEmpty ? '，發送了包含 ${notificationUpdates.length} 個變化的整合通知' : ''}');
    } catch (e) {
      print('檢查站點時發生錯誤: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('前景服務已停止');
  }
}

/// 前景服務管理器
class ForegroundServiceManager {
  static final ForegroundServiceManager _instance =
      ForegroundServiceManager._internal();

  factory ForegroundServiceManager() => _instance;

  ForegroundServiceManager._internal();

  /// 初始化前景服務
  Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ubike_monitor_service',
        channelName: 'Ubike 監控服務',
        channelDescription: '持續監控 Ubike 站點的車輛數量',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000), // 每 60 秒執行一次
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// 開始監控服務（支援多站點）
  Future<bool> startService(List<Station> stations) async {
    if (stations.isEmpty) {
      print('沒有站點可監控');
      return false;
    }

    // 儲存監控站點列表
    final prefs = await SharedPreferences.getInstance();
    final stationsJson = stations.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('monitored_stations', stationsJson);

    // 建構初始通知內容
    String notificationTitle;
    String notificationText;

    if (stations.length == 1) {
      notificationTitle = '監控: ${stations[0].stationName}';
      notificationText = '正在監控車輛數量變化...';
    } else {
      notificationTitle = '監控 ${stations.length} 個站點';
      notificationText = '正在監控 ${stations.map((s) => s.stationName).take(2).join('、')}${stations.length > 2 ? ' 等站點' : ''}';
    }

    // 啟動前景服務
    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: notificationTitle,
      notificationText: notificationText,
      callback: startCallback,
    );

    return result is ServiceRequestSuccess;
  }

  /// 新增站點到監控列表
  Future<bool> addStation(Station station) async {
    final prefs = await SharedPreferences.getInstance();
    final stationsJson = prefs.getStringList('monitored_stations') ?? [];

    // 檢查是否已存在
    bool exists = false;
    for (var jsonStr in stationsJson) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (json['station_no'] == station.stationNo) {
          exists = true;
          break;
        }
      } catch (e) {
        continue;
      }
    }

    if (exists) {
      print('站點 ${station.stationNo} 已在監控列表中');
      return false;
    }

    // 加入新站點
    stationsJson.add(jsonEncode(station.toJson()));
    await prefs.setStringList('monitored_stations', stationsJson);

    // 如果服務正在運行，重新啟動以載入新站點
    final isRunning = await isServiceRunning();
    if (isRunning) {
      await FlutterForegroundTask.restartService();
    } else {
      // 如果服務未運行，啟動服務
      final stations = <Station>[];
      for (var jsonStr in stationsJson) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          stations.add(Station.fromStationListJson(json));
        } catch (e) {
          continue;
        }
      }
      return await startService(stations);
    }

    return true;
  }

  /// 從監控列表移除站點
  Future<bool> removeStation(String stationNo) async {
    final prefs = await SharedPreferences.getInstance();
    final stationsJson = prefs.getStringList('monitored_stations') ?? [];

    // 移除該站點
    stationsJson.removeWhere((jsonStr) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return json['station_no'] == stationNo;
      } catch (e) {
        return false;
      }
    });

    await prefs.setStringList('monitored_stations', stationsJson);

    // 清除該站點的上次數量記錄
    await prefs.remove('last_yb2_$stationNo');
    await prefs.remove('last_eyb_$stationNo');

    // 如果還有其他站點，重新啟動服務；否則停止服務
    if (stationsJson.isNotEmpty) {
      final isRunning = await isServiceRunning();
      if (isRunning) {
        await FlutterForegroundTask.restartService();
      }
    } else {
      await stopService();
    }

    return true;
  }

  /// 停止監控服務
  Future<bool> stopService() async {
    // 取得所有監控站點以清除資料
    final prefs = await SharedPreferences.getInstance();
    final stationsJson = prefs.getStringList('monitored_stations') ?? [];

    // 清除所有站點的上次數量記錄
    for (var jsonStr in stationsJson) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final stationNo = json['station_no'] as String;
        await prefs.remove('last_yb2_$stationNo');
        await prefs.remove('last_eyb_$stationNo');
      } catch (e) {
        continue;
      }
    }

    // 清除監控站點列表
    await prefs.remove('monitored_stations');

    // 停止前景服務
    final result = await FlutterForegroundTask.stopService();

    return result is ServiceRequestSuccess;
  }

  /// 檢查服務是否正在運行
  Future<bool> isServiceRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}

/// 前景服務回調函數
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(UbikeMonitorTaskHandler());
}
