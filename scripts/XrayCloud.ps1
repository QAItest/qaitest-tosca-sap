Set-StrictMode -Version Latest

function Get-XrayCloudBaseUrl {
    param([string]$BaseUrl)

    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        $BaseUrl = $env:XRAY_BASE_URL
    }
    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        $BaseUrl = "https://xray.cloud.getxray.app/api/v2"
    }

    return $BaseUrl.TrimEnd("/")
}

function Get-XrayCloudToken {
    [CmdletBinding()]
    param(
        [string]$ClientId = $env:XRAY_CLIENT_ID,
        [string]$ClientSecret = $env:XRAY_CLIENT_SECRET,
        [string]$BaseUrl = $env:XRAY_BASE_URL
    )

    if ([string]::IsNullOrWhiteSpace($ClientId) -or [string]::IsNullOrWhiteSpace($ClientSecret)) {
        throw "Set XRAY_CLIENT_ID and XRAY_CLIENT_SECRET before calling Xray Cloud."
    }

    $apiBaseUrl = Get-XrayCloudBaseUrl -BaseUrl $BaseUrl
    $body = @{ client_id = $ClientId; client_secret = $ClientSecret } | ConvertTo-Json -Compress
    $token = Invoke-RestMethod `
        -Uri "$apiBaseUrl/authenticate" `
        -Method Post `
        -ContentType "application/json" `
        -Headers @{ Accept = "text/plain" } `
        -Body $body

    $token = ([string]$token).Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Xray Cloud authentication returned an empty token."
    }

    return $token
}

function ConvertTo-XrayQueryString {
    param([hashtable]$Parameters)

    $pairs = foreach ($entry in $Parameters.GetEnumerator() | Sort-Object Key) {
        if (-not [string]::IsNullOrWhiteSpace([string]$entry.Value)) {
            $key = [System.Uri]::EscapeDataString([string]$entry.Key)
            $value = [System.Uri]::EscapeDataString([string]$entry.Value)
            "$key=$value"
        }
    }

    return $pairs -join "&"
}
