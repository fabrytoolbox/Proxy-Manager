# Frank-Moses-Proxy-Manager.ps1 - v1.0 (Matrix Edition)
# Codename: "Frank Moses" (RED)
# Gestore Proxy di Sistema con GUI Matrix e Profili.
# Richiede PowerShell 7.2+

#Requires -Version 7.2

# ============================================================
# AUTO-ELEVAZIONE ADMIN
# ============================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $pwshPath = Join-Path $PSHOME "pwsh.exe"
    if (-not (Test-Path $pwshPath)) { $pwshPath = "pwsh.exe" }
    Start-Process $pwshPath -ArgumentList "-NoProfile -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$script:logFile = $null
$script:proxiesFilePath = Join-Path $scriptPath "proxies.xml"
$script:proxiesData = $null

# ============================================================
# LOGGING
# ============================================================
function Start-Log {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:logFile = Join-Path $scriptPath "frank_moses_proxy_$timestamp.log"
    @(
        "============================================================",
        " FRANK MOSES PROXY MANAGER v1.0 - LOG",
        "============================================================",
        "Data inizio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "PowerShell : $($PSVersionTable.PSVersion)",
        "============================================================",
        ""
    ) | Set-Content -Path $script:logFile -Encoding UTF8
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (-not $script:logFile) { return }
    $line = "[$(Get-Date -Format 'HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $script:logFile -Value $line -Encoding UTF8
}

Start-Log

