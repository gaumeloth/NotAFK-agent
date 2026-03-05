#!/usr/bin/env bash

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/gaumeloth/NotAFK-agent.git}"
BRANCH="${BRANCH:-main}"
OUTPUT_OVERRIDE="${NOTAFK_OUTPUT:-}"

SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

run_setup() {
    if [[ "${NOTAFK_SKIP_SETUP:-}" == "1" ]]; then
        echo "NOTAFK_SKIP_SETUP=1 rilevato: salto il setup automatico delle dipendenze."
        return
    fi

    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/setup-unix.sh" ]]; then
        echo "Eseguo script di setup locale ($SCRIPT_DIR/setup-unix.sh)..."
        bash "$SCRIPT_DIR/setup-unix.sh"
    else
        echo "Scarico ed eseguo lo script di setup..."
        curl -fsSL https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/setup-unix.sh | bash
    fi
}

run_setup

if ! command -v git >/dev/null 2>&1; then
    echo "Errore: git non e' installato o non e' nel PATH." >&2
    exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
    echo "Errore: uv non e' installato o non e' nel PATH." >&2
    exit 1
fi

CALLER_DIR="$(pwd -P)"

if [[ "$(uname)" == "Darwin" ]]; then
    WORKDIR="$(mktemp -d -t notafk-agent)"
else
    WORKDIR="$(mktemp -d)"
fi

cleanup() {
    if [[ -z "${NOTAFK_KEEP_TEMP:-}" ]]; then
        rm -rf "$WORKDIR"
    else
        echo "Cartella temporanea conservata in $WORKDIR"
    fi
}
trap cleanup EXIT

echo "Clono $REPO_URL (branch $BRANCH)..."
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$WORKDIR/repo" >/dev/null

cd "$WORKDIR/repo"

echo "Installo Python 3.13 tramite uv (se necessario)..."
uv python install 3.13 >/dev/null

echo "Sincronizzo dipendenze con uv..."
uv sync --frozen --group dev >/dev/null

echo "Avvio PyInstaller tramite uv..."
uv run pyinstaller --noconfirm --onefile --name NotAFK-Agent notafk-agent.py >/dev/null

ARTIFACT="dist/NotAFK-Agent"
if [[ ! -f "$ARTIFACT" ]]; then
    echo "Errore: artefatto PyInstaller non trovato in $ARTIFACT" >&2
    exit 1
fi

if [[ -n "$OUTPUT_OVERRIDE" ]]; then
    case "$OUTPUT_OVERRIDE" in
        /*) DEST_PATH="$OUTPUT_OVERRIDE" ;;
        ~*) DEST_PATH="$OUTPUT_OVERRIDE" ;;
        *) DEST_PATH="$CALLER_DIR/$OUTPUT_OVERRIDE" ;;
    esac
else
    DEST_PATH="$CALLER_DIR/NotAFK-Agent"
fi

cp -f "$ARTIFACT" "$DEST_PATH"
chmod +x "$DEST_PATH"

echo "Build completata. File disponibile in $DEST_PATH"
