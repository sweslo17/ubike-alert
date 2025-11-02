import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/station.dart';
import '../services/api_service.dart';
import '../services/foreground_service.dart';
import 'monitor_screen.dart';

/// 監控站點列表畫面
/// 顯示所有正在監控的站點並可管理
class MonitoredStationsScreen extends StatefulWidget {
  const MonitoredStationsScreen({super.key});

  @override
  State<MonitoredStationsScreen> createState() => _MonitoredStationsScreenState();
}

class _MonitoredStationsScreenState extends State<MonitoredStationsScreen> {
  final ApiService _apiService = ApiService();
  final ForegroundServiceManager _foregroundService = ForegroundServiceManager();

  List<Station> _monitoredStations = [];
  Map<String, Station> _stationDetailsMap = {};
  bool _isLoading = true;
  bool _isServiceRunning = false;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _loadMonitoredStations();
    _checkServiceStatus();
    _startPeriodicUpdate();
    _setupForegroundTaskListener();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }

  /// 設定前景服務監聽器
  void _setupForegroundTaskListener() {
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  /// 接收前景服務的資料更新
  void _onReceiveTaskData(dynamic data) {
    if (data is Map && mounted) {
      final updates = data['stations'] as List<dynamic>?;
      if (updates != null) {
        setState(() {
          for (var update in updates) {
            final stationNo = update['station_no'] as String;
            final yb2 = update['yb2'] as int;
            final eyb = update['eyb'] as int;
            final emptySpaces = update['empty_spaces'] as int?;

            // 更新站點詳細資訊
            final existingStation = _stationDetailsMap[stationNo];
            if (existingStation != null) {
              _stationDetailsMap[stationNo] = existingStation.copyWithDetails(
                availableSpaces: BikeAvailability(yb2: yb2, eyb: eyb),
                emptySpaces: emptySpaces,
              );
            }
          }
        });
      }
    }
  }

  /// 檢查服務狀態
  Future<void> _checkServiceStatus() async {
    final isRunning = await _foregroundService.isServiceRunning();
    setState(() {
      _isServiceRunning = isRunning;
    });
  }

  /// 啟動定期更新（僅用於刷新 UI 的相對時間顯示）
  void _startPeriodicUpdate() {
    // 每 10 秒觸發一次 setState 來更新 UI 上的相對時間
    // 實際站點資料由背景服務透過 _onReceiveTaskData 推送
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          // 觸發重新建構，更新相對時間顯示
        });
      }
    });
  }

  /// 載入監控站點列表
  Future<void> _loadMonitoredStations() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final stationsJson = prefs.getStringList('monitored_stations') ?? [];

      final stations = <Station>[];
      for (var jsonStr in stationsJson) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          stations.add(Station.fromStationListJson(json));
        } catch (e) {
          print('解析站點資料失敗: $e');
        }
      }

      setState(() {
        _monitoredStations = stations;
      });

      // 載入站點詳細資訊
      await _updateStationDetails();
    } catch (e) {
      print('載入監控站點失敗: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 更新站點詳細資訊
  Future<void> _updateStationDetails() async {
    if (_monitoredStations.isEmpty) return;

    try {
      final stationNos = _monitoredStations.map((s) => s.stationNo).toList();
      final baseStationsMap = {
        for (var s in _monitoredStations) s.stationNo: s
      };

      final detailsMap = await _apiService.fetchMultipleStationDetails(
        stationNos,
        baseStationsMap,
      );

      setState(() {
        _stationDetailsMap = detailsMap;
      });
    } catch (e) {
      print('更新站點詳細資訊失敗: $e');
    }
  }

  /// 移除單一監控站點
  Future<void> _removeStation(Station station) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stationsJson = prefs.getStringList('monitored_stations') ?? [];

      // 移除該站點
      stationsJson.removeWhere((jsonStr) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          return json['station_no'] == station.stationNo;
        } catch (e) {
          return false;
        }
      });

      await prefs.setStringList('monitored_stations', stationsJson);

      // 移除該站點的上次數量記錄
      await prefs.remove('last_yb2_${station.stationNo}');
      await prefs.remove('last_eyb_${station.stationNo}');

      // 重新載入列表
      await _loadMonitoredStations();

      // 如果沒有監控站點了，停止服務
      if (_monitoredStations.isEmpty && _isServiceRunning) {
        await _stopAllMonitoring();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已停止監控「${station.stationName}」')),
        );
      }
    } catch (e) {
      print('移除監控站點失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('移除失敗')),
        );
      }
    }
  }

  /// 停止所有監控
  Future<void> _stopAllMonitoring() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認停止'),
        content: const Text('確定要停止監控所有站點嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('停止全部'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await _foregroundService.stopService();

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('monitored_stations');

        // 清除所有站點的上次數量記錄
        for (var station in _monitoredStations) {
          await prefs.remove('last_yb2_${station.stationNo}');
          await prefs.remove('last_eyb_${station.stationNo}');
        }

        setState(() {
          _monitoredStations = [];
          _stationDetailsMap = {};
          _isServiceRunning = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已停止所有監控')),
          );
        }
      }
    } catch (e) {
      print('停止監控失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('停止失敗')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('監控站點列表'),
        backgroundColor: Colors.orange,
        actions: [
          if (_monitoredStations.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.stop_circle),
              onPressed: _stopAllMonitoring,
              tooltip: '停止全部監控',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _monitoredStations.isEmpty
              ? _buildEmptyState()
              : _buildStationList(),
    );
  }

  /// 建立空白狀態
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '目前沒有監控任何站點',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在站點頁面點擊「開始監控」即可新增',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// 建立站點列表
  Widget _buildStationList() {
    return Column(
      children: [
        // 服務狀態指示器
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: _isServiceRunning ? Colors.green[100] : Colors.grey[200],
          child: Row(
            children: [
              Icon(
                _isServiceRunning ? Icons.check_circle : Icons.info,
                color: _isServiceRunning ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isServiceRunning
                      ? '背景監控服務執行中（${_monitoredStations.length} 個站點）'
                      : '背景服務未執行',
                  style: TextStyle(
                    color: _isServiceRunning ? Colors.green[900] : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 站點列表
        Expanded(
          child: ListView.builder(
            itemCount: _monitoredStations.length,
            itemBuilder: (context, index) {
              final station = _monitoredStations[index];
              final details = _stationDetailsMap[station.stationNo];
              return _buildStationCard(station, details);
            },
          ),
        ),
      ],
    );
  }

  /// 建立站點卡片
  Widget _buildStationCard(Station station, Station? details) {
    final hasDetails = details?.availableSpaces != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hasDetails
              ? (details!.availableSpaces!.total > 0
                  ? Colors.green
                  : Colors.red)
              : Colors.grey,
          child: hasDetails
              ? Text(
                  '${details!.availableSpaces!.total}',
                  style: const TextStyle(color: Colors.white),
                )
              : const Icon(Icons.help, color: Colors.white),
        ),
        title: Text(station.stationName),
        subtitle: hasDetails
            ? Text(
                'YB2: ${details!.availableSpaces!.yb2} | 電輔: ${details.availableSpaces!.eyb} | 可還: ${details.emptySpaces ?? 0}',
              )
            : const Text('載入中...'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MonitorScreen(station: station),
                  ),
                );
              },
              tooltip: '查看詳情',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeStation(station),
              tooltip: '移除監控',
            ),
          ],
        ),
      ),
    );
  }
}
