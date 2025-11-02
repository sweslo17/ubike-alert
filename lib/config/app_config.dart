import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 應用程式配置管理
/// 從 .env 檔案載入敏感資訊
class AppConfig {
  /// Google Maps API Key
  static String get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'Google Maps API Key 未設定！\n'
        '請確認：\n'
        '1. 已複製 .env.example 為 .env\n'
        '2. 已在 .env 中填入正確的 GOOGLE_MAPS_API_KEY',
      );
    }
    return key;
  }

  /// 檢查配置是否完整
  static bool isConfigured() {
    try {
      return googleMapsApiKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
