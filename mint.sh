#!/bin/bash

# 1. 載入環境變數
if [ -f .env ]; then
    source .env
else
    echo "❌ 找不到 .env 檔案。請先執行 ./deploy.sh"
    exit 1
fi

# 檢查變數是否存在
if [ -z "$PACKAGE_ID" ]; then
    echo "❌ .env 中找不到 PACKAGE_ID"
    exit 1
fi

echo "🎨 正在呼叫 Mint 函數..."
echo "目標 Package: $PACKAGE_ID"

# 定義參數
MODULE_NAME="pic_display"
FUNC_NAME="mint"
# 這裡只傳入名字，圖片 URL 由合約內部的隨機邏輯生成
ARG_NAME="Lucky Hero #$(date +%s)" 

# 2. 執行交易
# 注意：--args 只需要傳入名字字串
RESULT=$(iota client call \
    --package "$PACKAGE_ID" \
    --module "$MODULE_NAME" \
    --function "$FUNC_NAME" \
    --args "$ARG_NAME" \
    --gas-budget 30000000 \
    --json)

# 3. 解析結果，抓取新生成的 NFT ID
if [ $? -eq 0 ]; then
    echo "✅ 鑄造成功！"
    
    # 抓取新創建的物件 ID (created object)
    OBJECT_ID=$(echo "$RESULT" | jq -r '.objectChanges[] | select(.type == "created") | .objectId' | head -n 1)
    
    echo "🖼️  NFT Object ID: $OBJECT_ID"
    echo "您可以到 Explorer 查看此物件。"
else
    echo "❌ 交易失敗"
    echo "$RESULT"
fi