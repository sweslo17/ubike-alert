import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/station.dart';

/// Ubike API 服務
/// 負責從新版 YouBike API 取得站點資料
class ApiService {
  // 站點列表 API 網址（全台灣 YouBike 2.0 站點）
  static const String stationListUrl =
      'https://apis.youbike.com.tw/json/station-min-yb2.json';

  // 停車資訊 API 網址（取得站點詳細資料）
  static const String parkingInfoUrl =
      'https://apis.youbike.com.tw/tw2/parkingInfo';

  /// 取得所有站點列表（僅基本資訊）
  /// 回傳 List of Station，失敗時回傳空陣列
  Future<List<Station>> fetchStations() async {
    try {
      final response = await http.get(Uri.parse(stationListUrl));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
        return jsonData
            .map((json) => Station.fromStationListJson(json))
            .toList();
      } else {
        print('站點列表 API 請求失敗: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('取得站點列表時發生錯誤: $e');
      return [];
    }
  }

  /// 根據站點編號取得詳細資料（包含 YB2/EYB 可借還車輛資訊）
  /// 用於監控特定站點或進入站點頁面時
  Future<Station?> fetchStationDetail(String stationNo, Station baseStation) async {
    try {
      final response = await http.post(
        Uri.parse(parkingInfoUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'station_no': [stationNo]
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));

        // 檢查回應格式
        if (responseData['retCode'] == 1 &&
            responseData['retVal'] != null &&
            responseData['retVal']['data'] != null &&
            responseData['retVal']['data'].isNotEmpty) {

          final stationData = responseData['retVal']['data'][0];
          return Station.fromParkingInfoJson(stationData, baseStation);
        } else {
          print('停車資訊 API 回應格式錯誤或無資料');
          return null;
        }
      } else {
        print('停車資訊 API 請求失敗: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('取得站點 $stationNo 詳細資料時發生錯誤: $e');
      return null;
    }
  }

  /// 批次取得多個站點的詳細資料
  Future<Map<String, Station>> fetchMultipleStationDetails(
    List<String> stationNos,
    Map<String, Station> baseStations,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(parkingInfoUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'station_no': stationNos,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final Map<String, Station> results = {};

        if (responseData['retCode'] == 1 &&
            responseData['retVal'] != null &&
            responseData['retVal']['data'] != null) {

          for (var stationData in responseData['retVal']['data']) {
            final stationNo = stationData['station_no'] as String;
            final baseStation = baseStations[stationNo];
            if (baseStation != null) {
              results[stationNo] = Station.fromParkingInfoJson(stationData, baseStation);
            }
          }
        }

        return results;
      } else {
        print('批次取得停車資訊失敗: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('批次取得站點詳細資料時發生錯誤: $e');
      return {};
    }
  }
}
