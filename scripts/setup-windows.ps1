param(
    [switch]$InstallMissing = $true
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Has-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-WithWinget {
    param(
        [string]$Id,
        [string]$DisplayName
    )
    Write-Host "Provo a installare $DisplayName tramite winget..."
    $args = @("install", "--exact", "--id", $Id, "--accept-source-agreements", "--accept-package-agreements")
    $process = Start-Process -FilePath "winget" -ArgumentList $args -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        throw "winget non e' riuscito a installare $DisplayName (exit code $($process.ExitCode))."
    }
}

function Ensure-Dependency {
    param(
        [string]$Name,
        [string]$Command,
        [string]$WingetId,
        [string]$ManualUrl
    )

    if (Has-Command $Command) {
        Write-Host "$Name gia' disponibile."
        return
    }

    if (-not $InstallMissing) {
        Write-Warning "$Name mancante. Installa manualmente da $ManualUrl"
        return
    }

    if (-not (Has-Command "winget")) {
        Write-Warning "winget non e' disponibile. Installa $Name manualmente da $ManualUrl"
        return
    }

    try {
        Install-WithWinget -Id $WingetId -DisplayName $Name
    }
    catch {
        Write-Warning $_.Exception.Message
        Write-Warning "Installazione di $Name fallita. Visita $ManualUrl per completare il setup manuale."
        return
    }

    if (Has-Command $Command) {
        Write-Host "$Name installato."
    }
    else {
        Write-Warning "$Name risulta ancora mancante. Verifica PATH oppure installa manualmente da $ManualUrl"
    }
}

Write-Host "=== Controllo dipendenze NotAFK-Agent (Windows) ==="

$deps = @(
    @{ Name = "Git"; Command = "git"; WingetId = "Git.Git"; ManualUrl = "https://git-scm.com/download/win" },
    @{ Name = "curl"; Command = "curl"; WingetId = "CURL.CURL"; ManualUrl = "https://curl.se/windows/" },
    @{ Name = "uv"; Command = "uv"; WingetId = "Astral Software.UV"; ManualUrl = "https://astral.sh/uv" }
)

foreach ($dep in $deps) {
    Ensure-Dependency @dep
}

Write-Host ""
Write-Host "Se usi NotAFK-Agent su Windows non serve xdotool. Dopo l'installazione delle dipendenze, puoi lanciare lo script di build:"
Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -Command `"Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/install-windows.ps1' -OutFile '$env:TEMP\\notafk-install.ps1'; & $env:TEMP\\notafk-install.ps1; Remove-Item $env:TEMP\\notafk-install.ps1`""
