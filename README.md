# NotAFK Agent

Utility desktop che simula un piccolo movimento del mouse ogni pochi minuti per evitare lo stato *Away From Keyboard*. Funziona su Windows (GUI Tkinter + selettore finestre WinAPI) e su Linux X11 tramite `xdotool`.

## Requisiti principali
- `uv` installato e presente nel PATH (usera' il file `.python-version` per ottenere Python 3.13).
- `git` e `curl`/`Invoke-WebRequest` disponibili.
- Facoltativo ma consigliato su Linux: `xdotool` per limitare i movimenti all'interno di una finestra specifica.

## Build con un solo comando
Gli script in `scripts/` scaricano il repository `https://github.com/gaumeloth/NotAFK-agent.git`, si appoggiano a `uv` per installare Python 3.13 se manca, sincronizzano le dipendenze (incluso `pyinstaller` dal gruppo `dev`) e copiano il binario finale nella cartella dalla quale e' stato lanciato il comando.

### Windows (PowerShell)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$script = Join-Path $env:TEMP 'notafk-install.ps1'; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/install-windows.ps1' -OutFile $script; & $script; Remove-Item $script"
```
`install-windows.ps1` contiene l'intera logica: esegue il clone temporaneo, usa `uv sync` e `uv run pyinstaller`, e copia `NotAFK-Agent.exe` nella cartella corrente. Usalo quando hai gia' PowerShell disponibile (versione consigliata su Windows 10/11).
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
