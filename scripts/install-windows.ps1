param(
    [string]$RepoUrl = "https://github.com/gaumeloth/NotAFK-agent.git",
    [string]$Branch = "main",
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Test-Dependency {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Lo strumento richiesto '$Name' non e' stato trovato nel PATH."
    }
}

Test-Dependency -Name "git"
Test-Dependency -Name "uv"

$callerPath = (Get-Location).ProviderPath
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $callerPath "NotAFK-Agent.exe"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("notafk-agent-" + [System.Guid]::NewGuid())
$repoPath = Join-Path $tempRoot "repo"
New-Item -ItemType Directory -Path $tempRoot | Out-Null

Write-Host "Clono $RepoUrl (branch $Branch) in $repoPath..."
git clone --depth 1 --branch $Branch $RepoUrl $repoPath | Out-Null

try {
    Push-Location $repoPath

    Write-Host "Installo Python 3.13 tramite uv (se necessario)..."
    uv python install 3.13 | Out-Null

    Write-Host "Sincronizzo dipendenze con uv..."
    uv sync --frozen --group dev | Out-Null

    Write-Host "Eseguo PyInstaller tramite uv..."
    uv run pyinstaller --noconfirm --onefile --name NotAFK-Agent notafk-agent.py | Out-Null

    $artifact = Join-Path $repoPath "dist\NotAFK-Agent.exe"
    if (-not (Test-Path $artifact)) {
        throw "Build fallita: artefatto $artifact non trovato."
    }

    Copy-Item -Path $artifact -Destination $OutputPath -Force
    Write-Host "Build completata. File copiato in $OutputPath"
}
finally {
    try {
        Pop-Location | Out-Null
    } catch {
        # stack vuoto
    }
    if (-not $env:NOTAFK_KEEP_TEMP) {
        Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "Cartella temporanea conservata in $tempRoot"
    }
}
