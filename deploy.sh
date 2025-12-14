#!/bin/bash

# ===================================================
# 0. 前置檢查
# ===================================================
if ! command -v iota &> /dev/null; then echo "❌ 錯誤: 找不到 'iota' 指令"; exit 1; fi
if ! command -v jq &> /dev/null; then echo "❌ 錯誤: 找不到 'jq' 指令"; exit 1; fi

TARGET_ENV="testnet"
CURRENT_ENV=$(iota client active-env)
echo "🔍 當前環境: $CURRENT_ENV"

if [ "$CURRENT_ENV" != "$TARGET_ENV" ]; then
    echo "⚠️  警告: 你目前不在 '$TARGET_ENV' 環境！"
    echo "    請先切換環境: iota client switch --env $TARGET_ENV"
    exit 1
fi

# ===================================================
# 1. 執行部署
# ===================================================
echo "🚀 開始建置並部署合約..."

OUTPUT=$(iota client publish --gas-budget 200000000 --json)

if [ $? -ne 0 ]; then
    echo "❌ 部署失敗，請檢查錯誤訊息。"
    exit 1
fi

# ===================================================
# 2. 解析結果 (Package, Vault, TreasuryCap)
# ===================================================

# 2.1 Package ID
PACKAGE_ID=$(echo "$OUTPUT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')
if [ -z "$PACKAGE_ID" ]; then echo "❌ 無法解析 Package ID"; exit 1; fi

# 2.2 Vault ID
VAULT_ID=$(echo "$OUTPUT" | jq -r '.objectChanges[] | select(.type == "created") | select(.objectType | contains("::pic_display::Vault")) | .objectId')

# 2.3 TreasuryCap ID (新增部分)
# 邏輯：尋找 objectType 包含 TreasuryCap 的 created 物件
TREASURY_CAP=$(echo "$OUTPUT" | jq -r '.objectChanges[] | select(.type == "created") | select(.objectType | contains("::coin::TreasuryCap")) | .objectId')

echo "=================================================="
echo "✅ 合約部署成功！"
echo "📦 Package ID : $PACKAGE_ID"
echo "🏦 Vault ID   : $VAULT_ID"
echo "Ez TreasuryCap: $TREASURY_CAP"
echo "=================================================="

# ===================================================
# 3. 儲存設定
# ===================================================

echo "PACKAGE_ID=$PACKAGE_ID" > .env
echo "VAULT_ID=$VAULT_ID" >> .env
echo "TREASURY_CAP=$TREASURY_CAP" >> .env  # 將 TreasuryCap 寫入 .env

echo "💾 已將設定儲存至 .env 檔案。"