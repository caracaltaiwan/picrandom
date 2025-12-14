#!/bin/bash

# ===================================================
# 0. 環境準備 (全部從 .env 讀取)
# ===================================================

# 檢查 .env 檔案是否存在
if [ -f .env ]; then
    source .env
    echo "mb 載入 .env 設定檔..."
else
    echo "❌ 錯誤: 找不到 .env 檔案"
    exit 1
fi

# 檢查變數是否都齊全
if [ -z "$PACKAGE_ID" ]; then echo "❌ 錯誤: .env 缺 PACKAGE_ID"; exit 1; fi
if [ -z "$VAULT_ID" ]; then echo "❌ 錯誤: .env 缺 VAULT_ID"; exit 1; fi

# [修改] 直接檢查 .env 裡有沒有 TreasuryCap
if [ -z "$TREASURY_CAP" ]; then 
    echo "❌ 錯誤: .env 中找不到 TREASURY_CAP。"
    echo "   請確認您使用的是最新版的 ./deploy.sh 並已重新部署。"
    exit 1 
else
    echo "✅ 從 .env 讀取到 TreasuryCap: $TREASURY_CAP"
fi

USER_ADDR=$(iota client active-address)
TOKEN_MODULE="awesome"
TOKEN_STRUCT="AWESOME"
VAULT_MODULE="pic_display"
TOTAL_AMOUNT=54250

echo "=================================================="
echo "👤 當前用戶: $USER_ADDR"
echo "💰 準備將 $TOTAL_AMOUNT $TOKEN_STRUCT 存入 Vault"
echo "=================================================="

# ===================================================
# 1. 鑄造代幣 (Mint Coin)
# ===================================================
echo "💸 步驟 1/2: 印製代幣..."

# 直接使用變數 $TREASURY_CAP
MINT_RES=$(iota client call --package "$PACKAGE_ID" --module "$TOKEN_MODULE" --function "mint_for_testing" --args "$TREASURY_CAP" "$TOTAL_AMOUNT" "$USER_ADDR" --gas-budget 50000000 --json)

if [ $? -ne 0 ]; then
    echo "❌ 鑄造失敗"
    exit 1
fi

# 抓取新代幣 ID
COIN_ID=$(echo "$MINT_RES" | jq -r --arg PKG "$PACKAGE_ID" --arg MOD "$TOKEN_MODULE" --arg STR "$TOKEN_STRUCT" '
    .objectChanges[] | 
    select(.type == "created") | 
    select(.objectType | contains($PKG + "::" + $MOD + "::" + $STR)) | 
    .objectId
')

if [ -z "$COIN_ID" ]; then
    echo "❌ 無法抓取新鑄造的 Coin ID"
    exit 1
fi
echo "   -> 新代幣 ID: $COIN_ID"

# ===================================================
# 2. 存入 Vault (Deposit)
# ===================================================
echo "🏦 步驟 2/2: 存入 Vault..."

DEPOSIT_RES=$(iota client call \
    --package "$PACKAGE_ID" \
    --module "$VAULT_MODULE" \
    --function "deposit_to_vault" \
    --args "$VAULT_ID" "$COIN_ID" \
    --gas-budget 50000000 \
    --json)

if [ $? -eq 0 ]; then
    echo "🎉 資金注入完成！Vault 現在已準備好運作。"
else
    echo "❌ 存入失敗"
    echo "$DEPOSIT_RES" | grep "error"
fi