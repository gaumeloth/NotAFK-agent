#!/usr/bin/env bash

set -euo pipefail

REQUIRED_COMMANDS=("git" "curl" "uv")
OPTIONAL_COMMANDS=()

OS="$(uname -s)"
if [[ "$OS" == "Linux" ]]; then
    OPTIONAL_COMMANDS+=("xdotool")
fi

PKG_MANAGER=""
PKG_CMD=()
APT_UPDATED=0

detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
    elif command -v brew >/dev/null 2>&1; then
        PKG_MANAGER="brew"
    fi
}

install_packages() {
    if [[ -z "$PKG_MANAGER" ]]; then
        echo "Impossibile determinare un package manager supportato. Installa manualmente: $*" >&2
        return 1
    fi

    case "$PKG_MANAGER" in
        apt)
            if [[ $APT_UPDATED -eq 0 ]]; then
                sudo apt-get update
                APT_UPDATED=1
            fi
            sudo apt-get install -y "$@"
            ;;
        dnf)
            sudo dnf install -y "$@"
            ;;
        yum)
            sudo yum install -y "$@"
            ;;
        pacman)
            sudo pacman -Sy --noconfirm "$@"
            ;;
        zypper)
            sudo zypper install -y "$@"
            ;;
        brew)
            brew install "$@"
            ;;
        *)
            echo "Package manager $PKG_MANAGER non gestito. Installa manualmente: $*" >&2
            return 1
            ;;
    esac
}

ensure_command() {
    local name="$1"
    local optional="${2:-0}"

    if command -v "$name" >/dev/null 2>&1; then
        echo "$name gia' presente."
        return 0
    fi

    if [[ "$name" == "uv" ]]; then
        install_uv
        return $?
    fi

    if install_packages "$name"; then
        echo "$name installato."
    else
        if [[ "$optional" -eq 1 ]]; then
            echo "Avviso: impossibile installare $name automaticamente. Installa manualmente (solo necessario se vuoi limitare i movimenti a una finestra specifica)." >&2
        else
            echo "Errore: $name non installato. Segui le istruzioni del tuo sistema per installarlo." >&2
            exit 1
        fi
    fi
}

install_uv() {
    if command -v uv >/dev/null 2>&1; then
        echo "uv gia' presente."
        return 0
    fi

    if [[ "$PKG_MANAGER" == "brew" ]]; then
        brew install uv
    else
        echo "Installo uv tramite lo script ufficiale..."
        curl -fsSL https://astral.sh/uv/install.sh | sh
    fi

    if command -v uv >/dev/null 2>&1; then
        echo "uv installato."
    else
        echo "Impossibile verificare l'installazione di uv. Aggiungi manualmente ~/.local/bin o il percorso indicato dallo script ufficiale al PATH." >&2
        exit 1
    fi
}

echo "=== Controllo dipendenze NotAFK-Agent (Linux/macOS) ==="
detect_pkg_manager

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    ensure_command "$cmd"
done

for cmd in "${OPTIONAL_COMMANDS[@]}"; do
    ensure_command "$cmd" 1
done

echo ""
echo "Dipendenze principali installate."
echo "Per generare il binario, esegui:"
echo "  curl -fsSL https://raw.githubusercontent.com/gaumeloth/NotAFK-agent/main/scripts/install-unix.sh | bash"
