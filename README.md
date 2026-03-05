# NotAFK Agent

Utility desktop che simula un piccolo movimento del mouse ogni pochi minuti per evitare lo stato *Away From Keyboard*. Funziona su Windows (GUI Tkinter + selettore finestre WinAPI) e su Linux X11 tramite `xdotool`.

## Requisiti principali
- `uv` installato e presente nel PATH (usera' il file `.python-version` per ottenere Python 3.13).
- `git` e `curl`/`Invoke-WebRequest` disponibili.
- Facoltativo ma consigliato su Linux: `xdotool` per limitare i movimenti all'interno di una finestra specifica.

## Controllo e installazione delle dipendenze
### Verifica manuale
```powershell
git --version
curl --version
uv version
```
Su Linux/X11 controlla anche `xdotool -v`. Se uno di questi comandi non viene trovato, installalo con il tuo package manager oppure usa gli script di setup descritti sotto.

### Setup automatico (Windows)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$script = Join-Path $env:TEMP 'notafk-setup.ps1'; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/setup-windows.ps1' -OutFile $script; & $script; Remove-Item $script"
```
Lo script `setup-windows.ps1`:
- verifica `git`, `curl` e `uv`;
- se manca qualcosa e `winget` e' disponibile, avvia automaticamente `winget install …`;
- in caso contrario stampa il link ufficiale da cui scaricare l'installer.
Al termine, usa una nuova finestra di PowerShell/Prompt per assicurarti che `uv` sia nel PATH.

### Setup automatico (Linux/macOS)
```bash
curl -fsSL https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/setup-unix.sh | bash
```
`setup-unix.sh` rileva il package manager piu' comune (`apt`, `dnf`, `yum`, `pacman`, `zypper`, `brew`) e prova a installare `git` e `curl`. Per `uv` usa Homebrew su macOS oppure lo script ufficiale `astral.sh/uv`. Su Linux installa anche `xdotool` se stai usando X11. Se il tuo sistema usa un package manager diverso, lo script ti dira' come procedere manualmente.

## Build con un solo comando
Gli script in `scripts/` scaricano il repository `https://github.com/gaumeloth/NotAFK-agent.git`, si appoggiano a `uv` per installare Python 3.13 se manca, sincronizzano le dipendenze (incluso `pyinstaller` dal gruppo `dev`) e copiano il binario finale nella cartella dalla quale e' stato lanciato il comando.

### Windows (PowerShell)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$script = Join-Path $env:TEMP 'notafk-install.ps1'; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/install-windows.ps1' -OutFile $script; & $script; Remove-Item $script"
```
`install-windows.ps1` contiene l'intera logica: prima lancia automaticamente `setup-windows.ps1` (locale se disponibile, altrimenti scaricato) per installare/aggiornare `git`, `curl` e `uv`; poi clona una working copy temporanea, esegue `uv sync` e `uv run pyinstaller`, e copia `NotAFK-Agent.exe` nella cartella corrente. Imposta `NOTAFK_SKIP_SETUP=1` se vuoi saltare l'esecuzione del setup (ad esempio quando lavori gia' dal repo e hai le dipendenze a posto).
Opzioni utili dello script:
- `-Branch nome-branch` o `-RepoUrl URL` per puntare a fork/branch diversi.
- `-OutputPath C:\percorso\NotAFK-Agent.exe` per scegliere dove salvare l'eseguibile.
- Variabile `NOTAFK_KEEP_TEMP=1` (settata prima del comando) per conservare la cartella temporanea con gli artefatti intermedi.

### Windows (CMD/BAT puro)
```cmd
cmd /c "curl -fsSL https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/install-windows.cmd -o %TEMP%\notafk-build.cmd && call %TEMP%\notafk-build.cmd && del %TEMP%\notafk-build.cmd"
```
`install-windows.cmd` e' solo un wrapper: se trova `install-windows.ps1` nella stessa cartella lo esegue direttamente, altrimenti scarica l'ultima versione dal branch `main` e poi lo lancia con PowerShell a `ExecutionPolicy Bypass`. E' utile per scenari in cui desideri restare nel prompt classico (ad esempio `.bat`/`cmd` one-liner) o quando vuoi distribuire un singolo file batch che richiami lo script PowerShell senza copiarlo a mano.

### Linux / macOS (Bash)
```bash
curl -fsSL https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/install-unix.sh | bash
```
Variabili utili:
- `REPO_URL` e `BRANCH` per puntare a fork o branch personalizzati.
- `NOTAFK_OUTPUT` per cambiare il nome/percorso del binario generato (default `./NotAFK-Agent`).
- `NOTAFK_KEEP_TEMP=1` per NON eliminare la cartella temporanea usata per il build.
- `NOTAFK_SKIP_SETUP=1` per saltare l'esecuzione di `setup-unix.sh` (di default lo script la scarica/avvia per assicurarsi che `git`, `curl`, `uv` e `xdotool` siano presenti).

## Cosa fanno gli script
1. Controllano la presenza di `git` e `uv`.
2. Clonano il repository in una directory temporanea (`%TEMP%\notafk-agent-*` oppure `/tmp/notafk-agent-*`).
3. Eseguono `uv python install 3.13` (per assicurare l'interprete richiesto) e `uv sync --frozen --group dev`.
4. Avviano `uv run pyinstaller --onefile notafk-agent.py` e copiano il risultato nella directory chiamante (`NotAFK-Agent.exe` su Windows, `NotAFK-Agent` su Linux/macOS).

## Build manuale (alternativa)
```bash
git clone https://github.com/gaumeloth/NotAFK-agent.git
cd NotAFK-agent
uv python install 3.13
uv sync --group dev
uv run pyinstaller --onefile --name NotAFK-Agent notafk-agent.py
```
L'eseguibile finale sara' in `dist/`.
