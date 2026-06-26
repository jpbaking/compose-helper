#!/bin/bash
# Github: https://github.com/jpbaking/compose-helper
# Installs compose-helper.py into the current directory.
# Run from inside your project directory (alongside docker-compose.yaml):
#   curl -fsSL https://raw.githubusercontent.com/jpbaking/compose-helper/main/.install-helper/install-py.sh | bash

set -e

BASE="https://raw.githubusercontent.com/jpbaking/compose-helper/main"
SCRIPT="compose-helper.py"
ENV_FILE="compose-helper.env"
ENV_EXAMPLE_URL="$BASE/compose-helper.env.example"

echo "==> Downloading $SCRIPT..."
curl -fsSL "$BASE/$SCRIPT" -o "$SCRIPT"
chmod +x "$SCRIPT"
echo "    OK"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

echo "==> Checking $ENV_FILE..."
curl -fsSL "$ENV_EXAMPLE_URL" -o "$tmp"

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
