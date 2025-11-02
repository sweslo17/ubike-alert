# API Key 安全配置總結

## 📁 檔案結構

```
ubike-alert/
├── .env                              # ✅ Flutter 使用（已在 .gitignore）
├── .env.example                      # ✅ 範本（可提交）
├── android/
│   ├── local.properties              # ✅ Android 使用（已在 .gitignore）
│   ├── local.properties.example      # ✅ 範本（可提交）
│   └── app/
│       ├── build.gradle.kts          # ✅ 從 local.properties 讀取
│       └── src/main/AndroidManifest.xml  # ✅ 使用 ${GOOGLE_MAPS_API_KEY}
└── ios/
    └── Runner/
        └── AppDelegate.swift         # ⚠️ 需手動替換（暫無自動化）
```

---

## 🔐 API Key 存放位置

### Android (已完成自動化)
```properties
# android/local.properties
GOOGLE_MAPS_API_KEY=你的_API_KEY
```

**工作流程：**
1. `local.properties` 存放 API Key
2. `build.gradle.kts` 讀取 → 設為 `manifestPlaceholders`
3. `AndroidManifest.xml` 使用 `${GOOGLE_MAPS_API_KEY}`
4. 編譯時自動注入

### iOS (需手動設置)
```swift
// ios/Runner/AppDelegate.swift
GMSServices.provideAPIKey("你的_API_KEY")
```

**注意：** iOS 目前需要手動替換，未來可以改用 xcconfig 自動化

### Flutter (已完成)
```env
# .env
GOOGLE_MAPS_API_KEY=你的_API_KEY
```

**工作流程：**
1. `.env` 存放 API Key
2. `main.dart` 使用 `flutter_dotenv` 讀取
3. `AppConfig.googleMapsApiKey` 提供存取

---

## ✅ 優點

### 1. 安全性
- ✅ API Key 不會出現在 Git 歷史中
- ✅ `local.properties` 和 `.env` 都在 `.gitignore` 中
- ✅ 每個開發者使用自己的 API Key

### 2. 協作性
- ✅ 提供 `.env.example` 和 `local.properties.example` 範本
- ✅ 新成員可快速設置
- ✅ 不會意外覆蓋別人的配置

### 3. CI/CD 友好
- ✅ 可在 CI 環境中動態注入
- ✅ 支援多環境配置（dev/staging/prod）

---

## 🚀 快速設置指南

### 新開發者設置流程

```bash
# 1. Clone 專案
git clone <repo-url>
cd ubike-alert

# 2. 設置 Flutter 環境變數
cp .env.example .env
# 編輯 .env，填入 GOOGLE_MAPS_API_KEY

# 3. 設置 Android 環境變數
# Android 的 local.properties 通常會自動生成
# 手動添加以下內容到 android/local.properties
echo "GOOGLE_MAPS_API_KEY=你的_API_KEY" >> android/local.properties

# 4. 設置 iOS (手動)
# 編輯 ios/Runner/AppDelegate.swift
# 將 YOUR_GOOGLE_MAPS_API_KEY_HERE 替換為實際的 Key

# 5. 安裝依賴
flutter pub get
cd ios && pod install && cd ..

# 6. 執行
flutter run
```

---

## 🔍 驗證設置

### 檢查 Git 狀態
```bash
git status

# ✅ 確認以下檔案不在列表中：
# - .env
# - android/local.properties
```

### 檢查 Android 配置
```bash
# 查看 local.properties（應包含 GOOGLE_MAPS_API_KEY）
cat android/local.properties

# 驗證編譯（會顯示是否成功讀取 API Key）
cd android && ./gradlew assembleDebug
```

### 檢查 Flutter 配置
```bash
flutter run

# 控制台應顯示：
# ✅ 環境變數載入成功
```

---

## 🛠️ 進階配置

### 多環境支援

如需區分開發、測試、生產環境：

#### Flutter (.env)
```bash
.env.development
.env.staging
.env.production
```

在 `main.dart` 中：
```dart
await dotenv.load(fileName: ".env.$environment");
```

#### Android (local.properties)
```properties
# 使用不同的 key 名稱
GOOGLE_MAPS_API_KEY_DEV=...
GOOGLE_MAPS_API_KEY_PROD=...
```

在 `build.gradle.kts` 中根據 buildType 選擇：
```kotlin
val apiKey = when (buildType) {
    "debug" -> localProperties.getProperty("GOOGLE_MAPS_API_KEY_DEV")
    "release" -> localProperties.getProperty("GOOGLE_MAPS_API_KEY_PROD")
    else -> "YOUR_API_KEY_HERE"
}
```

---

## 📝 CI/CD 配置

### GitHub Actions 範例

```yaml
name: Build Android

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Setup Flutter
      uses: subosito/flutter-action@v2

    - name: Create .env file
      run: echo "GOOGLE_MAPS_API_KEY=${{ secrets.GOOGLE_MAPS_API_KEY }}" > .env

    - name: Add API Key to local.properties
      run: echo "GOOGLE_MAPS_API_KEY=${{ secrets.GOOGLE_MAPS_API_KEY }}" >> android/local.properties

    - name: Build APK
      run: flutter build apk --release
```

**設置 GitHub Secrets：**
1. 前往 Repository Settings → Secrets and variables → Actions
2. 新增 Secret：`GOOGLE_MAPS_API_KEY`
3. 值填入實際的 API Key

---

## ⚠️ 常見問題

### Q1: AndroidManifest.xml 中還能看到 ${GOOGLE_MAPS_API_KEY}？
A: 這是正常的！這是一個 placeholder，編譯時會被 Gradle 替換成實際的值。

### Q2: 編譯時提示 "API key not found"
A: 檢查以下項目：
1. `android/local.properties` 是否存在
2. 檔案中是否有 `GOOGLE_MAPS_API_KEY=...` 這一行
3. API Key 是否正確（不包含空格）

### Q3: iOS 能自動讀取 .env 嗎？
A: 目前不行。iOS 需要手動設置在 `AppDelegate.swift` 中。
   未來可以使用 `.xcconfig` 檔案實現自動化。

### Q4: 如何在發布時保護 API Key？
A: 建議使用 API Key 限制：
- **Android**: 限制套件名稱 + SHA-1 指紋
- **iOS**: 限制 Bundle ID
- **兩者**: 限制 API（只開啟 Maps SDK）

---

## 🎓 延伸閱讀

- [Google Maps API Key 最佳實踐](https://cloud.google.com/docs/authentication/api-keys)
- [Android Gradle 配置](https://developer.android.com/studio/build/gradle-tips)
- [flutter_dotenv 套件文件](https://pub.dev/packages/flutter_dotenv)
- [保護 Android 應用程式中的 API Key](https://developer.android.com/studio/publish/app-signing)

---

✅ **你現在已經完成安全的 API Key 配置！**

API Key 完全從版本控制中隔離，可以安全地提交程式碼到 GitHub。
