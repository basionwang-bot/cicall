#!/bin/sh
set -eu

VERSION="${CICALL_VERSION:-0.1.0}"
INSTALL_ROOT="${CICALL_INSTALL_ROOT:-$HOME/.local/share/cicall}"
BIN_DIR="${CICALL_BIN_DIR:-$HOME/.local/bin}"
WHEEL_URL="${CICALL_WHEEL_URL:-https://github.com/basionwang-bot/cicall/releases/download/v${VERSION}/cicall-${VERSION}-py3-none-any.whl}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "cicall: python3 is required" >&2
  exit 1
fi

if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)'; then
  echo "cicall: Python 3.9 or newer is required" >&2
  exit 1
fi

mkdir -p "$INSTALL_ROOT" "$BIN_DIR"
python3 -m venv "$INSTALL_ROOT/venv"
"$INSTALL_ROOT/venv/bin/python" -m pip install --upgrade "$WHEEL_URL"

for command in cicall cicall-mcp cicall-daemon; do
  ln -sf "$INSTALL_ROOT/venv/bin/$command" "$BIN_DIR/$command"
done

echo "Cicall ${VERSION} installed successfully."
echo "Run: $BIN_DIR/cicall setup --client hermes --project my-project --cwd \"\$PWD\""
if ! printf '%s' ":$PATH:" | grep -q ":$BIN_DIR:"; then
  echo "Note: add $BIN_DIR to PATH, or invoke Cicall with its absolute path."
fi
