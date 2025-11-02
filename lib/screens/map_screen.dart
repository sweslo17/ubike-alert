import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/station.dart';
import '../services/api_service.dart';
import 'monitor_screen.dart';

/// 地圖選擇站點畫面
/// 在地圖上顯示站點並可點選進入詳細頁面
class MapScreen extends StatefulWidget {
  final List<Station> allStations;

  const MapScreen({super.key, required this.allStations});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiService _apiService = ApiService();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Map<String, Station> _stationDetailsMap = {};
  bool _isLoading = false;
  Timer? _debounceTimer;

  // 台北市中心作為預設位置（當無法取得使用者位置時使用）
  static const LatLng _defaultCenter = LatLng(25.0330, 121.5654);

  // 初始地圖位置和縮放級別
  LatLng _initialPosition = _defaultCenter;
  double _initialZoom = 15.0; // 適合查看附近站點的縮放級別
  bool _isLocationReady = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  /// 初始化位置（獲取用戶當前位置）
  Future<void> _initializeLocation() async {
    try {
      // 檢查位置服務是否啟用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('位置服務未啟用，使用預設位置');
        _useDefaultLocation();
        return;
      }

      // 檢查位置權限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('位置權限被拒絕，使用預設位置');
          _useDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('位置權限被永久拒絕，使用預設位置');
        _useDefaultLocation();
        return;
      }

      // 獲取當前位置
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _isLocationReady = true;
      });

      // 如果地圖控制器已經初始化，移動相機到當前位置
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _initialPosition,
              zoom: _initialZoom,
            ),
          ),
        );
      }

      print('已取得使用者位置: ${position.latitude}, ${position.longitude}');

      // 獲取位置後更新標記
      _updateMarkersForVisibleRegion();
    } catch (e) {
      print('取得位置時發生錯誤: $e');
      _useDefaultLocation();
    }
  }

  /// 使用預設位置
  void _useDefaultLocation() {
    setState(() {
      _initialPosition = _defaultCenter;
      _isLocationReady = true;
    });
    // 使用預設位置時也需要更新標記
    Future.delayed(const Duration(milliseconds: 500), () {
      _updateMarkersForVisibleRegion();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// 當地圖移動時觸發
  void _onCameraMove(CameraPosition position) {
    // 使用 debounce 避免過於頻繁的 API 呼叫
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateMarkersForVisibleRegion();
    });
  }

  /// 更新可視範圍內的站點標記
  Future<void> _updateMarkersForVisibleRegion() async {
    if (_mapController == null) return;

    setState(() => _isLoading = true);

    try {
      // 取得可視範圍
      final visibleRegion = await _mapController!.getVisibleRegion();

      // 過濾出可視範圍內的站點
      final visibleStations = widget.allStations.where((station) {
        return _isInBounds(
          station.latitude,
          station.longitude,
          visibleRegion,
        );
      }).toList();

      print('可視範圍內有 ${visibleStations.length} 個站點');

      // 批次取得站點詳細資訊
      if (visibleStations.isNotEmpty) {
        final stationNos = visibleStations.map((s) => s.stationNo).toList();
        final baseStationsMap = {
          for (var s in visibleStations) s.stationNo: s
        };

        final detailsMap = await _apiService.fetchMultipleStationDetails(
          stationNos,
          baseStationsMap,
        );

        _stationDetailsMap = detailsMap;

        // 生成標記
        _generateMarkers(visibleStations, detailsMap);
      }
    } catch (e) {
      print('更新地圖標記時發生錯誤: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 檢查座標是否在可視範圍內
  bool _isInBounds(double lat, double lng, LatLngBounds bounds) {
    return lat >= bounds.southwest.latitude &&
        lat <= bounds.northeast.latitude &&
        lng >= bounds.southwest.longitude &&
        lng <= bounds.northeast.longitude;
  }

  /// 生成地圖標記
  void _generateMarkers(
    List<Station> stations,
    Map<String, Station> detailsMap,
  ) {
    final markers = <Marker>{};

    for (var station in stations) {
      final details = detailsMap[station.stationNo];
      final hasDetails = details?.availableSpaces != null;

      // 根據車輛狀態決定標記顏色
      BitmapDescriptor markerColor;
      if (!hasDetails) {
        markerColor = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure, // 使用淺藍色表示載入中
        );
      } else {
        final totalBikes = details!.availableSpaces!.total;
        final emptySpaces = details.emptySpaces ?? 0;

        if (totalBikes >= 3 && emptySpaces >= 3) {
          // 有車有位：綠色
          markerColor = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          );
        } else if (totalBikes == 0) {
          // 無車：紅色
          markerColor = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          );
        } else if (emptySpaces == 0) {
          // 無位：橘色
          markerColor = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          );
        } else {
          // 車少或位少：黃色
          markerColor = BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          );
        }
      }

      markers.add(
        Marker(
          markerId: MarkerId(station.stationNo),
          position: LatLng(station.latitude, station.longitude),
          icon: markerColor,
          infoWindow: InfoWindow(
            title: station.stationName,
            snippet: hasDetails
                ? 'YB2: ${details!.availableSpaces!.yb2} | 電輔: ${details.availableSpaces!.eyb}'
                : '載入中...',
          ),
          onTap: () => _onMarkerTapped(station, details),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  /// 當標記被點擊時
  void _onMarkerTapped(Station baseStation, Station? details) {
    final stationToShow = details ?? baseStation;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stationToShow.stationName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('地址: ${stationToShow.address}'),
            const SizedBox(height: 8),
            if (details?.availableSpaces != null) ...[
              Text('YouBike 2.0: ${details!.availableSpaces!.yb2} 台'),
              Text('電輔車: ${details.availableSpaces!.eyb} 台'),
              Text('可還空位: ${details.emptySpaces ?? 0} 個'),
              Text('總車位: ${details.totalSpaces ?? 0} 個'),
            ] else ...[
              const Text('載入詳細資訊中...'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MonitorScreen(station: stationToShow),
                ),
              );
            },
            child: const Text('進入站點'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地圖選擇站點'),
        backgroundColor: Colors.orange,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: _initialZoom,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
              // 如果位置已經準備好，移動相機到該位置
              if (_isLocationReady && _initialPosition != _defaultCenter) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _initialPosition,
                      zoom: _initialZoom,
                    ),
                  ),
                );
              }
            },
            onCameraMove: _onCameraMove,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
          ),

          // 載入指示器
          if (_isLoading)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '更新站點資訊中...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 圖例說明
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '圖例',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  _buildLegendItem(Colors.green, '有車有位'),
                  _buildLegendItem(Colors.yellow, '車少或位少'),
                  _buildLegendItem(Colors.red, '無車'),
                  _buildLegendItem(Colors.orange, '無位'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