# ============================================================
# GESTIONE FILE PROXIES.XML
# ============================================================
function Load-ProxiesXml {
    if (Test-Path $script:proxiesFilePath) {
        try {
            $raw = Get-Content -Path $script:proxiesFilePath -Raw -Encoding UTF8
            $clean = $raw.TrimStart([char]0xFEFF, [char]0x200B, [char]0x0000, " ", "`r", "`n")
            $script:proxiesData = [xml]$clean
            Write-Log "File proxies.xml caricato." "OK"
        } catch {
            Write-Log "Errore nel parsing di proxies.xml: $($_.Exception.Message)" "ERROR"
            return $false
        }
    } else {
        Write-Log "File proxies.xml non trovato. Creazione di un file di default." "WARN"
        $defaultXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Proxies>
    <Proxy>
        <Nome>Ufficio</Nome>
        <Server>10.0.0.50</Server>
        <Porta>8080</Porta>
        <BypassList>*.local;192.168.*;10.*;&lt;local&gt;</BypassList>
    </Proxy>
    <Proxy>
        <Nome>Casa</Nome>
        <Server>192.168.1.1</Server>
        <Porta>3128</Porta>
        <BypassList>localhost;127.0.0.1</BypassList>
    </Proxy>
</Proxies>
"@
        try {
            $defaultXml | Set-Content -Path $script:proxiesFilePath -Encoding UTF8
            $script:proxiesData = [xml]$defaultXml
            Write-Log "Creato proxies.xml con profili di default." "OK"
        } catch {
            Write-Log "Impossibile creare proxies.xml: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }
    return $true
}

if (-not (Load-ProxiesXml)) {
    [System.Windows.Forms.MessageBox]::Show("Impossibile caricare o creare il file proxies.xml.`nControlla i permessi della cartella.", "MATRIX - ERRORE", "OK", "Error") | Out-Null
    exit
}

# ============================================================
# INTERFACCIA GRAFICA - MATRIX EDITION
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text            = "FRANK MOSES PROXY MANAGER v1.0"
$form.Size            = New-Object System.Drawing.Size(820, 680)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = [System.Drawing.Color]::Black
$form.ForeColor       = [System.Drawing.Color]::Lime
$form.Font            = New-Object System.Drawing.Font("Consolas", 10)

# --- HEADER ---
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "FRANK MOSES PROXY MANAGER v1.0"
$lblTitle.ForeColor = [System.Drawing.Color]::Lime
$lblTitle.Font      = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location  = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size      = New-Object System.Drawing.Size(760, 30)
$form.Controls.Add($lblTitle)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Text      = ":: GESTIONE PROXY E PROFILI : MATRIX EDITION ::"
$lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 180, 0)
$lblSubtitle.Font      = New-Object System.Drawing.Font("Consolas", 9)
$lblSubtitle.Location  = New-Object System.Drawing.Point(20, 50)
$lblSubtitle.Size      = New-Object System.Drawing.Size(760, 18)
$form.Controls.Add($lblSubtitle)

# --- SEZIONE PROFILI ---
$lblProfili = New-Object System.Windows.Forms.Label
$lblProfili.Text = "Profilo:"; $lblProfili.Location = New-Object System.Drawing.Point(20, 85)
$lblProfili.Size = New-Object System.Drawing.Size(80, 20); $form.Controls.Add($lblProfili)

$global:cmbProfili = New-Object System.Windows.Forms.ComboBox
$global:cmbProfili.Location = New-Object System.Drawing.Point(100, 82); $global:cmbProfili.Size = New-Object System.Drawing.Size(300, 26)
$global:cmbProfili.BackColor = [System.Drawing.Color]::Black; $global:cmbProfili.ForeColor = [System.Drawing.Color]::Lime
$global:cmbProfili.DropDownStyle = "DropDownList"
$form.Controls.Add($global:cmbProfili)

$global:btnLoadProfile = New-Object System.Windows.Forms.Button
$global:btnLoadProfile.Text = "CARICA"; $global:btnLoadProfile.Location = New-Object System.Drawing.Point(410, 80)
$global:btnLoadProfile.Size = New-Object System.Drawing.Size(100, 30); $global:btnLoadProfile.FlatStyle = "Flat"
$global:btnLoadProfile.ForeColor = [System.Drawing.Color]::Lime; $global:btnLoadProfile.FlatAppearance.BorderColor = [System.Drawing.Color]::Lime
$form.Controls.Add($global:btnLoadProfile)

$global:btnSaveProfile = New-Object System.Windows.Forms.Button
$global:btnSaveProfile.Text = "SALVA COME..."; $global:btnSaveProfile.Location = New-Object System.Drawing.Point(520, 80)
$global:btnSaveProfile.Size = New-Object System.Drawing.Size(120, 30); $global:btnSaveProfile.FlatStyle = "Flat"
$global:btnSaveProfile.ForeColor = [System.Drawing.Color]::Cyan; $global:btnSaveProfile.FlatAppearance.BorderColor = [System.Drawing.Color]::Cyan
$form.Controls.Add($global:btnSaveProfile)

# --- SEZIONE CONFIGURAZIONE ---
$gbConfig = New-Object System.Windows.Forms.GroupBox
$gbConfig.Text = "[ CONFIGURAZIONE PROXY ]"; $gbConfig.ForeColor = [System.Drawing.Color]::Lime
$gbConfig.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$gbConfig.Location = New-Object System.Drawing.Point(20, 125); $gbConfig.Size = New-Object System.Drawing.Size(760, 160)
$form.Controls.Add($gbConfig)

# Indirizzo e Porta
$lblServer = New-Object System.Windows.Forms.Label; $lblServer.Text = "Server:"; $lblServer.Location = New-Object System.Drawing.Point(20, 30); $lblServer.Size = New-Object System.Drawing.Size(80, 20); $gbConfig.Controls.Add($lblServer)
$global:txtServer = New-Object System.Windows.Forms.TextBox; $global:txtServer.Location = New-Object System.Drawing.Point(100, 28); $global:txtServer.Size = New-Object System.Drawing.Size(200, 26)
$global:txtServer.BackColor = [System.Drawing.Color]::Black; $global:txtServer.ForeColor = [System.Drawing.Color]::Lime; $gbConfig.Controls.Add($global:txtServer)

$lblPorta = New-Object System.Windows.Forms.Label; $lblPorta.Text = "Porta:"; $lblPorta.Location = New-Object System.Drawing.Point(320, 30); $lblPorta.Size = New-Object System.Drawing.Size(60, 20); $gbConfig.Controls.Add($lblPorta)
$global:txtPorta = New-Object System.Windows.Forms.TextBox; $global:txtPorta.Location = New-Object System.Drawing.Point(380, 28); $global:txtPorta.Size = New-Object System.Drawing.Size(80, 26)
$global:txtPorta.BackColor = [System.Drawing.Color]::Black; $global:txtPorta.ForeColor = [System.Drawing.Color]::Lime; $gbConfig.Controls.Add($global:txtPorta)

$global:chkEnable = New-Object System.Windows.Forms.CheckBox; $global:chkEnable.Text = "Abilita Proxy"; $global:chkEnable.Location = New-Object System.Drawing.Point(500, 28)
$global:chkEnable.Size = New-Object System.Drawing.Size(150, 24); $global:chkEnable.ForeColor = [System.Drawing.Color]::Lime; $global:chkEnable.BackColor = [System.Drawing.Color]::Black
$gbConfig.Controls.Add($global:chkEnable)

# Bypass List
$lblBypass = New-Object System.Windows.Forms.Label; $lblBypass.Text = "Bypass List:"; $lblBypass.Location = New-Object System.Drawing.Point(20, 70); $lblBypass.Size = New-Object System.Drawing.Size(100, 20); $gbConfig.Controls.Add($lblBypass)
$global:txtBypass = New-Object System.Windows.Forms.TextBox; $global:txtBypass.Location = New-Object System.Drawing.Point(120, 68); $global:txtBypass.Size = New-Object System.Drawing.Size(620, 26)
$global:txtBypass.BackColor = [System.Drawing.Color]::Black; $global:txtBypass.ForeColor = [System.Drawing.Color]::Lime; $gbConfig.Controls.Add($global:txtBypass)

$lblHint = New-Object System.Windows.Forms.Label; $lblHint.Text = "Separati da ; (es. *.local;192.168.*;<local>)"; $lblHint.Location = New-Object System.Drawing.Point(120, 100); $lblHint.Size = New-Object System.Drawing.Size(500, 20)
$lblHint.ForeColor = [System.Drawing.Color]::Gray; $lblHint.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Italic); $gbConfig.Controls.Add($lblHint)

