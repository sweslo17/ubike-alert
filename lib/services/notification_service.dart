import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 推播通知服務
/// 負責發送本地推播通知
class NotificationService {
  // 單例模式（確保只有一個通知服務實例）
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Flutter Local Notifications 外掛
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// 初始化通知服務
  Future<void> initialize() async {
    // iOS 設定
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Android 設定
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 組合設定
    const settings = InitializationSettings(
      iOS: iosSettings,
      android: androidSettings,
    );

    // 初始化
    await _notifications.initialize(settings);

    // 請求 iOS 權限
    await _requestIOSPermissions();
  }

  /// 請求 iOS 通知權限
  Future<void> _requestIOSPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// 發送車輛數量變化通知
  /// [stationName] 站點名稱
  /// [oldCount] 舊的車輛數量
  /// [newCount] 新的車輛數量
  Future<void> sendBikeCountNotification({
    required String stationName,
    required int oldCount,
    required int newCount,
  }) async {
    // 通知標題
    const title = 'Ubike 車輛數量變化';

    // 通知內容
    final body = '$stationName\n車輛數: $oldCount → $newCount';

    // Android 通知設定
    const androidDetails = AndroidNotificationDetails(
      'ubike_monitor', // 頻道 ID
      'Ubike 監控', // 頻道名稱
      channelDescription: '監控 Ubike 站點車輛數量變化',
      importance: Importance.high,
      priority: Priority.high,
    );

    // iOS 通知設定
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // 組合設定
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 發送通知
    await _notifications.show(
      0, // 通知 ID（使用 0 會覆蓋前一個通知）
      title,
      body,
      details,
    );
  }

  /// 發送測試通知（用於測試推播功能）
  Future<void> sendTestNotification() async {
    await sendBikeCountNotification(
      stationName: '測試站點',
      oldCount: 5,
      newCount: 10,
    );
  }
}
