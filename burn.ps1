param (
    [Parameter(Mandatory = $true)]
    [string]$NFT_ID
)
. "$PSScriptRoot\iota-json.ps1"
# ===================================================
# 0. 共用 JSON Parser
# ===================================================

function Parse-IotaJson {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$RawOutput
    )

    $text = ($RawOutput -join "`n")

    # 嘗試所有可能的 JSON 區塊（object 或 array）
    $matches = [regex]::Matches(
        $text,
        '(?s)(\{.*?\}|\[.*?\])'
    )

    foreach ($m in $matches) {
        try {
            return $m.Value | ConvertFrom-Json
        } catch {
            continue
        }
    }

    return $null
}

# ===================================================
# 1. 環境準備（讀取 .env）
# ===================================================

$EnvFile = ".env"

if (-Not (Test-Path $EnvFile)) {
    Write-Host "❌ 錯誤: 找不到 .env 檔案"
    exit 1
}

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

if (-Not $Env:PACKAGE_ID) {
    Write-Host "❌ 錯誤: .env 中找不到 PACKAGE_ID"
    exit 1
}

# ===================================================
# 2. 執行 Burn
# ===================================================

Write-Host "🔥 正在燒毀 NFT: $NFT_ID"
Write-Host "💰 NFT 內的 AWESOME 將退回給呼叫者"

$BURN_RES = iota client call `
    --package $Env:PACKAGE_ID `
    --module "pic_display" `
    --function "burn" `
    --args $NFT_ID `
    --gas-budget 30000000 `
    --json 

# ===================================================
# 3. 交易結果判斷（只看 exit code）
# ===================================================

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Burn 交易失敗"
    $BURN_RES | Select-String "error" | Select-Object -First 10
    exit 1
}

# ===================================================
# 4. 輔助解析 JSON（非關鍵路徑）
# ===================================================

$json = Parse-IotaJson $BURN_RES

$COIN_ID = $null

if ($json -and $json.objectChanges) {
    $COIN_ID = $json.objectChanges |
        Where-Object {
            $_.type -eq "created" -and
            $_.objectType -like "*::coin::Coin<*awesome::AWESOME*>*"
        } |
        Select-Object -ExpandProperty objectId -First 1
}

# ===================================================
# 5. 最終輸出
# ===================================================

Write-Host "=================================================="
Write-Host "✅ Burn 成功"
Write-Host "🗑️  NFT Object ID 已銷毀:"
Write-Host "    $NFT_ID"

if ($COIN_ID) {
    Write-Host "💰 AWESOME Coin 已退回"
    Write-Host "🪙 Coin Object ID:"
    Write-Host "    $COIN_ID"
} else {
    Write-Host "ℹ️  AWESOME 已退回（Coin 可能被自動合併）"
}

Write-Host "👉 請以 Explorer / 錢包餘額為準"
Write-Host "=================================================="