# --- PULSANTI AZIONE ---
$global:btnApply = New-Object System.Windows.Forms.Button
$global:btnApply.Text = "▶  APPLICA PROXY"
$global:btnApply.Location = New-Object System.Drawing.Point(20, 300)
$global:btnApply.Size = New-Object System.Drawing.Size(370, 45)
$global:btnApply.FlatStyle = "Flat"; $global:btnApply.BackColor = [System.Drawing.Color]::Black
$global:btnApply.ForeColor = [System.Drawing.Color]::Lime; $global:btnApply.FlatAppearance.BorderColor = [System.Drawing.Color]::Lime
$global:btnApply.FlatAppearance.BorderSize = 2; $global:btnApply.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($global:btnApply)

$global:btnDisable = New-Object System.Windows.Forms.Button
$global:btnDisable.Text = "DISATTIVA PROXY"
$global:btnDisable.Location = New-Object System.Drawing.Point(410, 300)
$global:btnDisable.Size = New-Object System.Drawing.Size(370, 45)
$global:btnDisable.FlatStyle = "Flat"; $global:btnDisable.BackColor = [System.Drawing.Color]::Black
$global:btnDisable.ForeColor = [System.Drawing.Color]::Red; $global:btnDisable.FlatAppearance.BorderColor = [System.Drawing.Color]::Red
$global:btnDisable.FlatAppearance.BorderSize = 2; $global:btnDisable.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($global:btnDisable)

$global:btnRead = New-Object System.Windows.Forms.Button
$global:btnRead.Text = "LEGGI CONFIGURAZIONE ATTUALE"
$global:btnRead.Location = New-Object System.Drawing.Point(20, 355)
$global:btnRead.Size = New-Object System.Drawing.Size(760, 35)
$global:btnRead.FlatStyle = "Flat"; $global:btnRead.BackColor = [System.Drawing.Color]::Black
$global:btnRead.ForeColor = [System.Drawing.Color]::Cyan; $global:btnRead.FlatAppearance.BorderColor = [System.Drawing.Color]::Cyan
$form.Controls.Add($global:btnRead)

