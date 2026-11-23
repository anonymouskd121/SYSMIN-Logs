# SYSMIN Logs - Fast Reverse-Reader Windows Server HTTP Agent (v4.8.1)
$Port = 8080
$BindAll = $false # $true = accept remote connections (needs admin + firewall rule). WARNING: HTTP is cleartext — use over localhost, Tailscale/WireGuard, or behind a TLS reverse proxy.
$ApiKey = "" # Set a fixed secret for persistent servers, or leave blank to auto-generate a random key on each start (sent via header X-Sysmin-Key)

try { Import-Module Microsoft.PowerShell.Diagnostics -ErrorAction SilentlyContinue } catch {}

function Test-Key($a, $b) {
    if (-not $a) { return $false }
    $x = [Text.Encoding]::UTF8.GetBytes([string]$a)
    $y = [Text.Encoding]::UTF8.GetBytes([string]$b)
    $d = $x.Length -bxor $y.Length
    for ($i = 0; $i -lt $y.Length; $i++) {
        $c = if ($i -lt $x.Length) { $x[$i] } else { 0 }
        $d = $d -bor ($c -bxor $y[$i])
    }
    return ($d -eq 0)
}

if (-not $ApiKey) {
    $rb = New-Object byte[] 18
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($rb)
    $ApiKey = [Convert]::ToBase64String($rb) -replace '[+/=]', 'x'
}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$ServerHostname = $env:COMPUTERNAME
$ServerIP = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notlike '169.*' } | Select-Object -First 1).IPAddress
if (-not $ServerIP) { $ServerIP = "127.0.0.1" }

$Listener = New-Object System.Net.HttpListener
if ($IsAdmin -and $BindAll) {
    $Listener.Prefixes.Add("http://+:$Port/")
} else {
    $Listener.Prefixes.Add("http://localhost:$Port/")
    $Listener.Prefixes.Add("http://127.0.0.1:$Port/")
}

try {
    $Listener.Start()
} catch {
    $Listener = New-Object System.Net.HttpListener
    $Listener.Prefixes.Add("http://localhost:$Port/")
    $Listener.Start()
}

Write-Host "=====================================================" -ForegroundColor DarkCyan
Write-Host "SYSMIN Agent Active on $ServerHostname (${ServerIP}:$Port)" -ForegroundColor Green
Write-Host "Endpoint : http://localhost:$Port/api/logs" -ForegroundColor Cyan
Write-Host "API Key  : $ApiKey  (paste into the Key field in SYSMIN)" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor DarkCyan

$Channels = @(
  'Security',
  'System',
  'Application',
  'Microsoft-Windows-PowerShell/Operational',
  'Microsoft-Windows-Windows Defender/Operational',
  'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational',
  'Microsoft-Windows-TaskScheduler/Operational',
  'Microsoft-Windows-GroupPolicy/Operational',
  'DNS Server',
  'Microsoft-Windows-DNS-Client/Operational',
  'Microsoft-Windows-Windows Firewall With Advanced Security/Firewall'
)

