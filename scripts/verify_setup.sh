#!/bin/bash

# 顏色定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 驗證 Ubike Alert 配置..."
echo ""

# 檢查 .env 檔案是否存在
if [ -f ".env" ]; then
    echo -e "${GREEN}✅ .env 檔案存在${NC}"
else
    echo -e "${RED}❌ .env 檔案不存在${NC}"
    echo -e "${YELLOW}   請執行: cp .env.example .env${NC}"
    exit 1
fi

# 檢查 .env 是否在 .gitignore 中
if grep -q "^\.env$" .gitignore; then
    echo -e "${GREEN}✅ .env 已加入 .gitignore${NC}"
else
    echo -e "${RED}❌ .env 未加入 .gitignore${NC}"
    exit 1
fi

# 檢查 .env 是否被 git 追蹤
if git ls-files --error-unmatch .env &> /dev/null; then
    echo -e "${RED}❌ 警告！.env 檔案被 Git 追蹤${NC}"
    echo -e "${YELLOW}   請執行: git rm --cached .env${NC}"
    exit 1
else
    echo -e "${GREEN}✅ .env 未被 Git 追蹤${NC}"
fi

# 檢查 .env 中是否有 API Key
if grep -q "GOOGLE_MAPS_API_KEY=YOUR_API_KEY_HERE" .env; then
    echo -e "${YELLOW}⚠️  .env 中的 API Key 尚未設定${NC}"
    echo -e "${YELLOW}   請在 .env 中填入實際的 Google Maps API Key${NC}"
elif grep -q "GOOGLE_MAPS_API_KEY=" .env; then
    # 檢查是否為空
    key_value=$(grep "GOOGLE_MAPS_API_KEY=" .env | cut -d '=' -f 2)
    if [ -z "$key_value" ]; then
        echo -e "${YELLOW}⚠️  GOOGLE_MAPS_API_KEY 為空${NC}"
    else
        echo -e "${GREEN}✅ GOOGLE_MAPS_API_KEY 已設定${NC}"
        # 不顯示實際的 key，只顯示前綴和長度
        key_prefix="${key_value:0:10}"
        key_length="${#key_value}"
        echo -e "   Key 前綴: ${key_prefix}... (長度: ${key_length})"
    fi
else
    echo -e "${RED}❌ .env 中未找到 GOOGLE_MAPS_API_KEY${NC}"
    exit 1
fi

# 檢查 flutter 套件是否安裝
echo ""
echo "📦 檢查 Flutter 相依套件..."
if [ -d ".dart_tool" ]; then
    echo -e "${GREEN}✅ Flutter 套件已安裝${NC}"
else
    echo -e "${YELLOW}⚠️  請執行: flutter pub get${NC}"
fi

# 檢查關鍵套件
echo ""
echo "🔌 檢查必要套件..."
packages=("flutter_dotenv" "google_maps_flutter" "geolocator")
for package in "${packages[@]}"; do
    if grep -q "$package:" pubspec.yaml; then
        echo -e "${GREEN}✅ $package${NC}"
    else
        echo -e "${RED}❌ $package 未安裝${NC}"
    fi
done

# 安全性檢查
echo ""
echo "🔒 安全性檢查..."

# 檢查是否有硬編碼的 API Key（簡單模式匹配）
echo "   檢查程式碼中是否有硬編碼的 API Key..."
if grep -r "AIza[0-9A-Za-z-_]\{35\}" lib/ --exclude-dir=.dart_tool 2>/dev/null | grep -v "TODO\|EXAMPLE\|your-api-key"; then
    echo -e "${RED}❌ 警告！發現可能的硬編碼 API Key${NC}"
else
    echo -e "${GREEN}✅ 未發現硬編碼的 API Key${NC}"
fi

# 最終總結
echo ""
echo "======================================"
echo -e "${GREEN}🎉 驗證完成！${NC}"
echo "======================================"
echo ""
echo "下一步："
echo "1. 確認 .env 中的 API Key 正確"
echo "2. 執行: flutter pub get"
echo "3. 執行: flutter run"
echo ""
