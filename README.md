# SYSMIN Logs — Easy Server Logs

![Version](https://img.shields.io/badge/version-4.8-blue?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows%20Server%20%7C%20Windows%2010%2F11-0078D6?style=flat-square)
![Architecture](https://img.shields.io/badge/architecture-Single--File%20HTML%20%2B%20PowerShell-emerald?style=flat-square)
![Dependencies](https://img.shields.io/badge/server%20install-Zero%20Install-indigo?style=flat-square)

**SYSMIN Logs** is a lightweight, zero-install Windows Server Event Log viewer, decoder, and multi-server fleet dashboard built into a single HTML file paired with a fast PowerShell listener agent.

Instead of digging through raw XML in Windows Event Viewer, SYSMIN automatically extracts **Usernames**, **Client Hostnames**, **Source IPs**, **Logon Types**, **Services**, **Hex Error Codes**, and **MITRE ATT&CK** mappings—turning noisy server logs into actionable plain-English diagnostics and one-click PowerShell remediation commands.

---

## Key Features

* **Fast Reverse-Reader Agent:** Uses .NET `EventLogReader` (`ReverseDirection = $true`) to read newest events first and stop immediately at the last sync timestamp—completing incremental syncs in milliseconds instead of scanning entire `.evtx` files.
* **Deep XML Entity Extraction:** Automatically parses `TargetUserName`, `WorkstationName`, `IpAddress`, `LogonType`, `ServiceName`, and `ProcessName` into clickable pills for instant cross-filtering.
* **Built-In Brute-Force Detection:** Single failed logons (`4625` / `4771`) log as `WARNING` to prevent alert fatigue, and automatically escalate to `CRITICAL` when **5+ failures occur within 5 minutes** from the same source.
* **Multi-Server Fleet Polling:** Monitor one or multiple Windows Servers simultaneously with configurable Auto-Sync (`15s`, `30s`, `60s`), per-node enable/disable toggles, and inline API key management.
* **MITRE ATT&CK & Hex Error Decoding:** Tags security events with MITRE techniques (`T1110`, `T1078`, `T1059.001`, `T1543.003`, etc.) and translates Windows status codes (`0xc000006a`, `0x80070005`, `0xc0000234`, etc.).
* **Incremental Deduplicated Reports:** Export only *new* unreported events as **PDF**, **Standalone Interactive HTML**, **CSV** (with Excel formula-injection protection), or **Structured JSON**.
* **Triage Workflow & Alerts:** Mark events as `Starred`, `Investigating`, or `Resolved`, get optional audible chimes on `CRITICAL` alerts, and switch between Dark and Light mode.
* **Offline Decoder & Importer:** Paste raw Event Viewer XML, type an Event ID manually, or import saved `.json` / `.csv` files (including SYSMIN's own exports).

---

## Quick Start (Local Server)

No web server, database, or agent installer is required.

### 1. Download the Portal
Clone the repository or download the HTML file directly:

```bash
git clone [https://github.com/anonymouskd121/SYSMIN-Logs.git](https://github.com/anonymouskd121/SYSMIN-Logs.git)
```

Open the SYSMIN HTML file in any modern browser (Chrome, Edge, Firefox, or Brave).

### 2. Start the PowerShell Agent
1. Click **Agent Script** in the top toolbar of SYSMIN Logs.
2. Click **Copy PowerShell Script**.
3. Open **PowerShell as Administrator** on your Windows Server (required to read the `Security` event log) and save/run the script (e.g., `sysmin-agent.ps1`):

```powershell
powershell -ExecutionPolicy Bypass -File .\sysmin-agent.ps1
```

4. The console will print a startup banner containing an auto-generated **API Key**:

```text
=====================================================
SYSMIN Agent Active on SRV-DC-01 (192.168.1.50:8080)
Endpoint : http://localhost:8080/api/logs
API Key  : k8xP3mQ9vL2nR7tW4yB6cF1h  (paste into the Key field in SYSMIN)
=====================================================
```

> **Non-Admin Option:** If you want to run the agent under a standard account instead of Administrator, grant it read access to event logs once (then sign out and back in):
> ```powershell
> net localgroup "Event Log Readers" "$env:USERNAME" /add
> ```

### 3. Connect & Sync
1. In the SYSMIN header, click **Servers (1)**.
2. Click **Set Key** next to `Local Server`, paste the API Key from your PowerShell window, and press **Enter** (or click **Save**).
3. Click **Sync All Nodes** (or **Sync Fleet** in the main toolbar).

Your fleet status pill will turn **CONNECTED**, and events will populate immediately.

---

## Multi-Server / Remote Fleet Setup

By default, the PowerShell agent binds **only to `localhost` and `127.0.0.1`** for security. To monitor remote Windows Servers from a central admin workstation:

### On Each Remote Windows Server
1. Open `sysmin-agent.ps1` and set `$BindAll = $true` plus a **fixed** `$ApiKey` (so the key does not rotate when the server reboots):

```powershell
$Port = 8080
$BindAll = $true
$ApiKey = "replace-with-a-long-random-secret-key"
```

2. Allow port `8080` through Windows Firewall—**restricted to your admin workstation's IP**:

```powershell
New-NetFirewallRule -DisplayName "SYSMIN Logs Agent" `
  -Direction Inbound -Protocol TCP -LocalPort 8080 `
  -RemoteAddress 192.168.1.100 -Action Allow
```
*(Replace `192.168.1.100` with your management machine's IP or VPN subnet.)*

3. Run the script as Administrator (or register it as a Scheduled Task at startup).

### In the SYSMIN Dashboard
1. Click **Servers** in the top bar.
2. Enter:
   * **Label:** e.g. `DC-01` or `SQL-PROD`
   * **URL:** `http://192.168.1.50:8080`
   * **API Key:** the `$ApiKey` configured on that server
3. Click **Add Node**, then **Sync All Nodes**.
4. Optionally enable **Auto-Sync** (`15s`, `30s`, or `60s`) for live monitoring.

> **Security Warning for Remote Connections:** The built-in `HttpListener` serves plain `HTTP`. When `$BindAll =$true`, your `X-Sysmin-Key` header and Event ID `4104` PowerShell script blocks traverse the network unencrypted. For production LANs, run remote polling over **Tailscale / WireGuard / VPN**, or place the agent behind a **TLS reverse proxy** (IIS, Caddy, or Nginx).

---

## Complete Usage Guide

### 1. Filtering & Cross-Filtering
* **Category Pills:** Filter the fleet by `Auth, Logon & Logoff`, `Disk & Kernel`, `Services & GPO`, `Network & DNS`, `IIS, .NET & SQL`, or `Defender & PS`.
* **Click-to-Filter Entity Pills:** Click any `👤 User`, `💻 Client Host`, `🌐 Source IP`, or `⚙️ Service/Process` badge on an event card to instantly filter the entire feed by that entity.
* **Combined Filters:** Narrow results by **Server**, **Severity**, **Channel**, **Time Range** (`1H`, `24H`, `7D`), **Export State**, or **Triage State**.
* **KPI Scope Toggle:** Switch the top KPI cards and charts between **Fleet Total** (all loaded logs) and **Filtered View** (only currently matching logs).
* **Keyboard Navigation:** Use `Tab` + `Enter` / `Space` to move through and inspect events, and `Esc` to close any modal.

### 2. Diagnostic Inspector & Triage
Click any event in the feed to open it in the right-hand **Diagnostic Inspector**:
* **Telemetry Grid:** Displays extracted Account/User, Client Workstation, Source IP, and Logon Type / Target Service.
* **Triage Bar:** Tag incidents as `Unreviewed`, `Starred`, `Investigating`, or `Resolved` (saved locally in your browser).
* **Plain-English Breakdown:** Summarizes *What Happened*, *Operational Impact*, and *Remediation Steps*.
* **PowerShell Verification:** Copy a tailored `Get-WinEvent` / `Get-Service` / `Get-MpThreat` verification command in one click.
* **Remediation Lookup:** Opens a targeted Google troubleshooting query including the Event ID, Provider, and detected Hex Error Code.

### 3. Incremental Reporting & Exports
SYSMIN tracks every exported event UID in browser storage so repeat exports never duplicate old logs and shows how much storage deduplication saved.

Click **Export Report** and choose a format:

| Format | Best For | Notes |
|---|---|---|
| **PDF Document** | Management & audit handoffs | Capped at 100 events per export for browser speed; remaining unreported events stay queued for the next export. |
| **Dynamic HTML** | Sharing with teammates | Self-contained dark-mode report with built-in live search and severity filter. |
| **CSV Spreadsheet** | Excel / ticketing / audits | Escapes formula-injection prefixes (`=`, `+`, `-`, `@`, `\t`) automatically. |
| **Structured JSON** | SIEM ingestion & backups | Full event objects; can be re-imported back into SYSMIN at any time. |

Click **Reset** on the *Deduped Storage Saved* KPI card if you want to clear export history and re-export everything.

### 4. Manual Event & Raw XML Decoder
Need to decode an event from an offline server?
1. Click **Decode Log** in the toolbar.
2. Either type an **Event ID** (e.g., `4625`, `7045`, `4104`) or paste raw **Event Viewer XML** (`<Event xmlns=...>...</Event>`) directly into the text box.
3. Click **Decode & Add**. SYSMIN parses the XML via native `DOMParser`, extracts all entities, caches the event, and opens it in the Inspector.

### 5. Importing Saved Logs
Click **Import** and select a `.json` or `.csv` file. SYSMIN supports:
* Previously exported SYSMIN `.json` and `.csv` reports.
* Raw PowerShell `Get-WinEvent | ConvertTo-Json` exports.
* Standard Windows Event Viewer `.csv` exports.

---

## Monitored Windows Event Channels

The PowerShell agent automatically queries these 11 channels (skipping any channel not installed on the target host, such as `DNS Server` on non-DC machines):

1. `Security`
2. `System`
3. `Application`
4. `Microsoft-Windows-PowerShell/Operational`
5. `Microsoft-Windows-Windows Defender/Operational`
6. `Microsoft-Windows-TerminalServices-LocalSessionManager/Operational`
7. `Microsoft-Windows-TaskScheduler/Operational`
8. `Microsoft-Windows-GroupPolicy/Operational`
9. `DNS Server`
10. `Microsoft-Windows-DNS-Client/Operational`
11. `Microsoft-Windows-Windows Firewall With Advanced Security/Firewall`

---

## Security Architecture

* **Mandatory Key Auth:** When `$ApiKey` is left blank, the agent generates a cryptographically random 18-byte key on startup and validates `X-Sysmin-Key` in constant time (`Test-Key`) to prevent timing attacks.
* **Localhost by Default:** `$BindAll` defaults to `$false`, preventing unintended LAN exposure.
* **Browser-Side Storage:** Server lists, API keys, triage statuses, and up to 500 cached events are stored locally in your browser's `localStorage`—no external backend ever receives your server logs.
* **XSS & CSV Formula Hardening:** All event fields are HTML-escaped before rendering, and CSV cells starting with spreadsheet formula triggers are neutralized.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| **`401 Unauthorized` toast on sync** | Missing or rotated `X-Sysmin-Key` | Click **Servers → Set Key / Edit Key**, paste the key shown in the PowerShell console, and save. |
| **Security channel events missing** | PowerShell not running elevated | Run PowerShell as **Administrator** or add the user to the `Event Log Readers` local group. |
| **Remote server shows `OFFLINE`** | `$BindAll` is `$false` or Firewall blocks port `8080` | Set `$BindAll =$true`, run PowerShell as Administrator, and add an inbound Windows Firewall rule for port `8080`. |
| **Browser blocks `http://` from `https://`** | Mixed-content restriction | Open the SYSMIN HTML file locally (`file://`) or serve both dashboard and agent over HTTPS. |
| **0 events returned after clicking Clear Feed** | Sync cursor was active | Clicking **Clear Feed** resets per-server sync cursors automatically—click **Sync Fleet** again to pull the latest 25 events per channel. |
