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


  /// 發送整合的更新摘要通知（適合手錶顯示）
  /// [updates] 更新列表，每個元素包含站點名稱和變化資訊
  Future<void> sendConsolidatedUpdateNotification({
    required List<Map<String, dynamic>> updates,
  }) async {
    if (updates.isEmpty) return;

    String title;
    String body;

    // 計算總變化
    final totalChange = updates.fold<int>(
      0,
      (sum, update) => sum + (update['totalChange'] as int),
    );

    // 建立標題
    if (updates.length == 1) {
      final stationName = updates[0]['stationName'] as String;
      if (totalChange > 0) {
        title = '🚲 $stationName +$totalChange台';
      } else if (totalChange < 0) {
        title = '🚲 $stationName $totalChange台';
      } else {
        title = '🚲 $stationName';
      }
    } else {
      if (totalChange > 0) {
        title = '🚲 ${updates.length}站點更新 (+$totalChange台)';
      } else if (totalChange < 0) {
        title = '🚲 ${updates.length}站點更新 ($totalChange台)';
      } else {
        title = '🚲 ${updates.length}站點更新';
      }
    }

    // 建立內容
    if (updates.length <= 3) {
      // 1-3個站點：顯示詳細的 YB2 和電輔車變化
      final lines = updates.map((update) {
        final name = (update['stationName'] as String)
            .replaceAll('YouBike2.0_', '')
            .replaceAll('YouBike2.0', '');
        final yb2Change = update['yb2Change'] as int;
        final eybChange = update['eybChange'] as int;

        final parts = <String>[];
        parts.add(name);

        if (yb2Change != 0) {
          parts.add('YB2 ${yb2Change > 0 ? '+' : ''}$yb2Change');
        }
        if (eybChange != 0) {
          parts.add('電輔 ${eybChange > 0 ? '+' : ''}$eybChange');
        }

        return parts.join(' ');
      }).toList();

      body = lines.join('\n');

    } else {
      // 4個以上站點：只顯示站點名稱和總增減（最多顯示10個）
      final displayUpdates = updates.take(10).toList();
      final lines = displayUpdates.map((update) {
        final name = (update['stationName'] as String)
            .replaceAll('YouBike2.0_', '')
            .replaceAll('YouBike2.0', '');
        final change = update['totalChange'] as int;
        if (change > 0) {
          return '$name +$change';
        } else if (change < 0) {
          return '$name $change';
        } else {
          return name;
        }
      }).toList();

      if (updates.length > 10) {
        lines.add('及其他 ${updates.length - 10} 個站點');
      }

      body = lines.join('\n');
    }

    // 使用 BigTextStyle 確保多行內容完整顯示
    final androidDetails = AndroidNotificationDetails(
      'ubike_monitor',
      'Ubike 監控',
      channelDescription: '監控 Ubike 站點車輛數量變化',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 使用固定 ID 2 作為整合通知（每次覆蓋上一次）
    await _notifications.show(2, title, body, notificationDetails);
  }

  /// 發送測試通知（用於測試推播功能）
  Future<void> sendTestNotification() async {
    await sendConsolidatedUpdateNotification(
      updates: [
        {
          'stationName': '捷運市政府站',
          'yb2Change': 3,
          'eybChange': 2,
          'totalChange': 5,
        },
        {
          'stationName': '世貿中心',
          'yb2Change': -2,
          'eybChange': 0,
          'totalChange': -2,
        },
      ],
    );
  }
}
