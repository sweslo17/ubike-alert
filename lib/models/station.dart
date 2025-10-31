/// Ubike 站點資料模型
/// 對應 API 回傳的 JSON 資料
class Station {
  final String sno; // 站點編號
  final String sna; // 站點名稱（中文）
  final String sarea; // 行政區（中文）
  final String ar; // 地址（中文）
  final int quantity; // 總車位數
  final int availableRentBikes; // 可借車輛數
  final int availableReturnBikes; // 可還空位數
  final double latitude; // 緯度
  final double longitude; // 經度
  final String updateTime; // 更新時間

  Station({
    required this.sno,
    required this.sna,
    required this.sarea,
    required this.ar,
    required this.quantity,
    required this.availableRentBikes,
    required this.availableReturnBikes,
    required this.latitude,
    required this.longitude,
    required this.updateTime,
  });

  /// 從 JSON 建立 Station 物件
  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      sno: json['sno'] ?? '',
      sna: json['sna'] ?? '',
      sarea: json['sarea'] ?? '',
      ar: json['ar'] ?? '',
      quantity: json['Quantity'] ?? 0,
      availableRentBikes: json['available_rent_bikes'] ?? 0,
      availableReturnBikes: json['available_return_bikes'] ?? 0,
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      updateTime: json['updateTime'] ?? '',
    );
  }

  /// 轉換為 JSON（用於儲存）
  Map<String, dynamic> toJson() {
    return {
      'sno': sno,
      'sna': sna,
      'sarea': sarea,
      'ar': ar,
      'Quantity': quantity,
      'available_rent_bikes': availableRentBikes,
      'available_return_bikes': availableReturnBikes,
      'latitude': latitude,
      'longitude': longitude,
      'updateTime': updateTime,
    };
  }
}
