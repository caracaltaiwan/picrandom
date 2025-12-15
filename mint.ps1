# ===================================================
# 0. 環境準備 (直接讀取 .env)
# ===================================================
. "$PSScriptRoot\iota-json.ps1"
$EnvFile = ".env"

if (-Not (Test-Path $EnvFile)) {
    Write-Host "❌ 錯誤: 找不到 .env 檔案"
    exit 1
}

# 讀取 .env (KEY=VALUE)
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*#') { return }
    if ($_ -match '^\s*$') { return }

    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) {
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        Set-Item -Path "Env:$key" -Value $value
    }
}

# 檢查 PACKAGE_ID
if (-Not $Env:PACKAGE_ID) {
    Write-Host "❌ 錯誤: .env 中找不到 PACKAGE_ID"
    exit 1
}

# 檢查 VAULT_ID
if (-Not $Env:VAULT_ID) {
    Write-Host "❌ 錯誤: .env 中找不到 VAULT_ID"
    Write-Host "   請確認您已使用最新版的 ./deploy.sh 重新部署合約。"
    exit 1
} else {
    Write-Host "✅ 讀取 Vault ID: $($Env:VAULT_ID)"
}

# ===================================================
# 1. 執行鑄造
# ===================================================

$Timestamp = [int][double]::Parse((Get-Date -UFormat %s))
$NFT_NAME = "Lucky User #$Timestamp"

Write-Host "🎨 正在從 Vault 提取資金並鑄造 NFT: '$NFT_NAME'..."

# 呼叫 Mint 函數
$MINT_RES = iota client call `
    --package $Env:PACKAGE_ID `
    --module "pic_display" `
    --function "mint" `
    --args $Env:VAULT_ID $NFT_NAME `
    --gas-budget 50000000 `
    --json

# =========== 【加入這段程式碼來除錯】 ===========
# Write-Host "DEBUG: 原始回傳內容如下:" -ForegroundColor Cyan
# $MINT_RES | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
# Write-Host "-------------------------------------"
# ==============================================

if ($LASTEXITCODE -eq 0) {

    # 解析 JSON
    $json = Parse-IotaJson $MINT_RES

    $NFT_ID = $json.objectChanges |
        Where-Object {
            $_.type -eq "created" -and
            $_.objectType -like "*$($Env:PACKAGE_ID)::pic_display::Awesome_NFT*"
        } |
        Select-Object -ExpandProperty objectId -First 1

    Write-Host "=================================================="
    Write-Host "🎉 鑄造成功！"
    Write-Host "🖼️  NFT Object ID: $NFT_ID"
    Write-Host "💰 已自動從 Vault 獲取 50 AWESOME 代幣"
    Write-Host "👉 請至 Explorer 查看該 NFT 的 Display 與 Balance"
    Write-Host "=================================================="

} else {
    Write-Host "❌ 鑄造失敗"
    $MINT_RES | Select-String "error" | Select-Object -First 5
}
