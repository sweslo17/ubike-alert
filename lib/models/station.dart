/// 車輛可用性詳細資訊（區分 YB2 和 EYB）
class BikeAvailability {
  final int yb2; // 一般 YouBike 2.0 數量
  final int eyb; // 電輔車數量

  BikeAvailability({
    required this.yb2,
    required this.eyb,
  });

  /// 總可借車輛數
  int get total => yb2 + eyb;

  /// 從 JSON 建立 BikeAvailability 物件
  factory BikeAvailability.fromJson(Map<String, dynamic> json) {
    return BikeAvailability(
      yb2: json['yb2'] ?? 0,
      eyb: json['eyb'] ?? 0,
    );
  }

  /// 轉換為 JSON
  Map<String, dynamic> toJson() {
    return {
      'yb2': yb2,
      'eyb': eyb,
    };
  }
}

/// Ubike 站點資料模型
/// 對應新版 YouBike API 的資料結構
class Station {
  final String stationNo; // 站點編號
  final String stationName; // 站點名稱（中文）
  final String district; // 行政區（中文）
  final String address; // 地址（中文）
  final double latitude; // 緯度
  final double longitude; // 經度
  final int status; // 站點狀態

  // 以下為詳細資訊（需透過 parkingInfo API 取得）
  final BikeAvailability? availableSpaces; // 可借車輛詳細資訊（YB2/EYB）
  final int? emptySpaces; // 可還空位數
  final int? totalSpaces; // 總車位數
  final String? updateTime; // 更新時間

  Station({
    required this.stationNo,
    required this.stationName,
    required this.district,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.availableSpaces,
    this.emptySpaces,
    this.totalSpaces,
    this.updateTime,
  });

  /// 從站點列表 API (station-min-yb2.json) 建立基本資訊
  factory Station.fromStationListJson(Map<String, dynamic> json) {
    return Station(
      stationNo: json['station_no'] ?? '',
      stationName: json['name_tw'] ?? '',
      district: json['district_tw'] ?? '',
      address: json['address_tw'] ?? '',
      latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['lng']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 1,
    );
  }

  /// 從停車資訊 API (parkingInfo) 更新詳細資訊
  static Station fromParkingInfoJson(
    Map<String, dynamic> json,
    Station baseStation,
  ) {
    BikeAvailability? availability;
    if (json['available_spaces_detail'] != null) {
      availability = BikeAvailability.fromJson(json['available_spaces_detail']);
    }

    return Station(
      stationNo: baseStation.stationNo,
      stationName: baseStation.stationName,
      district: baseStation.district,
      address: baseStation.address,
      latitude: double.tryParse(json['lat']?.toString() ?? '0') ?? baseStation.latitude,
      longitude: double.tryParse(json['lng']?.toString() ?? '0') ?? baseStation.longitude,
      status: json['status'] ?? baseStation.status,
      availableSpaces: availability,
      emptySpaces: json['empty_spaces'],
      totalSpaces: json['parking_spaces'],
      updateTime: baseStation.updateTime,
    );
  }

  /// 複製站點並更新詳細資訊
  Station copyWithDetails({
    BikeAvailability? availableSpaces,
    int? emptySpaces,
    int? totalSpaces,
    String? updateTime,
  }) {
    return Station(
      stationNo: stationNo,
      stationName: stationName,
      district: district,
      address: address,
      latitude: latitude,
      longitude: longitude,
      status: status,
      availableSpaces: availableSpaces ?? this.availableSpaces,
      emptySpaces: emptySpaces ?? this.emptySpaces,
      totalSpaces: totalSpaces ?? this.totalSpaces,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  /// 轉換為 JSON（用於儲存）
  Map<String, dynamic> toJson() {
    return {
      'station_no': stationNo,
      'name_tw': stationName,
      'district_tw': district,
      'address_tw': address,
      'lat': latitude.toString(),
      'lng': longitude.toString(),
      'status': status,
      'available_spaces_detail': availableSpaces?.toJson(),
      'empty_spaces': emptySpaces,
      'parking_spaces': totalSpaces,
      'updated_at': updateTime,
    };
  }
}
