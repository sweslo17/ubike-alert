# 開發環境設置指南

## 1. 設置 Google Maps API Key

### 步驟 1：複製環境變數範本
```bash
cp .env.example .env
```

### 步驟 2：取得 Google Maps API Key

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 建立新專案或選擇現有專案
3. 啟用以下 API：
   - Maps SDK for Android
   - Maps SDK for iOS
4. 前往「憑證」頁面
5. 點擊「建立憑證」→「API 金鑰」
6. 複製產生的 API Key

### 步驟 3：填入 API Key

編輯 `.env` 檔案：
```env
GOOGLE_MAPS_API_KEY=你的_API_KEY
```

### 步驟 4：設置 Android

編輯 `android/local.properties`，添加 Google Maps API Key：

```properties
# 在檔案末尾添加
GOOGLE_MAPS_API_KEY=你的_API_KEY
```

**注意：**
- `local.properties` 已加入 `.gitignore`，不會被提交到 Git
- `AndroidManifest.xml` 會自動從 `local.properties` 讀取 API Key
- 可以參考 `android/local.properties.example` 範本

**（建議）限制 API Key：**
- 應用程式限制：Android 應用程式
- 新增套件名稱：`com.ubikeapp.ubike_alert`
- 新增 SHA-1 憑證指紋：
  ```bash
  # Debug 版本
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```

### 步驟 5：設置 iOS

編輯 `ios/Runner/AppDelegate.swift`，將 API Key 改為你的：

```swift
GMSServices.provideAPIKey("你的_API_KEY")
```

**（建議）限制 API Key：**
- 應用程式限制：iOS 應用程式
- 新增 Bundle ID：`com.example.ubikeAlert`

---

## 2. 安裝相依套件

```bash
flutter pub get
```

iOS 需要額外安裝 CocoaPods：
```bash
cd ios
pod install
cd ..
```

---

## 3. 執行應用程式

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# 或選擇裝置
flutter devices
flutter run -d <device-id>
```

---

## 4. 建置發布版本

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle (Google Play)
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

---

## ⚠️ 重要安全提醒

1. **絕對不要**將 `.env` 檔案提交到 Git
2. `.env` 已加入 `.gitignore`，請確認未被追蹤：
   ```bash
   git status
   # 確認 .env 不在列表中
   ```
3. 定期輪替 API Key（建議每 3-6 個月）
4. 為不同環境使用不同的 API Key：
   - 開發環境：無限制（方便測試）
   - 生產環境：嚴格限制應用程式和 Bundle ID

---

## 🔍 驗證設置

執行以下命令檢查配置：
```bash
flutter run
```

檢查控制台輸出：
```
環境變數載入成功
```

如果看到以下錯誤：
```
載入 .env 失敗: ...
```

請確認：
1. `.env` 檔案存在於專案根目錄
2. 檔案內容格式正確（參考 `.env.example`）
3. 已執行 `flutter pub get`

---

## 📝 其他配置

### 推播通知測試

Android 需要：
- 已授予通知權限
- 前景服務權限（自動授予）

iOS 需要：
- 在實體裝置上測試（模擬器不支援推播）
- 已授予通知權限

---

## 🐛 常見問題

### Q: 地圖顯示空白
A: 檢查 API Key 是否正確設置，並確認已啟用對應平台的 Maps SDK

### Q: 編譯時出現 "API key not found"
A: 確認 `.env` 檔案存在且格式正確

### Q: iOS 編譯失敗
A: 執行 `cd ios && pod install && cd ..` 重新安裝 CocoaPods 依賴

### Q: Android 地圖不顯示
A: 檢查 SHA-1 指紋是否正確加入 API Key 限制

---

## 📧 需要幫助？

如有問題，請建立 Issue 或聯絡開發者。
