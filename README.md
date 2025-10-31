# Ubike Alert

一個即時監控 Ubike 站點車輛數量的 Flutter 應用程式，支援背景監控和推播通知。

**注意：本應用程式僅支援台北市和新北市的 Ubike 2.0 站點。**

## 功能特色

- 📍 **站點查詢**：瀏覽台北市和新北市所有 Ubike 站點
- 🔍 **即時搜尋**：快速搜尋站點名稱
- ⏱️ **自動更新**：每分鐘自動刷新所有站點資料
- 🔔 **推播通知**：車輛數量變化時即時通知
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
- **API**：台北市政府開放資料平台、新北市政府開放資料平台

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

本應用程式整合雙北地區的 Ubike 2.0 開放資料 API，僅支援**台北市**和**新北市**的站點資訊。

### 台北市 Ubike 2.0 即時資訊

- **API 端點**：
  ```
  https://tcgbusfs.blob.core.windows.net/dotapp/youbike/v2/youbike_immediate.json
  ```

- **資料提供單位**：台北市政府交通局
- **更新頻率**：約每分鐘更新一次
- **資料格式**：JSON
- **主要欄位**：
  - `sno`：站點代號
  - `sna`：站點名稱（中文）
  - `sarea`：行政區
  - `ar`：站點地址
  - `sbi`：可借車輛數
  - `bemp`：可還空位數
  - `tot`：總停車格數
  - `mday`：資料更新時間

### 新北市 Ubike 2.0 即時資訊

- **API 端點**：
  ```
  https://data.ntpc.gov.tw/api/datasets/010e5b15-3823-4b20-b401-b1cf000550c5/json
  ```

- **資料提供單位**：新北市政府交通局
- **更新頻率**：約每分鐘更新一次
- **資料格式**：JSON
- **主要欄位**：
  - `sno`：站點代號
  - `sna`：站點名稱（中文）
  - `sarea`：行政區
  - `ar`：站點地址
  - `available_rent_bikes`：可借車輛數
  - `available_return_bikes`：可還空位數
  - `infoTime`：資料更新時間

### 資料整合說明

應用程式會同時呼叫兩個 API，並將資料整合為統一格式。由於新北市 API 的欄位名稱與台北市不同，程式會自動進行欄位對應轉換：

- 新北市的 `available_rent_bikes` → 台北市格式的 `sbi`
- 新北市的 `available_return_bikes` → 台北市格式的 `bemp`
- 新北市的 `infoTime` → 台北市格式的 `mday`

### 限制說明

- **僅支援雙北地區**：目前僅整合台北市和新北市的資料，不支援其他縣市（如桃園、台中等）
- **僅支援 Ubike 2.0**：不包含 Ubike 1.0 站點
- **網路連線需求**：需要網路連線才能取得即時資料
- **API 可用性**：依賴政府開放資料平台的服務穩定性

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
