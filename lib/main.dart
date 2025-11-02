import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/station_list_screen.dart';
import 'config/app_config.dart';

/// Ubike 監控 APP 主程式
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 載入環境變數（API Keys 等敏感資訊）
  try {
    await dotenv.load(fileName: ".env");
    print('環境變數載入成功');

    // 驗證必要的配置是否存在
    if (!AppConfig.isConfigured()) {
      print('警告：配置不完整，請檢查 .env 檔案');
    }
  } catch (e) {
    print('載入 .env 失敗: $e');
    print('請確認已建立 .env 檔案（可從 .env.example 複製）');
  }

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
