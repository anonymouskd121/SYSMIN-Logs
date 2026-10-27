# 🖥️ SYSMIN Logs
> **Easy Server Logs.** — Instant, plain-English Windows Server event log translation, fleet telemetry, and space-saving incremental reporting for system administrators and DevOps engineers.

---

## 🌟 Overview

**SYSMIN Logs** is a lightweight, Completely Offline zero-dependency web dashboard paired with a native PowerShell HTTP collector agent. It is designed to bridge the gap between cryptic Windows Event Logs and instant operational clarity. 

Whether you are investigating unexpected reboots, brute-force login attempts, low RAM conditions, or service crashes, SYSMIN translates Windows Event IDs (1–65535) and Hex error codes into clear **Plain-English** explanations accompanied by **1-click Google remediation searches** and **ready-to-run PowerShell fix commands**.

---

## ✨ Key Features

* **🗣️ Plain-English Translation Engine**: Instantly translates raw Windows Event Viewer XML and Event IDs into three human-friendly sections: *What Actually Happened*, *Why Does This Matter?*, and *Recommended Admin Action*.
* **🌐 Multi-Server Fleet Monitoring**: Monitor multiple Windows Server nodes simultaneously from a single pane of glass, complete with live online/offline status detection.
* **⚡ Live Auto-Sync Polling**: Configure background polling intervals (15s, 30s, 60s) with live countdown timers to keep your logs updated automatically.
* **🌙 Dark & Light Theme Mode**: Switch seamlessly between high-contrast Dark Mode for night ops and clean Light Mode for day viewing.
* **📊 Visual Executive Analytics**: Built-in severity doughnut charts, top event frequency charts, and real-time KPI counters.
* **💾 Incremental Space-Saving Reporting**: Generates audit reports containing **only new, unreported logs**. Already reported events are skipped automatically to prevent file duplication and save disk space.
* **📄 Multi-Format Report Export**: Export incident reports instantly as landscape **PDF Executive Summaries**, standalone interactive **HTML Dashboards**, or structured **CSV Spreadsheets**.
* **🔒 Error-Proof PowerShell Agent**: Lightweight HTTP listener script featuring automatic `Get-EventLog` fallbacks and try/catch protection against `UnauthorizedAccessException`.

---

## 🚀 Quick Start Guide

### Step 1: Launch the Web Portal
1. Download or clone this repository.
2. Open **`SYSMIN-Logs.html`** in any modern web browser (Chrome, Edge, Firefox, Safari).

### Step 2: Start the PowerShell Server Agent
1. Open **PowerShell as Administrator** on your Windows Server.
2. Click the **Agent Script** button in the top navigation bar of the SYSMIN dashboard and copy the PowerShell script.
3. Paste and run the script in your Administrator PowerShell window:
   ```powershell
   # SYSMIN Logs - Windows Server HTTP Agent
   $Port = 8080$Listener = New-Object System.Net.HttpListener
   $Listener.Prefixes.Add("http://localhost:$Port/")
   $Listener.Start()
   Write-Host "SYSMIN Agent Active on $env:COMPUTERNAME ($Port)" -ForegroundColor Green
   # ... (full script available inside the web portal modal)
