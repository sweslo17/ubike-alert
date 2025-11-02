# Ubike Alert

一個即時監控 Ubike 站點車輛數量的 Flutter 應用程式，支援背景監控和推播通知。

**支援全台灣的 YouBike 2.0 站點，包含一般車與電輔車的即時資訊。**

## 功能特色

- 📍 **站點查詢**：瀏覽全台灣所有 YouBike 2.0 站點
- 🔍 **即時搜尋**：快速搜尋站點名稱
- 🚴 **車種區分**：分別顯示一般 YouBike 2.0 和電輔車數量
- 🔔 **推播通知**：車輛數量變化時即時通知（區分 YB2/電輔車）
- 📊 **即時監控**：選擇站點進行持續監控
- 🌙 **背景執行**：即使螢幕關閉也能持續監控
- ⚙️ **客製化門檻**：設定車輛數量變化的通知門檻

## 技術架構

- **框架**：Flutter 3.x
- **語言**：Dart
- **狀態管理**：StatefulWidget
- **本地儲存**：SharedPreferences
- **背景服務**：flutter_foreground_task
- **推播通知**：flutter_local_notifications
- **API**：YouBike 官方 API（全台灣站點資料）

## 專案結構

```
lib/
├── main.dart                          # 應用程式進入點
├── models/
│   └── station.dart                   # 站點資料模型
├── services/
│   ├── api_service.dart               # API 服務（Ubike 資料獲取）
│   ├── notification_service.dart      # 推播通知服務
│   └── foreground_service.dart        # 前景服務（背景監控）
└── screens/
    ├── station_list_screen.dart       # 站點列表畫面
    └── monitor_screen.dart            # 監控畫面
```

## 開發環境設定

### 前置需求

- Flutter SDK 3.0 或以上版本
- Dart SDK 3.0 或以上版本
- Android Studio（Android 開發）或 Xcode（iOS 開發）
- Android SDK（最低支援 API 21）

### 安裝步驟

1. **Clone 專案**
   ```bash
   git clone <repository-url>
   cd ubike_alert
   ```

2. **安裝依賴套件**
   ```bash
   flutter pub get
   ```

3. **檢查 Flutter 環境**
   ```bash
   flutter doctor
   ```

4. **執行應用程式**

   - **Android 裝置/模擬器**：
     ```bash
     flutter run
     ```

   - **指定裝置**：
     ```bash
     flutter devices  # 查看可用裝置
     flutter run -d <device-id>
     ```

### Android 開發設定

1. **必要權限**（已在 `AndroidManifest.xml` 中配置）：
   - `INTERNET` - 網路存取
   - `POST_NOTIFICATIONS` - 推播通知（Android 13+）
   - `FOREGROUND_SERVICE` - 前景服務
   - `FOREGROUND_SERVICE_DATA_SYNC` - 資料同步前景服務
   - `WAKE_LOCK` - 保持喚醒

2. **Core Library Desugaring**：
   專案已啟用 Java 8+ 特性支援，無需額外設定。

### iOS 開發設定

1. **安裝 CocoaPods**（如尚未安裝）：
   ```bash
   sudo gem install cocoapods
   ```

2. **安裝 iOS 依賴**：
   ```bash
   cd ios
   pod install
   cd ..
   ```

3. **權限設定**：
   在 `ios/Runner/Info.plist` 中已配置通知權限。

## 主要依賴套件

```yaml
dependencies:
  http: ^1.1.0                           # HTTP 請求
  flutter_local_notifications: ^17.0.0   # 本地推播通知
  shared_preferences: ^2.2.2             # 本地資料儲存
  permission_handler: ^11.1.0            # 權限管理
  flutter_foreground_task: ^8.0.0        # 前景服務/背景執行
```

## API 資料來源

本應用程式使用 YouBike 官方 API，支援**全台灣**的 YouBike 2.0 站點資訊。

### API 執行流程

