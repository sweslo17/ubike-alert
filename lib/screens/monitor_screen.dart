import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/station.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/foreground_service.dart';
import 'monitored_stations_screen.dart';

/// 監控畫面
/// 即時監控選定站點的車輛數量變化
class MonitorScreen extends StatefulWidget {
  final Station station;

  const MonitorScreen({super.key, required this.station});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  final ForegroundServiceManager _foregroundService = ForegroundServiceManager();

  Station? _currentStation; // 目前站點資料
  Timer? _uiUpdateTimer; // UI 更新定時器
  bool _isMonitoring = false; // 監控中狀態
  int _threshold = 0; // 推播門檻（最小車輛數）
  int? _lastBikeCount; // 上次的車輛數
  DateTime? _lastUpdateTime; // 最後更新時間

  @override
  void initState() {
    super.initState();
    _currentStation = widget.station;
    _loadThreshold(); // 載入儲存的門檻值
    _notificationService.initialize(); // 初始化通知服務
    _foregroundService.initialize(); // 初始化前景服務
    _refreshStationData(); // 進入時立即載入最新資料
    _startUIUpdateTimer(); // 啟動 UI 更新定時器
    _checkServiceStatus(); // 檢查服務狀態
    _setupForegroundTaskListener(); // 設定前景服務監聽器
  }

  /// 設定前景服務監聽器
  void _setupForegroundTaskListener() {
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  /// 接收前景服務的資料更新
  void _onReceiveTaskData(dynamic data) {
    if (data is Map && mounted) {
      // 新格式：批次更新
      final updates = data['stations'] as List<dynamic>?;
      if (updates != null) {
        for (var update in updates) {
          final stationNo = update['station_no'] as String?;
          final yb2Count = update['yb2'] as int?;
          final eybCount = update['eyb'] as int?;
          final emptySpaces = update['empty_spaces'] as int?;

          // 只更新當前監控的站點
          if (stationNo == widget.station.stationNo &&
              yb2Count != null &&
              eybCount != null) {
            setState(() {
              if (_currentStation != null) {
                _currentStation = _currentStation!.copyWithDetails(
                  availableSpaces: BikeAvailability(
                    yb2: yb2Count,
                    eyb: eybCount,
                  ),
                  emptySpaces: emptySpaces,
                );
                _lastUpdateTime = DateTime.now();
              }
            });
            break; // 找到當前站點後就停止
          }
        }
      }
    }
  }

  /// 檢查前景服務狀態
  Future<void> _checkServiceStatus() async {
    final isRunning = await _foregroundService.isServiceRunning();

    // 檢查當前站點是否在監控列表中
    final prefs = await SharedPreferences.getInstance();
    final stationsJson = prefs.getStringList('monitored_stations') ?? [];

    bool isInList = false;
    for (var jsonStr in stationsJson) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (json['station_no'] == widget.station.stationNo) {
          isInList = true;
          break;
        }
      } catch (e) {
        continue;
      }
    }

    setState(() {
      _isMonitoring = isRunning && isInList;
    });
  }

  /// 啟動 UI 更新定時器（每秒更新一次以顯示相對時間）
  void _startUIUpdateTimer() {
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // 觸發重新建構以更新相對時間顯示
        });
      }
    });
  }

  /// 刷新站點資料（不發送通知）
  Future<void> _refreshStationData() async {
    final station = await _apiService.fetchStationDetail(
      widget.station.stationNo,
      widget.station,
    );
    if (station != null) {
      setState(() {
        _currentStation = station;
        _lastUpdateTime = DateTime.now();
      });
    }
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel(); // 停止 UI 更新定時器
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData); // 移除監聽器
    super.dispose();
  }

  /// 載入儲存的門檻值
  Future<void> _loadThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _threshold = prefs.getInt('threshold') ?? 0;
    });
  }

  /// 儲存門檻值
  Future<void> _saveThreshold(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('threshold', value);
    setState(() {
      _threshold = value;
    });
  }

  /// 加入監控列表
  Future<void> _startMonitoring() async {
    if (_currentStation == null) return;

    // 加入站點到監控列表
    final success = await _foregroundService.addStation(_currentStation!);

    if (success) {
      setState(() {
        _isMonitoring = true;
        _lastBikeCount = _currentStation?.availableSpaces?.total;
      });

      // 儲存上次的車輛數（YB2 和 EYB）- 使用新的 per-station keys
      if (_currentStation?.availableSpaces != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_yb2_${_currentStation!.stationNo}', _currentStation!.availableSpaces!.yb2);
        await prefs.setInt('last_eyb_${_currentStation!.stationNo}', _currentStation!.availableSpaces!.eyb);
      }

      // 顯示成功訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已加入監控列表：${_currentStation!.stationName}'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '查看列表',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MonitoredStationsScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } else {
      // 顯示站點已在列表中的訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('此站點已在監控列表中'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 從監控列表移除
  Future<void> _stopMonitoring() async {
    final success = await _foregroundService.removeStation(widget.station.stationNo);

    if (success) {
      setState(() {
        _isMonitoring = false;
      });

      // 顯示成功訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已從監控列表移除：${widget.station.stationName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 顯示門檻設定對話框
  Future<void> _showThresholdDialog() async {
    final controller = TextEditingController(text: _threshold.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設定推播門檻'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '最小車輛數',
            hintText: '當車輛數 >= 此值時才推播',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text) ?? 0;
              _saveThreshold(value);
              Navigator.pop(context);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('站點監控'),
          backgroundColor: Colors.orange,
          actions: [
            // 設定門檻按鈕
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showThresholdDialog,
            ),
          ],
        ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 站點資訊卡片
            _buildStationInfoCard(),

            const SizedBox(height: 24),

            // 監控狀態
            _buildMonitoringStatus(),

            const SizedBox(height: 24),

            // 加入/移除監控按鈕
            Center(
              child: ElevatedButton.icon(
                onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
                icon: Icon(_isMonitoring ? Icons.remove_circle : Icons.add_circle),
                label: Text(_isMonitoring ? '移除監控' : '加入監控'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// 建立站點資訊卡片
  Widget _buildStationInfoCard() {
    final hasDetails = _currentStation?.availableSpaces != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentStation?.stationName ?? '載入中...',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('地址: ${_currentStation?.address ?? ''}'),
            const SizedBox(height: 16),
            if (!hasDetails)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem(
                        'YouBike 2.0',
                        '${_currentStation?.availableSpaces?.yb2 ?? 0}',
                        Colors.green,
                      ),
                      _buildInfoItem(
                        '電輔車',
                        '${_currentStation?.availableSpaces?.eyb ?? 0}',
                        Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem(
                        '可還空位',
                        '${_currentStation?.emptySpaces ?? 0}',
                        Colors.orange,
                      ),
                      _buildInfoItem(
                        '總車位',
                        '${_currentStation?.totalSpaces ?? 0}',
                        Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 建立資訊項目
  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label),
      ],
    );
  }

  /// 建立監控狀態
  Widget _buildMonitoringStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isMonitoring ? Icons.check_circle : Icons.cancel,
                  color: _isMonitoring ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _isMonitoring ? '監控中' : '未監控',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('推播門檻: $_threshold 台以上'),
            if (_isMonitoring && _lastBikeCount != null) ...[
              const SizedBox(height: 8),
              Text('上次總車輛數: $_lastBikeCount'),
            ],
            if (_lastUpdateTime != null) ...[
              const SizedBox(height: 8),
              Text(
                '最後更新: ${_formatUpdateTime(_lastUpdateTime!)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 格式化更新時間
  String _formatUpdateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} 秒前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分鐘前';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
