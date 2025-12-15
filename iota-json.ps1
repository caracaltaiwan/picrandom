function Parse-IotaJson {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$RawOutput
    )

    $text = ($RawOutput -join "`n").Trim()

    # 找第一個 JSON 起點（{ 或 [）
    $startObj = $text.IndexOf('{')
    $startArr = $text.IndexOf('[')

    if ($startObj -lt 0 -and $startArr -lt 0) {
        throw "找不到 JSON 起點"
    }

    if ($startObj -lt 0) {
        $start = $startArr
    } elseif ($startArr -lt 0) {
        $start = $startObj
    } else {
        $start = [Math]::Min($startObj, $startArr)
    }

    # 從起點開始，逐步嘗試解析
    for ($end = $text.Length; $end -gt $start; $end--) {
        $candidate = $text.Substring($start, $end - $start)

        try {
            return $candidate | ConvertFrom-Json
        } catch {
            continue
        }
    }

    throw "JSON 解析失敗（無法找到可解析的 JSON 區塊）"
}