1. **打開 APP** → 呼叫站點列表 API 取得全台站點基本資訊
2. **點選站點** → 呼叫停車資訊 API 取得該站點的即時可借還車輛資訊
3. **刷新資料** → 再次呼叫停車資訊 API 更新最新數據
4. **背景監控** → 每 60 秒自動呼叫停車資訊 API 檢查變化

### YouBike 站點列表 API

- **API 端點**：
  ```
  GET https://apis.youbike.com.tw/json/station-min-yb2.json
  ```

- **用途**：取得全台灣所有 YouBike 2.0 站點的基本資訊
- **更新頻率**：約每分鐘更新一次
- **資料格式**：JSON 陣列
- **主要欄位**：
  - `station_no`：站點編號
  - `name_tw`：站點名稱（中文）
  - `district_tw`：行政區
  - `address_tw`：站點地址
  - `lat` / `lng`：經緯度座標
  - `status`：站點狀態

### YouBike 停車資訊 API

- **API 端點**：
  ```
  POST https://apis.youbike.com.tw/tw2/parkingInfo
  ```

- **用途**：取得特定站點的即時可借還車輛詳細資訊
- **更新頻率**：即時資料
- **請求格式**：
  ```json
  {
    "station_no": ["500203020"]
  }
  ```
- **回應格式**：JSON
- **主要欄位**：
  - `station_no`：站點編號
  - `parking_spaces`：總停車位
  - `available_spaces`：可借車輛總數
  - `available_spaces_detail`：
    - `yb2`：一般 YouBike 2.0 可借數量
    - `eyb`：電輔車可借數量
  - `empty_spaces`：可還空位數
  - `status`：站點狀態

### 資料特色

- **全台灣覆蓋**：支援台北市、新北市、桃園市、台中市、台南市、高雄市等所有縣市的 YouBike 2.0 站點
- **車種區分**：清楚區分一般 YouBike 2.0 和電輔車的數量
- **即時更新**：API 提供即時資料，無需等待政府開放資料平台的排程更新
- **統一格式**：所有縣市使用相同的資料格式，無需額外轉換

### 限制說明

- **僅支援 YouBike 2.0**：不包含 YouBike 1.0 站點
- **網路連線需求**：需要網路連線才能取得即時資料
- **API 可用性**：依賴 YouBike 官方 API 的服務穩定性

## 開發指南

### 新增功能

1. 在適當的目錄下創建新檔案
2. 遵循現有的程式碼風格和架構
3. 更新相關的服務或模型
4. 測試新功能

### 除錯技巧

1. **查看即時 Log**：
   ```bash
   flutter run -d <device-id>
   ```
   執行後會持續顯示應用程式的執行日誌

2. **查看背景服務 Log**：
   背景服務會定期輸出「檢查站點資料」和「目前車輛數」等訊息

3. **Android Debug Bridge**：
   ```bash
   adb logcat | grep flutter
   ```

### 建置發布版本

1. **Android APK**：
   ```bash
   flutter build apk --release
   ```
   輸出位置：`build/app/outputs/flutter-apk/app-release.apk`

2. **Android App Bundle**（Google Play 上架）：
   ```bash
   flutter build appbundle --release
   ```
   輸出位置：`build/app/outputs/bundle/release/app-release.aab`

3. **iOS**：
   ```bash
   flutter build ios --release
   ```

## 常見問題

### Q: 為什麼推播通知沒有出現？
A: 請確認已授予應用程式通知權限。在 Android 13+ 裝置上，首次啟動時會要求通知權限。

### Q: 背景監控會不會很耗電？
A: 應用程式使用前景服務，每分鐘才檢查一次資料，電量消耗相對較低。系統會在通知欄顯示監控狀態。

### Q: 可以同時監控多個站點嗎？
A: 目前版本僅支援單一站點監控。切換到新站點時會自動停止前一個站點的監控。

### Q: 螢幕關閉後還會監控嗎？
A: 是的，應用程式使用前景服務確保即使螢幕關閉也能持續監控。

## 授權

本專案僅供個人學習和使用。

## 聯絡資訊

如有問題或建議，歡迎開啟 Issue。