# --- LOG ---
$global:txtLog = New-Object System.Windows.Forms.TextBox
$global:txtLog.Multiline = $true; $global:txtLog.ScrollBars = "Vertical"; $global:txtLog.ReadOnly = $true
$global:txtLog.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 10); $global:txtLog.ForeColor = [System.Drawing.Color]::Lime
$global:txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$global:txtLog.Location = New-Object System.Drawing.Point(20, 400); $global:txtLog.Size = New-Object System.Drawing.Size(760, 200)
$global:txtLog.BorderStyle = "FixedSingle"
$form.Controls.Add($global:txtLog)

function Write-ScreenLog {
    param([string]$Message, [string]$Color = "Lime")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $global:txtLog.AppendText("[$timestamp] $Message`r`n")
    $global:txtLog.SelectionStart = $global:txtLog.Text.Length
    $global:txtLog.ScrollToCaret()
    Write-Log $Message "INFO"
}

# --- STATUS BAR E EXIT ---
$global:lblStatus = New-Object System.Windows.Forms.Label
$global:lblStatus.Text = "> Pronto."
$global:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 0)
$global:lblStatus.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
$global:lblStatus.Location = New-Object System.Drawing.Point(20, 610); $global:lblStatus.Size = New-Object System.Drawing.Size(680, 25)
$form.Controls.Add($global:lblStatus)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "EXIT"; $btnExit.Location = New-Object System.Drawing.Point(700, 605)
$btnExit.Size = New-Object System.Drawing.Size(80, 30); $btnExit.FlatStyle = "Flat"
$btnExit.BackColor = [System.Drawing.Color]::Black; $btnExit.ForeColor = [System.Drawing.Color]::Red
$btnExit.FlatAppearance.BorderColor = [System.Drawing.Color]::Red
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# ============================================================
# FUNZIONE PER POPOLARE LA COMBOBOX DEI PROFILI
# ============================================================
function Update-ProfileCombo {
    $global:cmbProfili.Items.Clear()
    foreach ($proxy in $script:proxiesData.Proxies.Proxy) {
        $global:cmbProfili.Items.Add($proxy.Nome) | Out-Null
    }
    if ($global:cmbProfili.Items.Count -gt 0) { $global:cmbProfili.SelectedIndex = 0 }
}
# --------------------------------------------------
#                   primo blocco
# --------------------------------------------------
# ============================================================
# FUNZIONI DI LETTURA (WinINET e WinHTTP)
# ============================================================

