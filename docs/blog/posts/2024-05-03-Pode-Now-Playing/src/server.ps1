param(
    # Listen on all IPv4 interfaces by default
    [Parameter()]
    [string]
    $Address = '0.0.0.0',

    # Listen on port 8088 by default
    [Parameter()]
    [ValidateRange(0, 65535)]
    [int]
    $Port = 80
)

Start-PodeServer {
    Add-PodeEndpoint -Address $Address -Port $Port -Protocol Http # (1)!

    # Log requests to the terminal/stdout
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    $messagesRouteParams = @{
        Method      = 'Get'
        Path        = '/music/recenttracks'
        ContentType = 'application/json'
    }
    Add-PodeRoute @messagesRouteParams -ScriptBlock {
        # (2)!
        $cachedTracks = Get-PodeState -Name 'recenttracks'
        $uri = "https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=$($env:LASTFM_USER)&api_key=$($env:LASTFM_API_KEY)&format=json"
        if ($null -eq $cachedTracks -or $cachedTracks.TimeStamp -lt (Get-Date).AddMinutes(-1)) {
            Set-PodeState -Name recenttracks -Value (
                [pscustomobject]@{
                    TimeStamp = Get-Date
                    Tracks    = (Invoke-RestMethod -Method Get -Uri $uri -ErrorAction Stop).recenttracks.track
                })
        }

        # (3)!
        $limit = 50
        if ($WebEvent.Query['limit']) {
            $limit = [math]::Min($limit, [math]::Abs([int]$WebEvent.Query['limit']))
        }

        # (4)!
        $response = @{
            StatusCode = 200
            Value      = (Get-PodeState -Name 'recenttracks').Tracks | Select-Object -First $limit
        }
        Write-PodeJsonResponse @response
    }
}