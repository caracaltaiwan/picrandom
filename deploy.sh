#!/bin/bash

# ===================================================
# 0. 前置檢查
# ===================================================

# 檢查是否安裝了 iota cli
if ! command -v iota &> /dev/null; then
    echo "❌ 錯誤: 找不到 'iota' 指令，請確保已安裝 IOTA CLI。"
    exit 1
fi

# 檢查是否安裝了 jq
if ! command -v jq &> /dev/null; then
    echo "❌ 錯誤: 找不到 'jq' 指令。請安裝 jq 以解析 JSON 輸出 (例如: brew install jq)。"
    exit 1
fi

# --- 新增：檢查是否在 Testnet ---
TARGET_ENV="testnet"
CURRENT_ENV=$(iota client active-env)

echo "🔍 當前環境: $CURRENT_ENV"

if [ "$CURRENT_ENV" != "$TARGET_ENV" ]; then
    echo "⚠️  警告: 你目前不在 '$TARGET_ENV' 環境！"
    echo "    請先切換環境: iota client switch --env $TARGET_ENV"
    echo "    或者檢查你的環境設定: iota client envs"
    exit 1
fi

# ===================================================
# 1. 執行部署
# ===================================================

echo "🚀 環境確認無誤 ($CURRENT_ENV)，開始建置並部署合約..."

# 發布合約並獲取 JSON 輸出
# 注意：--gas-budget 設定為 2億
OUTPUT=$(iota client publish --gas-budget 200000000 --json)

# 檢查部署指令的 exit code
if [ $? -ne 0 ]; then
    echo "❌ 部署失敗，請檢查上方錯誤訊息。"
    exit 1
fi

# ===================================================
# 2. 解析結果
# ===================================================

# 使用 jq 解析 JSON，提取 Package ID
PACKAGE_ID=$(echo "$OUTPUT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')

if [ -z "$PACKAGE_ID" ]; then
    echo "❌ 無法解析 Package ID，請檢查輸出格式。"
    exit 1
fi

echo "✅ 合約部署成功！"
echo "📦 Package ID: $PACKAGE_ID"

# ===================================================
# 3. 儲存設定
# ===================================================

# 將變數寫入 .env 檔案
echo "PACKAGE_ID=$PACKAGE_ID" > .env

echo "💾 已將 Package ID 儲存至 .env 檔案。"