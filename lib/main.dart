import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/station_list_screen.dart';

/// Ubike 監控 APP 主程式
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化前景服務
  FlutterForegroundTask.initCommunicationPort();

  // 請求推播通知權限
  await Permission.notification.request();

  runApp(const UbikeAlertApp());
}

/// APP 主要元件
class UbikeAlertApp extends StatelessWidget {
  const UbikeAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ubike 監控',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      // 啟動時顯示站點列表畫面
      home: const StationListScreen(),
    );
  }
}
