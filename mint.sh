#!/bin/bash

# ===================================================
# 0. 環境準備 (直接讀取 .env)
# ===================================================

# 檢查 .env 檔案
if [ -f .env ]; then
    source .env
else
    echo "❌ 錯誤: 找不到 .env 檔案"
    exit 1
fi

# 檢查 PACKAGE_ID
if [ -z "$PACKAGE_ID" ]; then 
    echo "❌ 錯誤: .env 中找不到 PACKAGE_ID" 
    exit 1 
fi

# [關鍵修正] 直接從 .env 讀取 VAULT_ID，不再使用 iota client objects 搜尋
if [ -z "$VAULT_ID" ]; then 
    echo "❌ 錯誤: .env 中找不到 VAULT_ID"
    echo "   請確認您已使用最新版的 ./deploy.sh 重新部署合約。"
    exit 1 
else
    echo "✅ 讀取 Vault ID: $VAULT_ID"
fi

# ===================================================
# 1. 執行鑄造
# ===================================================

NFT_NAME="Lucky User #$(date +%s)"

echo "🎨 正在從 Vault 提取資金並鑄造 NFT: '$NFT_NAME'..."

# 呼叫 Mint 函數
# 參數 1: Vault ID (Shared Object)
# 參數 2: NFT 名稱
MINT_RES=$(iota client call \
    --package "$PACKAGE_ID" \
    --module "pic_display" \
    --function "mint" \
    --args "$VAULT_ID" "$NFT_NAME" \
    --gas-budget 50000000 \
    --json)

if [ $? -eq 0 ]; then
    # 解析新產生的 NFT ID
    NFT_ID=$(echo "$MINT_RES" | jq -r --arg PKG "$PACKAGE_ID" '
        .objectChanges[] | 
        select(.type == "created") | 
        select(.objectType | contains($PKG + "::pic_display::Awesome_NFT")) | 
        .objectId
    ')
    
    echo "=================================================="
    echo "🎉 鑄造成功！"
    echo "🖼️  NFT Object ID: $NFT_ID"
    echo "💰 已自動從 Vault 獲取 50 AWESOME 代幣"
    echo "👉 請至 Explorer 查看該 NFT 的 Display 與 Balance"
    echo "=================================================="
else
    echo "❌ 鑄造失敗"
    # 嘗試印出錯誤訊息
    echo "$MINT_RES" | grep "error" | head -n 5
fi