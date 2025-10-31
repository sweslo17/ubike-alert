import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/station.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/foreground_service.dart';

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
      final sno = data['sno'] as String?;
      final bikeCount = data['bikeCount'] as int?;
      final updateTime = data['updateTime'] as String?;

      // 只更新當前監控的站點
      if (sno == widget.station.sno && bikeCount != null) {
        setState(() {
          if (_currentStation != null) {
            _currentStation = Station(
              sno: _currentStation!.sno,
              sna: _currentStation!.sna,
              sarea: _currentStation!.sarea,
              ar: _currentStation!.ar,
              quantity: _currentStation!.quantity,
              availableRentBikes: bikeCount,
              availableReturnBikes: _currentStation!.availableReturnBikes,
              latitude: _currentStation!.latitude,
              longitude: _currentStation!.longitude,
              updateTime: updateTime ?? _currentStation!.updateTime,
            );
            _lastUpdateTime = DateTime.now();
          }
        });
      }
    }
  }

  /// 檢查前景服務狀態
  Future<void> _checkServiceStatus() async {
    final isRunning = await _foregroundService.isServiceRunning();

    // 檢查是否正在監控其他站點
    final prefs = await SharedPreferences.getInstance();
    final monitoringSno = prefs.getString('monitoring_station_sno');

    setState(() {
      _isMonitoring = isRunning && monitoringSno == widget.station.sno;
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
    final station = await _apiService.fetchStationById(widget.station.sno);
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

  /// 開始監控
  Future<void> _startMonitoring() async {
    if (_currentStation == null) return;

    // 檢查是否正在監控其他站點
    final prefs = await SharedPreferences.getInstance();
    final monitoringSno = prefs.getString('monitoring_station_sno');
    final isServiceRunning = await _foregroundService.isServiceRunning();

    // 如果正在監控其他站點，先停止
    if (isServiceRunning && monitoringSno != null && monitoringSno != widget.station.sno) {
      await _foregroundService.stopService();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已停止監控「$monitoringSno」'),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // 等待一下讓使用者看到訊息
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // 啟動前景服務
    final success = await _foregroundService.startService(
      _currentStation!.sno,
      _currentStation!.sna,
    );

    if (success) {
      setState(() {
        _isMonitoring = true;
        _lastBikeCount = _currentStation?.availableRentBikes;
      });

      // 儲存上次的車輛數
      await prefs.setInt('last_bike_count', _lastBikeCount ?? 0);

      // 顯示成功訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已開始背景監控，即使螢幕關閉也會持續運行'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      // 顯示錯誤訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('啟動監控服務失敗'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 停止監控
  Future<void> _stopMonitoring() async {
    final success = await _foregroundService.stopService();

    if (success) {
      setState(() {
        _isMonitoring = false;
      });

      // 顯示成功訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已停止背景監控'),
            duration: Duration(seconds: 2),
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

            // 開始/停止監控按鈕
            Center(
              child: ElevatedButton.icon(
                onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
                icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                label: Text(_isMonitoring ? '停止監控' : '開始監控'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentStation?.sna ?? '載入中...',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('地址: ${_currentStation?.ar ?? ''}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  '可借車輛',
                  '${_currentStation?.availableRentBikes ?? 0}',
                  Colors.green,
                ),
                _buildInfoItem(
                  '可還空位',
                  '${_currentStation?.availableReturnBikes ?? 0}',
                  Colors.blue,
                ),
                _buildInfoItem(
                  '總車位',
                  '${_currentStation?.quantity ?? 0}',
                  Colors.grey,
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
            if (_isMonitoring) ...[
              const SizedBox(height: 8),
              Text('上次車輛數: ${_lastBikeCount ?? "-"}'),
            ],
            const SizedBox(height: 8),
            if (_currentStation?.updateTime != null) ...[
              Text(
                'API 更新時間: ${_currentStation!.updateTime}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
            if (_lastUpdateTime != null) ...[
              const SizedBox(height: 4),
              Text(
                '資料刷新時間: ${_formatUpdateTime(_lastUpdateTime!)}',
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
