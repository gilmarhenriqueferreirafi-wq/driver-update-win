[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Atualizar,
    [switch]$CriarPontoRestauracao,
    [switch]$ReiniciarSeNecessario
)

$ErrorActionPreference = 'Stop'
$LogPath = Join-Path $PSScriptRoot "Atualizar-Drivers-$((Get-Date).ToString('yyyyMMdd-HHmmss')).log"

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO')
    $line = "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [$Level] $Message"
    Write-Host $line
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-MissingDevices {
    try {
        return @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object {
            $null -ne $_.ConfigManagerErrorCode -and $_.ConfigManagerErrorCode -ne 0
        } | Select-Object Name, PNPClass, DeviceID, ConfigManagerErrorCode)
    } catch {
        Write-Log "Não foi possível consultar dispositivos PnP: $($_.Exception.Message)" 'WARN'
        return @()
    }
}

function Get-DriverUpdates {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $result = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Driver'")
    return @($result.Updates)
}

function Install-DriverUpdates {
    param([object[]]$Updates)
    $session = New-Object -ComObject Microsoft.Update.Session
    $collection = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($update in $Updates) {
        if (-not $update.EulaAccepted) { $update.AcceptEula() }
        [void]$collection.Add($update)
    }
    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $collection
    $downloadResult = $downloader.Download()
    if ($downloadResult.ResultCode -notin 2,3) {
        throw "Falha ao baixar drivers. Código: $($downloadResult.ResultCode)"
    }
    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $collection
    return $installer.Install()
}

try {
    New-Item -ItemType File -Path $LogPath -Force | Out-Null
    Write-Log 'Iniciando verificação de drivers.'

    if (-not (Test-Administrator)) {
        Write-Log 'Execute este script em um PowerShell aberto como Administrador.' 'ERROR'
        exit 1
    }

    $missingDevices = @(Get-MissingDevices)
    if ($missingDevices.Count -gt 0) {
        Write-Log "Dispositivo(s) com problema de driver: $($missingDevices.Count)" 'WARN'
        $missingDevices | Format-Table Name, PNPClass, ConfigManagerErrorCode -AutoSize | Out-String | ForEach-Object { Write-Log $_.TrimEnd() 'WARN' }
    } else {
        Write-Log 'Nenhum dispositivo PnP com problema de driver foi encontrado.'
    }

    if ($CriarPontoRestauracao) {
        Write-Log 'Criando ponto de restauração...'
        Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'Antes da atualização de drivers' -RestorePointType 'MODIFY_SETTINGS'
        Write-Log 'Ponto de restauração criado.'
    }

    $updates = @(Get-DriverUpdates)
    if ($updates.Count -eq 0) {
        Write-Log 'Nenhuma atualização de driver encontrada no Windows Update.'
        exit 0
    }

    Write-Log "Encontrada(s) $($updates.Count) atualização(ões):"
    $updates | Select-Object Title, KB, Size | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log $_.TrimEnd() }

    if (-not $Atualizar) {
        Write-Log 'Modo de análise: nada foi instalado. Use -Atualizar para instalar.'
        exit 0
    }

    if (-not $PSCmdlet.ShouldProcess("$($updates.Count) driver(s)", 'Instalar atualizações')) {
        exit 0
    }

    Write-Log 'Instalando atualizações de drivers...'
    $installResult = Install-DriverUpdates -Updates $updates
    Write-Log "Resultado da instalação: $($installResult.ResultCode)"
    Write-Log 'Processo de atualização concluído.'

    if ($ReiniciarSeNecessario) {
        Write-Log 'Reinicialização solicitada. O computador será reiniciado em 60 segundos.' 'WARN'
        shutdown.exe /r /t 60 /c 'Reinicialização após atualização de drivers'
    } else {
        Write-Log 'Não reiniciei automaticamente. Reinicie se o Windows solicitar.'
    }
} catch {
    Write-Log $_.Exception.Message 'ERROR'
    exit 1
}