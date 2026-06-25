#!/usr/bin/env bash
#
# install.sh — install entrokey (and its diceware wordlist) to a prefix
#
# Usage:
#   ./install.sh                 # installs to $HOME/.local (default)
#   PREFIX=/usr/local ./install.sh
#   PREFIX=$HOME/.local ./install.sh
#
# After install, entrokey.sh / entrokey.fish can be run from anywhere
# because diceware.txt is placed next to them (resolved via script dir).
#
set -euo pipefail

PREFIX="${PREFIX:-${HOME}/.local}"
BIN_DIR="${PREFIX}/bin"

echo "entrokey installer"
echo "  prefix: ${PREFIX}"
echo "  bin:    ${BIN_DIR}"
echo

if [ ! -f entrokey.sh ] || [ ! -f entrokey.fish ] || [ ! -f diceware.txt ]; then
    echo "Error: run this from the entrokey source directory (missing scripts or diceware.txt)." >&2
    exit 1
fi

mkdir -p "${BIN_DIR}"

cp -f entrokey.sh entrokey.fish diceware.txt "${BIN_DIR}/"

chmod +x "${BIN_DIR}/entrokey.sh" "${BIN_DIR}/entrokey.fish"

echo "Installed files:"
ls -l "${BIN_DIR}/entrokey.sh" "${BIN_DIR}/entrokey.fish" "${BIN_DIR}/diceware.txt"

echo
echo "✓ Done."
echo
echo "Ensure ${BIN_DIR} is in your PATH:"
echo
echo "  Bash / POSIX:"
echo "    echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ~/.bashrc"
echo "    # then: source ~/.bashrc"
echo
echo "  Fish:"
echo "    set -U fish_user_paths ${BIN_DIR} \$fish_user_paths"
echo
echo "Test:"
echo "  entrokey.sh --help"
echo "  entrokey.fish -g -n -f testkey   # should work from any directory now"
echo
echo "To remove:"
echo "  rm -f ${BIN_DIR}/entrokey.sh ${BIN_DIR}/entrokey.fish ${BIN_DIR}/diceware.txt"
echo
echo "Python deps (still needed):"
echo "  pip install --user mnemonic cryptography"
echo "  # or on Arch: yay -S python-mnemonic"
echo