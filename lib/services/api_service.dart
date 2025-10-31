import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/station.dart';

/// Ubike API 服務
/// 負責從 Ubike API 取得站點資料
class ApiService {
  // 台北市 Ubike API 網址
  static const String taipeiApiUrl =
      'https://tcgbusfs.blob.core.windows.net/dotapp/youbike/v2/youbike_immediate.json';

  // 新北市 Ubike API 網址
  static const String newTaipeiApiUrl =
      'https://data.ntpc.gov.tw/api/datasets/010e5b15-3823-4b20-b401-b1cf000550c5/json?page=0&size=1000';

  /// 取得所有站點資料（合併台北市和新北市）
  /// 回傳 List Station，失敗時回傳空陣列
  Future<List<Station>> fetchStations() async {
    try {
      // 同時取得台北市和新北市的資料
      final results = await Future.wait([
        _fetchTaipeiStations(),
        _fetchNewTaipeiStations(),
      ]);

      // 合併兩個城市的站點
      final allStations = [...results[0], ...results[1]];

      return allStations;
    } catch (e) {
      print('取得站點資料時發生錯誤: $e');
      return [];
    }
  }

  /// 取得台北市站點資料
  Future<List<Station>> _fetchTaipeiStations() async {
    try {
      final response = await http.get(Uri.parse(taipeiApiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
        return jsonData.map((json) => Station.fromJson(json)).toList();
      } else {
        print('台北市 API 請求失敗: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('取得台北市站點資料時發生錯誤: $e');
      return [];
    }
  }

  /// 取得新北市站點資料
  Future<List<Station>> _fetchNewTaipeiStations() async {
    try {
      final response = await http.get(Uri.parse(newTaipeiApiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
        // 新北市的資料格式不同，需要轉換
        return jsonData
            .map((json) => Station.fromJson(_convertNewTaipeiFormat(json)))
            .toList();
      } else {
        print('新北市 API 請求失敗: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('取得新北市站點資料時發生錯誤: $e');
      return [];
    }
  }

  /// 將新北市的資料格式轉換為標準格式
  Map<String, dynamic> _convertNewTaipeiFormat(Map<String, dynamic> json) {
    return {
      'sno': json['sno'] ?? '',
      'sna': json['sna'] ?? '',
      'sarea': json['sarea'] ?? '',
      'ar': json['ar'] ?? '',
      'Quantity': int.tryParse(json['tot']?.toString() ?? '0') ?? 0,
      'available_rent_bikes': int.tryParse(json['sbi']?.toString() ?? '0') ?? 0,
      'available_return_bikes': int.tryParse(json['bemp']?.toString() ?? '0') ?? 0,
      'latitude': double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      'longitude': double.tryParse(json['lng']?.toString() ?? '0') ?? 0.0,
      'updateTime': json['mday'] ?? '',
    };
  }

  /// 根據站點編號取得單一站點資料
  /// 用於監控特定站點
  Future<Station?> fetchStationById(String sno) async {
    try {
      final stations = await fetchStations();
      return stations.firstWhere(
        (station) => station.sno == sno,
        orElse: () => throw Exception('找不到站點'),
      );
    } catch (e) {
      print('取得站點 $sno 時發生錯誤: $e');
      return null;
    }
  }
}
