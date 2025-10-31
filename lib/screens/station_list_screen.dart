import 'dart:async';
import 'package:flutter/material.dart';
import '../models/station.dart';
import '../services/api_service.dart';
import 'monitor_screen.dart';

/// 站點列表畫面
/// 顯示所有 Ubike 站點並提供搜尋功能
class StationListScreen extends StatefulWidget {
  const StationListScreen({super.key});

  @override
  State<StationListScreen> createState() => _StationListScreenState();
}

class _StationListScreenState extends State<StationListScreen> {
  final ApiService _apiService = ApiService();
  List<Station> _stations = []; // 所有站點
  List<Station> _filteredStations = []; // 搜尋過濾後的站點
  bool _isLoading = true; // 載入中狀態
  Timer? _refreshTimer; // 自動刷新定時器
  String _currentSearchQuery = ''; // 當前搜尋關鍵字

  @override
  void initState() {
    super.initState();
    _loadStations(); // 載入站點資料
    _startAutoRefresh(); // 啟動自動刷新
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // 停止定時器
    super.dispose();
  }

  /// 啟動自動刷新（每分鐘更新一次）
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadStations();
    });
  }

  /// 載入所有站點資料
  Future<void> _loadStations() async {
    // 只在初次載入時顯示載入中畫面
    if (_stations.isEmpty) {
      setState(() => _isLoading = true);
    }

    final stations = await _apiService.fetchStations();

    setState(() {
      _stations = stations;
      // 重新套用當前的搜尋過濾
      _applySearchFilter();
      _isLoading = false;
    });
  }

  /// 搜尋過濾站點
  void _filterStations(String query) {
    _currentSearchQuery = query;
    _applySearchFilter();
  }

  /// 套用搜尋過濾
  void _applySearchFilter() {
    setState(() {
      if (_currentSearchQuery.isEmpty) {
        _filteredStations = _stations;
      } else {
        _filteredStations = _stations
            .where((station) =>
                station.sna.contains(_currentSearchQuery) ||
                station.sarea.contains(_currentSearchQuery) ||
                station.ar.contains(_currentSearchQuery))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 頂部導覽列
      appBar: AppBar(
        title: const Text('選擇監控站點'),
        backgroundColor: Colors.orange,
      ),

      // 主要內容
      body: Column(
        children: [
          // 搜尋框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜尋站點名稱或地址',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _filterStations,
            ),
          ),

          // 站點列表或載入中提示
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildStationList(),
          ),
        ],
      ),

      // 重新載入按鈕
      floatingActionButton: FloatingActionButton(
        onPressed: _loadStations,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  /// 建立站點列表
  Widget _buildStationList() {
    if (_filteredStations.isEmpty) {
      return const Center(
        child: Text('沒有找到符合的站點'),
      );
    }

    return ListView.builder(
      itemCount: _filteredStations.length,
      itemBuilder: (context, index) {
        final station = _filteredStations[index];
        return _buildStationCard(station);
      },
    );
  }

  /// 建立單一站點卡片
  Widget _buildStationCard(Station station) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        // 左側圖示
        leading: CircleAvatar(
          backgroundColor: station.availableRentBikes > 0
              ? Colors.green
              : Colors.red,
          child: Text(
            '${station.availableRentBikes}',
            style: const TextStyle(color: Colors.white),
          ),
        ),

        // 站點資訊
        title: Text(station.sna),
        subtitle: Text(
          '${station.sarea} - ${station.ar}\n'
          '可借: ${station.availableRentBikes} | 可還: ${station.availableReturnBikes}',
        ),
        isThreeLine: true,

        // 點擊後進入監控畫面
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MonitorScreen(station: station),
            ),
          );
        },

        // 右側箭頭
        trailing: const Icon(Icons.arrow_forward_ios),
      ),
    );
  }
}
