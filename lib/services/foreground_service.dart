import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 前景服務任務處理器
/// 在背景持續監控站點資料
@pragma('vm:entry-point')
class UbikeMonitorTaskHandler extends TaskHandler {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  String? _stationSno;
  int? _lastBikeCount;
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
    _stationSno = prefs.getString('monitoring_station_sno');
    _threshold = prefs.getInt('threshold') ?? 0;
    _lastBikeCount = prefs.getInt('last_bike_count');

    print('載入設定: 站點=$_stationSno, 門檻=$_threshold, 上次車輛數=$_lastBikeCount');
  }

  /// 儲存上次車輛數
  Future<void> _saveLastBikeCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_bike_count', count);
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (_stationSno == null) {
      print('沒有設定監控站點');
      return;
    }

    print('檢查站點資料: $_stationSno');

    try {
      final station = await _apiService.fetchStationById(_stationSno!);

      if (station == null) {
        print('無法取得站點資料');
        return;
      }

      final currentCount = station.availableRentBikes;
      print('目前車輛數: $currentCount, 上次: $_lastBikeCount');

      // 檢查是否需要發送通知
      if (_lastBikeCount != null && _lastBikeCount != currentCount) {
        if (currentCount >= _threshold) {
          await _notificationService.sendBikeCountNotification(
            stationName: station.sna,
            oldCount: _lastBikeCount!,
            newCount: currentCount,
          );
          print('已發送通知: ${station.sna} $currentCount 台');
        }
      }

      _lastBikeCount = currentCount;
      await _saveLastBikeCount(currentCount);

      // 更新前景服務通知內容
      FlutterForegroundTask.updateService(
        notificationTitle: '監控中: ${station.sna}',
        notificationText: '可借車輛: $currentCount 台',
      );

      // 發送資料到 UI
      FlutterForegroundTask.sendDataToMain({
        'sno': station.sno,
        'bikeCount': currentCount,
        'updateTime': station.updateTime,
      });
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

  /// 開始監控服務
  Future<bool> startService(String stationSno, String stationName) async {
    // 儲存監控站點資訊
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('monitoring_station_sno', stationSno);

    // 啟動前景服務
    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '監控中: $stationName',
      notificationText: '正在監控站點車輛數量...',
      callback: startCallback,
    );

    return result is ServiceRequestSuccess;
  }

  /// 停止監控服務
  Future<bool> stopService() async {
    // 清除監控站點資訊
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('monitoring_station_sno');
    await prefs.remove('last_bike_count');

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
