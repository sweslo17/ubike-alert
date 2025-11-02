# 安全配置說明

## 🔐 API Key 管理

本專案使用 **環境變數** 來管理敏感資訊（如 Google Maps API Key），避免將密鑰提交到版本控制系統。

---

## 📁 檔案結構

```
ubike-alert/
├── .env                    # ❌ 實際的 API Keys（不提交到 Git）
├── .env.example            # ✅ API Key 範本（可提交）
├── .gitignore              # ✅ 忽略 .env 檔案
├── SETUP.md                # 設置指南
├── lib/
│   └── config/
│       └── app_config.dart # Dart 配置管理類別
└── ...
```

---

## 🛡️ 安全最佳實踐

### 1. 環境變數管理
- ✅ **DO**: 使用 `.env` 檔案存放敏感資訊
- ✅ **DO**: 將 `.env` 加入 `.gitignore`
- ✅ **DO**: 提供 `.env.example` 作為範本
- ❌ **DON'T**: 將實際的 API Key 硬編碼在程式碼中
- ❌ **DON'T**: 將 `.env` 提交到 Git

### 2. API Key 限制
建議在 Google Cloud Console 設定以下限制：

#### Android API Key
```
應用程式限制：Android 應用程式
允許的套件名稱：com.example.ubike_alert
允許的 SHA-1 憑證指紋：[你的 SHA-1]
API 限制：Maps SDK for Android
```

#### iOS API Key
```
應用程式限制：iOS 應用程式
允許的 Bundle ID：com.example.ubikeAlert
API 限制：Maps SDK for iOS
```

### 3. 定期輪替
- 建議每 **3-6 個月** 更換一次 API Key
- 發現洩露時立即撤銷並重新產生
- 保留舊 Key 的歷史記錄（以防回滾）

---

## 🔍 驗證安全性

### 檢查 .env 是否被忽略
```bash
git status
# 確認 .env 不在列表中
```

### 檢查歷史記錄中是否有洩露
```bash
# 搜尋可能的 API Key 模式
git log -p | grep -i "AIza"

# 如果發現洩露，需要清理 Git 歷史
# 參考：https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
```

### 使用 git-secrets 防止意外提交
```bash
# 安裝 git-secrets
brew install git-secrets  # macOS
# 或參考：https://github.com/awslabs/git-secrets

# 設定掃描規則
cd /path/to/ubike-alert
git secrets --install
git secrets --register-aws  # 掃描 AWS keys
git secrets --add 'AIza[0-9A-Za-z-_]{35}'  # Google API Key 模式

# 掃描現有倉庫
git secrets --scan
```

---

## 🚨 萬一 API Key 洩露了怎麼辦？

### 立即行動清單

1. **撤銷 API Key**
   - 前往 [Google Cloud Console](https://console.cloud.google.com/)
   - 刪除或禁用洩露的 API Key

2. **產生新的 API Key**
   - 產生新的 Key
   - 設定更嚴格的限制
   - 更新 `.env` 檔案

3. **清理 Git 歷史**（如果已推送到 GitHub）
   ```bash
   # 使用 BFG Repo-Cleaner 或 git filter-branch
   # 參考 GitHub 官方指南
   ```

4. **通知團隊成員**
   - 通知所有有存取權限的人員
   - 要求更新本地配置

5. **監控使用量**
   - 檢查 Google Cloud Console 的使用量圖表
   - 確認是否有異常請求

---

## 📚 相關資源

- [Google API Key Best Practices](https://cloud.google.com/docs/authentication/api-keys)
- [flutter_dotenv 套件文件](https://pub.dev/packages/flutter_dotenv)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub: Removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)

---

## ✅ 檢查清單

在提交程式碼前，請確認：

- [ ] `.env` 檔案已加入 `.gitignore`
- [ ] 沒有在程式碼中硬編碼 API Key
- [ ] 已提供 `.env.example` 範本
- [ ] API Key 已設定應用程式限制
- [ ] 已撰寫 SETUP.md 給其他開發者參考
- [ ] `git status` 確認 `.env` 未被追蹤
- [ ] 已測試從 `.env` 正確載入配置

---

## 🤝 貢獻者指南

如果你是新的貢獻者：

1. Clone 專案後，執行 `cp .env.example .env`
2. 在 `.env` 中填入你自己的 API Key（不要使用他人的）
3. 絕對不要提交 `.env` 檔案
4. 如果需要新的環境變數，更新 `.env.example`

---

## 💡 進階配置

### 多環境支援

如果需要區分開發、測試、生產環境：

```bash
.env.development    # 開發環境
.env.staging        # 測試環境
.env.production     # 生產環境
```

在 `main.dart` 中根據環境載入：
```dart
await dotenv.load(fileName: ".env.$environment");
```

### CI/CD 配置

在 GitHub Actions 中使用 Secrets：

```yaml
# .github/workflows/build.yml
- name: Create .env file
  run: echo "GOOGLE_MAPS_API_KEY=${{ secrets.GOOGLE_MAPS_API_KEY }}" > .env
```

---

如有任何安全相關問題，請聯絡專案維護者。
