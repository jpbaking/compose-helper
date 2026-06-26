#!/bin/bash
# Github: https://github.com/jpbaking/compose-helper
# Installs compose-helper.sh into the current directory.
# Run from inside your project directory (alongside docker-compose.yaml):
#   curl -fsSL https://raw.githubusercontent.com/jpbaking/compose-helper/main/.install-helper/install.sh | bash

set -e

BASE="https://raw.githubusercontent.com/jpbaking/compose-helper/main"
SCRIPT="compose-helper.sh"
ENV_FILE="compose-helper.env"
ENV_EXAMPLE_URL="$BASE/compose-helper.env.example"

_download() {
    if command -v curl &>/dev/null; then
        curl -fsSL "$1" -o "$2"
    elif command -v wget &>/dev/null; then
        wget -qO "$2" "$1"
    else
        echo "Error: neither curl nor wget found" >&2
        exit 1
    fi
}

echo "==> Downloading $SCRIPT..."
_download "$BASE/$SCRIPT" "$SCRIPT"
chmod +x "$SCRIPT"
echo "    OK"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

echo "==> Checking $ENV_FILE..."
_download "$ENV_EXAMPLE_URL" "$tmp"

if [[ ! -f "$ENV_FILE" ]]; then
    cp "$tmp" "$ENV_FILE"
    echo "    Created $ENV_FILE"
else
    # Extract key names from a KEY=value file, handling # commented-out keys.
    _keys() {
        grep -E '^[[:space:]]*#?[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$1" \
            | sed 's/^[[:space:]]*#*[[:space:]]*//' \
            | cut -d= -f1 \
            | tr -d ' \t'
    }

    new_keys=()
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        grep -qE "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" || new_keys+=("$key")
    done < <(_keys "$tmp")

    if [[ ${#new_keys[@]} -gt 0 ]]; then
        echo "    $ENV_FILE already exists — not overwritten."
        echo "    New keys in the latest example missing from your $ENV_FILE:"
        printf "      %s\n" "${new_keys[@]}"
        echo "    See $ENV_EXAMPLE_URL to add them manually."
    else
        echo "    $ENV_FILE is up to date — not overwritten."
    fi
fi

echo ""
echo "Done. Run: ./$SCRIPT --help"