# Legge la configurazione WinINET (Registro di Windows)
function Get-WinInetProxy {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    try {
        $reg = Get-ItemProperty -Path $regPath -ErrorAction Stop
        return @{
            Enabled    = ($reg.ProxyEnable -eq 1)
            Server     = $reg.ProxyServer
            BypassList = $reg.ProxyOverride
        }
    } catch {
        Write-Log "Errore lettura WinINET: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Legge la configurazione WinHTTP (tramite netsh)
function Get-WinHttpProxy {
    try {
        $output = netsh winhttp show proxy 2>&1
        $outputString = $output -join "`n"
        
        if ($outputString -match 'Proxy server\(s\)\s*:\s*(.+)') {
            $server = $Matches[1].Trim()
            return @{
                Enabled = ($server -ne "Direct access (no proxy server).")
                Server  = if ($server -eq "Direct access (no proxy server).") { "" } else { $server }
            }
        }
        return @{ Enabled = $false; Server = "" }
    } catch {
        Write-Log "Errore lettura WinHTTP: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# ============================================================
# FUNZIONE PER POPOLARE LA GUI CON LA CONFIGURAZIONE ATTUALE
# ============================================================
function Update-GuiFromSystem {
    Write-ScreenLog "Lettura configurazione di sistema in corso..." "Cyan"
    
    # 1. Leggi WinINET
    $wininet = Get-WinInetProxy
    if ($wininet) {
        $global:chkEnable.Checked = $wininet.Enabled
        if ($wininet.Server) {
            # Il server può essere nel formato "192.168.1.1:8080" o "http=192.168.1.1:8080;https=..."
            # Per semplicità, gestiamo solo il formato base "host:porta"
            if ($wininet.Server -match '^(.*?):(\d+)$') {
                $global:txtServer.Text = $Matches[1]
                $global:txtPorta.Text = $Matches[2]
            } else {
                $global:txtServer.Text = $wininet.Server
                $global:txtPorta.Text = ""
            }
        } else {
            $global:txtServer.Text = ""
            $global:txtPorta.Text = ""
        }
        $global:txtBypass.Text = if ($wininet.BypassList) { $wininet.BypassList } else { "" }
        
        $statusWinInet = if ($wininet.Enabled) { "ATTIVO ($($wininet.Server))" } else { "DISATTIVO" }
        Write-ScreenLog "WinINET (Browser/App): $statusWinInet" "Lime"
    }

    # 2. Leggi WinHTTP
    $winhttp = Get-WinHttpProxy
    if ($winhttp) {
        $statusWinHttp = if ($winhttp.Enabled) { "ATTIVO ($($winhttp.Server))" } else { "DISATTIVO (Direct Access)" }
        Write-ScreenLog "WinHTTP (Servizi/Script): $statusWinHttp" "Lime"
    }
    
    $global:lblStatus.Text = "> Configurazione letta dal sistema."
}
# ----------------------------------------------------
#					secondo blocco
# ----------------------------------------------------
# ============================================================
# FUNZIONI DI SCRITTURA (WinINET e WinHTTP)
# ============================================================

# Applica la configurazione a WinINET (Registro)
function Set-WinInetProxy {
    param(
        [string]$Server,
        [string]$Porta,
        [string]$BypassList,
        [bool]$Enable
    )
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    try {
        # Imposta ProxyEnable
        Set-ItemProperty -Path $regPath -Name "ProxyEnable" -Value $(if ($Enable) { 1 } else { 0 }) -ErrorAction Stop
        
        if ($Enable) {
            # Imposta ProxyServer (host:porta)
            $proxyString = if ($Porta) { "$Server`:$Porta" } else { $Server }
            Set-ItemProperty -Path $regPath -Name "ProxyServer" -Value $proxyString -ErrorAction Stop
            
            # Imposta BypassList (ProxyOverride)
            if ($BypassList) {
                Set-ItemProperty -Path $regPath -Name "ProxyOverride" -Value $BypassList -ErrorAction Stop
            } else {
                Remove-ItemProperty -Path $regPath -Name "ProxyOverride" -ErrorAction SilentlyContinue
            }
        }
        
        Write-Log "WinINET aggiornato: Enable=$Enable, Server=$Server, Porta=$Porta" "OK"
        return $true
    } catch {
        Write-Log "Errore scrittura WinINET: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Applica la configurazione a WinHTTP (netsh)
function Set-WinHttpProxy {
    param(
        [string]$Server,
        [string]$Porta,
        [string]$BypassList,
        [bool]$Enable
    )
    try {
        if ($Enable) {
            $proxyString = if ($Porta) { "$Server`:$Porta" } else { $Server }
            
            # Costruiamo il comando senza virgolette (sintassi nativa di netsh)
            $netshArgs = "winhttp set proxy proxy-server=$proxyString"
            if ($BypassList) {
                $netshArgs += " bypass-list=$BypassList"
            }
            
            # Eseguiamo tramite cmd /c (ambiente nativo)
            $output = cmd /c "netsh $netshArgs 2>&1"
        } else {
            $output = cmd /c "netsh winhttp reset proxy 2>&1"
        }
        
        $outputString = $output -join "`n"
        
        # Controlla il successo (in italiano o inglese)
        if ($outputString -match 'Impostazioni proxy correnti|Operazione completata|The operation completed successfully|OK') {
            Write-Log "WinHTTP aggiornato: Enable=$Enable, Server=$Server" "OK"
            return $true
        } else {
            Write-Log "Errore scrittura WinHTTP: $outputString" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Eccezione durante netsh: $($_.Exception.Message)" "ERROR"
        return $false
    }
}
# ============================================================
# FUNZIONE DI APPLICAZIONE (WinINET + WinHTTP)
# ============================================================
function Apply-ProxyConfiguration {
    param(
        [string]$Server,
        [string]$Porta,
        [string]$BypassList,
        [bool]$Enable
    )

    Write-ScreenLog "Applicazione configurazione proxy in corso..." "Cyan"

    # Applica a WinINET
    $wininetResult = Set-WinInetProxy -Server $Server -Porta $Porta -BypassList $BypassList -Enable $Enable
    if ($wininetResult) {
        Write-ScreenLog "WinINET (Browser/App): aggiornato correttamente." "Lime"
    } else {
        Write-ScreenLog "WinINET: errore durante l'aggiornamento." "Red"
    }

    # Applica a WinHTTP
    $winhttpResult = Set-WinHttpProxy -Server $Server -Porta $Porta -BypassList $BypassList -Enable $Enable
    if ($winhttpResult) {
        Write-ScreenLog "WinHTTP (Servizi/Script): aggiornato correttamente." "Lime"
    } else {
        Write-ScreenLog "WinHTTP: errore durante l'aggiornamento." "Red"
    }

    # Aggiorna la status bar
    if ($wininetResult -and $winhttpResult) {
        $global:lblStatus.Text = "> Proxy applicato con successo."
    } else {
        $global:lblStatus.Text = "> Errore durante l'applicazione del proxy."
    }
}

# ============================================================
# FUNZIONE PER SALVARE UN NUOVO PROFILO NEL FILE XML
# ============================================================
function Save-NewProfile {
    param(
        [string]$Nome,
        [string]$Server,
        [string]$Porta,
        [string]$BypassList
    )

    if ([string]::IsNullOrWhiteSpace($Nome)) {
        [System.Windows.Forms.MessageBox]::Show("Il nome del profilo non può essere vuoto.", "MATRIX - ATTENZIONE", "OK", "Warning") | Out-Null
        return
    }

    # Controlla se il profilo esiste già
    $existing = $script:proxiesData.Proxies.Proxy | Where-Object { $_.Nome -eq $Nome }
    if ($existing) {
        [System.Windows.Forms.MessageBox]::Show("Esiste già un profilo con il nome '$Nome'. Scegli un altro nome.", "MATRIX - ATTENZIONE", "OK", "Warning") | Out-Null
        return
    }

    try {
        # Crea il nuovo nodo Proxy
        $newProxy = $script:proxiesData.CreateElement("Proxy")
        
        $nNome = $script:proxiesData.CreateElement("Nome"); $nNome.InnerText = $Nome; $newProxy.AppendChild($nNome) | Out-Null
        $nServer = $script:proxiesData.CreateElement("Server"); $nServer.InnerText = $Server; $newProxy.AppendChild($nServer) | Out-Null
        $nPorta = $script:proxiesData.CreateElement("Porta"); $nPorta.InnerText = $Porta; $newProxy.AppendChild($nPorta) | Out-Null
        $nBypass = $script:proxiesData.CreateElement("BypassList"); $nBypass.InnerText = $BypassList; $newProxy.AppendChild($nBypass) | Out-Null

        $script:proxiesData.Proxies.AppendChild($newProxy) | Out-Null
        
        # Salva il file XML
        $script:proxiesData.Save($script:proxiesFilePath)
        
        Write-ScreenLog "Nuovo profilo salvato: $Nome" "Lime"
        Update-ProfileCombo
        $global:cmbProfili.SelectedItem = $Nome
    } catch {
        Write-Log "Errore salvataggio profilo: $($_.Exception.Message)" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Errore durante il salvataggio del profilo: $($_.Exception.Message)", "MATRIX - ERRORE", "OK", "Error") | Out-Null
    }
}
# ------------------------------------------------------
# 					terzo blocco
# ------------------------------------------------------
# ============================================================
# EVENTI DELLA GUI
# ============================================================

# EVENTO: CARICA PROFILO
$global:btnLoadProfile.Add_Click({
    $selectedProfileName = $global:cmbProfili.SelectedItem
    if (-not $selectedProfileName) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona un profilo dalla lista.", "MATRIX - ATTENZIONE", "OK", "Warning") | Out-Null
        return
    }

    $profile = $script:proxiesData.Proxies.Proxy | Where-Object { $_.Nome -eq $selectedProfileName }
    if ($profile) {
        $global:txtServer.Text = $profile.Server
        $global:txtPorta.Text = $profile.Porta
        $global:txtBypass.Text = $profile.BypassList
        Write-ScreenLog "Profilo caricato: $selectedProfileName" "Cyan"
        $global:lblStatus.Text = "> Profilo '$selectedProfileName' caricato."
    }
})

# EVENTO: SALVA COME... (Nuovo Profilo)
$global:btnSaveProfile.Add_Click({
    # Chiedi il nome del profilo con un InputBox
    $nomeProfilo = [Microsoft.VisualBasic.Interaction]::InputBox("Inserisci il nome per il nuovo profilo:", "MATRIX - SALVA PROFILO", "")
    
    if (-not [string]::IsNullOrWhiteSpace($nomeProfilo)) {
        $server = $global:txtServer.Text.Trim()
        $porta = $global:txtPorta.Text.Trim()
        $bypass = $global:txtBypass.Text.Trim()

        if (-not $server) {
            [System.Windows.Forms.MessageBox]::Show("Il campo 'Server' è obbligatorio per salvare un profilo.", "MATRIX - ATTENZIONE", "OK", "Warning") | Out-Null
            return
        }

        Save-NewProfile -Nome $nomeProfilo.Trim() -Server $server -Porta $porta -BypassList $bypass
    }
})

# EVENTO: APPLICA PROXY
$global:btnApply.Add_Click({
    $server = $global:txtServer.Text.Trim()
    $porta = $global:txtPorta.Text.Trim()
    $bypass = $global:txtBypass.Text.Trim()
    $enable = $global:chkEnable.Checked

    if ($enable -and -not $server) {
        [System.Windows.Forms.MessageBox]::Show("Inserisci l'indirizzo del server proxy.", "MATRIX - ATTENZIONE", "OK", "Warning") | Out-Null
        return
    }

    Apply-ProxyConfiguration -Server $server -Porta $porta -BypassList $bypass -Enable $enable
})

# EVENTO: DISATTIVA PROXY
$global:btnDisable.Add_Click({
    $resp = [System.Windows.Forms.MessageBox]::Show(
        "Vuoi disattivare il proxy su entrambi i livelli (WinINET e WinHTTP)?",
        "MATRIX - CONFERMA", "YesNo", "Question"
    )
    if ($resp -eq "Yes") {
        Apply-ProxyConfiguration -Server "" -Porta "" -BypassList "" -Enable $false
        $global:chkEnable.Checked = $false
    }
})

# EVENTO: LEGGI CONFIGURAZIONE ATTUALE
$global:btnRead.Add_Click({
    Update-GuiFromSystem
})

# ============================================================
# AVVIO FORM
# ============================================================
$form.Add_Load({
    Write-ScreenLog "FRANK MOSES PROXY MANAGER v1.0 avviato." "Lime"
    Write-ScreenLog "Log file: $(Split-Path $script:logFile -Leaf)" "Cyan"
    Write-ScreenLog "Catalogo profili: $($script:proxiesFilePath)" "Cyan"
    Write-ScreenLog "============================================================" "DarkGray"
    
    # Popola la ComboBox dei profili
    Update-ProfileCombo
    
    # Leggi la configurazione attuale del sistema e popola i campi
    Update-GuiFromSystem
})

# Avvio della GUI
[void]$form.ShowDialog()