while ($Listener.IsListening) {
    $Response = $null
    try {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response

        $Response.Headers.Add("Access-Control-Allow-Origin", "*")
        $Response.Headers.Add("Access-Control-Allow-Methods", "GET, OPTIONS")
        $Response.Headers.Add("Access-Control-Allow-Headers", "X-Sysmin-Key, Content-Type, Accept")
        $Response.Headers.Add("Access-Control-Allow-Private-Network", "true")

        if ($Request.HttpMethod -eq "OPTIONS") {
            $Response.StatusCode = 200
            continue
        }

        if ($Request.Url.AbsolutePath -eq "/api/logs") {
            $ClientKey = $Request.Headers["X-Sysmin-Key"]
            if ($ApiKey -and (-not (Test-Key $ClientKey $ApiKey))) {
                $Response.StatusCode = 401
                $ErrBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Unauthorized - Missing or invalid X-Sysmin-Key"}')
                $Response.ContentType = "application/json; charset=utf-8"
                $Response.ContentLength64 = $ErrBytes.Length
                $Response.OutputStream.Write($ErrBytes, 0, $ErrBytes.Length)
                continue
            }

            $Sw = [System.Diagnostics.Stopwatch]::StartNew()
            # Capture UTC timestamp BEFORE reading so mid-poll events are never skipped
            $SyncStarted = (Get-Date).ToUniversalTime().ToString("o")

            $SinceParam = $Request.QueryString["since"]
            $CutoffUtc = $null
            if ($SinceParam) {
                try {
                    # 2-second safety overlap; frontend deduplicates by UID
                    $CutoffUtc = [DateTimeOffset]::Parse($SinceParam).UtcDateTime.AddSeconds(-2)
                } catch {}
            }

            $LimitPerChannel = if ($CutoffUtc) { 150 } else { 25 }
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Sync request received$(if ($CutoffUtc) { " (incremental)" } else { " (initial)" })..." -ForegroundColor Yellow
            $AllEvents = New-Object System.Collections.Generic.List[object]

            foreach ($Ch in $Channels) {
                $Reader = $null
                try {
                    $Query = New-Object System.Diagnostics.Eventing.Reader.EventLogQuery($Ch, [System.Diagnostics.Eventing.Reader.PathType]::LogName)
                    $Query.ReverseDirection = $true
                    $Reader = New-Object System.Diagnostics.Eventing.Reader.EventLogReader($Query)

                    $Count = 0
                    while ($Count -lt $LimitPerChannel) {
                        $Ev = $Reader.ReadEvent()
                        if ($null -eq $Ev) { break }
                        try {
                            # Stop scanning this channel immediately once we pass the last sync time
                            if ($CutoffUtc -and $Ev.TimeCreated) {
                                if ($Ev.TimeCreated.ToUniversalTime() -lt $CutoffUtc) {
                                    break
                                }
                            }

                            $TimeIso = if ($Ev.TimeCreated) { $Ev.TimeCreated.ToString("yyyy-MM-ddTHH:mm:ss.fffzzz") } else { (Get-Date).ToString("o") }
                            $TimeDisp = if ($Ev.TimeCreated) { $Ev.TimeCreated.ToString("dd MMM yyyy, hh:mm:ss tt") } else { (Get-Date).ToString("dd MMM yyyy, hh:mm:ss tt") }
                            $MsgText = try { $Ev.FormatDescription() } catch { $null }
                            $LevelDisp = try { $Ev.LevelDisplayName } catch { $null }
                            if (-not $LevelDisp) {
                                $LevelDisp = switch ($Ev.Level) {
                                    1 { "Critical" }
                                    2 { "Error" }
                                    3 { "Warning" }
                                    default { "Information" }
                                }
                            }

                            $XmlMap = @{}
                            try {
                                $XmlDoc = [xml]$Ev.ToXml()
                                $DataNodes = $XmlDoc.Event.EventData.Data
                                if ($DataNodes) {
                                    $idx = 0
                                    foreach ($DataNode in $DataNodes) {
                                        $key = if ($DataNode.Name) { $DataNode.Name } else { "Param$idx" }
                                        $val = if ($DataNode.'#text') { $DataNode.'#text' } else { [string]$DataNode }
                                        if ($val) { $XmlMap[$key] = $val }
                                        $idx++
                                    }
                                }
                            } catch {}

                            if (-not $MsgText) {
                                $Pairs = ($XmlMap.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join " | "
                                $MsgText = if ($Pairs) { "Event ID $($Ev.Id) - $Pairs" } else { "Event ID $($Ev.Id) logged by $($Ev.ProviderName) in $($Ev.LogName)." }
                            }

                            $AllEvents.Add([PSCustomObject]@{
                                Id               = $Ev.Id
                                RecordId         = $Ev.RecordId
                                LogName          = $Ev.LogName
                                ProviderName     = $Ev.ProviderName
                                LevelDisplayName = $LevelDisp
                                Level            = $Ev.Level
                                TimeCreated      = $TimeIso
                                TimeDisplay      = $TimeDisp
                                MachineName      = $ServerHostname
                                ServerIP         = $ServerIP
                                Message          = $MsgText
                                EventData        = $XmlMap
                            })
                            $Count++
                        } finally {
                            $Ev.Dispose()
                        }
                    }
                } catch {
                    # Channel does not exist on this host or lacks read permission — skip silently
                } finally {
                    if ($Reader) { $Reader.Dispose() }
                }
            }

            $Sw.Stop()
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Sent $($AllEvents.Count) detailed logs in $($Sw.ElapsedMilliseconds)ms." -ForegroundColor Green

            $Payload = @{
                status    = "connected"
                hostname  = $ServerHostname
                ip        = $ServerIP
                isAdmin   = $IsAdmin
                timestamp = $SyncStarted
                logs      = $AllEvents
            } | ConvertTo-Json -Depth 5 -Compress

            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($Payload)
            $Response.ContentType = "application/json; charset=utf-8"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        } else {
            $Response.StatusCode = 404
        }
    } catch [System.Net.HttpListenerException] {
        Write-Warning "[$(Get-Date -Format 'HH:mm:ss')] Client disconnected or listener error: $($_.Exception.Message)"
        if (-not $Listener.IsListening) { break }
    } catch {
        Write-Warning "[$(Get-Date -Format 'HH:mm:ss')] Request handling error: $($_.Exception.Message)"
    } finally {
        if ($Response) {
            try { $Response.Close() } catch {}
        }
    }
}