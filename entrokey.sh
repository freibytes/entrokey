#!/usr/bin/env bash

VERSION="0.2.0"

show_version() {
    echo "entrokey $VERSION"
}

show_help() {
    echo "entrokey.sh - Generate deterministic ed25519 SSH keys from BIP39 or Diceware"
    echo ""
    echo "Usage: entrokey.sh [OPTIONS] [MNEMONIC WORDS...]"
    echo ""
    echo "Options:"
    echo "  -h, --help                  Show this help message and exit"
    echo "  -V, --version               Show version and exit"
    echo "  -f, --filename NAME         Output filename base (skips interactive prompt)"
    echo "  -n, --no-password           Generate unencrypted private key (no passphrase)"
    echo "  -g, --generate-mnemonic     Generate a secure Diceware mnemonic"
    echo "  -w, --words N               Number of diceware words when using -g (default: 12)"
    echo "  -m, --move-keys             Move keys to $HOME/.ssh/ (if dir exists) after chmod 600"
    echo ""
    echo "Description:"
    echo "  Derives an ed25519 private key deterministically from a mnemonic using"
    echo "  HKDF-SHA256. Writes OpenSSH format private key + .pub file."
    echo ""
    echo "  -g generates cryptographically random words from the local EFF Diceware list."
    echo "  The generated mnemonic is printed so you can write it down."
    echo ""
    echo "Security notes:"
    echo "  - 12 words ≈ 155 bits of entropy (good default)"
    echo "  - 18 words ≈ 230 bits"
    echo "  - 24 words ≈ 310 bits"
    echo "  - Always use --no-password only for testing or non-sensitive keys"
    echo ""
    echo "Examples:"
    echo "  entrokey.sh -g -n -w 18 -f mykey"
    echo "  entrokey.sh -f id_ed25519 \"word1 word2 ...\""
    echo "  entrokey.sh -g --no-password"
    echo "  entrokey.sh -h"
}

# Defaults
help=0
version=0
filename=""
no_password=0
generate_mnemonic=0
words=12
move_keys=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            help=1
            shift
            ;;
        -V|--version)
            version=1
            shift
            ;;
        -f|--filename)
            filename="$2"
            shift 2
            ;;
        -n|--no-password)
            no_password=1
            shift
            ;;
        -g|--generate-mnemonic)
            generate_mnemonic=1
            shift
            ;;
        -w|--words)
            words="$2"
            shift 2
            ;;
        -m|--move-keys)
            move_keys=1
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [ "$help" -eq 1 ]; then
    show_help
    exit 0
fi

if [ "$version" -eq 1 ]; then
    show_version
    exit 0
fi

# Validate word count
if ! [[ "$words" =~ ^[0-9]+$ ]] || [ "$words" -lt 6 ] || [ "$words" -gt 24 ]; then
    echo "Error: --words must be a number between 6 and 24" >&2
    exit 1
fi

# Handle mnemonic generation or input
if [ "$generate_mnemonic" -eq 1 ]; then
    if [ ! -f diceware.txt ]; then
        echo "Error: diceware.txt not found in current directory." >&2
        echo "Please ensure the wordlist is present." >&2
        exit 1
    fi

    mnemonic=$(shuf -n "$words" diceware.txt | tr '\n' ' ' | sed 's/ *$//')
    echo "Generated $words-word mnemonic (WRITE THIS DOWN!):"
    echo "  $mnemonic"
    echo ""
else
    if [ $# -eq 0 ]; then
        echo "Error: No mnemonic provided. Use -g/--generate-mnemonic or provide words." >&2
        exit 1
    fi
    mnemonic="$*"
fi

use_encryption=1
if [ "$no_password" -eq 1 ]; then
    use_encryption=0
fi

# Filename handling
if [ -n "$filename" ]; then
    basename="$filename"
else
    read -p "Filename without extension (e.g. id_ed25519): " basename
fi

if [ -z "$basename" ]; then
    echo "No filename provided. Aborting." >&2
    exit 1
fi

if [ "$use_encryption" -eq 1 ]; then
    read -s -p "Enter passphrase for private key: " passphrase
    echo
    read -s -p "Confirm passphrase: " passphrase2
    echo

    if [ "$passphrase" != "$passphrase2" ]; then
        echo "Passphrases do not match. Aborting." >&2
        exit 1
    fi

    if [ -z "$passphrase" ]; then
        echo "No passphrase provided. Aborting." >&2
        exit 1
    fi
else
    passphrase=""
fi

priv_key="$basename"
pub_key="${basename}.pub"

# Generate the key (using the same quoting pattern that worked before)
if [ "$use_encryption" -eq 1 ]; then
    python3 -c '
from mnemonic import Mnemonic
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
import sys

mnemo = Mnemonic("english")
seed = mnemo.to_seed('"'$mnemonic'"', passphrase="")

hkdf = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=b"ed25519-key-from-bip39")
key_bytes = hkdf.derive(seed)

priv = Ed25519PrivateKey.from_private_bytes(key_bytes)
pub = priv.public_key()

encryption = serialization.BestAvailableEncryption(b"'"$passphrase"'")

with open("'"$priv_key"'", "wb") as f:
    f.write(priv.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.OpenSSH,
        encryption_algorithm=encryption
    ))

with open("'"$pub_key"'", "wb") as f:
    f.write(pub.public_bytes(
        encoding=serialization.Encoding.OpenSSH,
        format=serialization.PublicFormat.OpenSSH
    ))

print("Encrypted private key generated successfully")
' 2>&1
else
    python3 -c '
from mnemonic import Mnemonic
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
import sys

mnemo = Mnemonic("english")
seed = mnemo.to_seed('"'$mnemonic'"', passphrase="")

hkdf = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=b"ed25519-key-from-bip39")
key_bytes = hkdf.derive(seed)

priv = Ed25519PrivateKey.from_private_bytes(key_bytes)
pub = priv.public_key()

with open("'"$priv_key"'", "wb") as f:
    f.write(priv.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.OpenSSH,
        encryption_algorithm=serialization.NoEncryption()
    ))

with open("'"$pub_key"'", "wb") as f:
    f.write(pub.public_bytes(
        encoding=serialization.Encoding.OpenSSH,
        format=serialization.PublicFormat.OpenSSH
    ))

print("Unencrypted private key generated successfully")
' 2>&1
fi

if [ $? -ne 0 ]; then
    echo "Failed to generate key." >&2
    echo "Make sure the packages are installed: pip install mnemonic cryptography" >&2
    exit 1
fi

chmod 600 "$priv_key"
chmod 644 "$pub_key" 2>/dev/null || true

moved=0
if [ "$move_keys" -eq 1 ]; then
    if [ -d "$HOME/.ssh" ]; then
        mv "$priv_key" "$pub_key" "$HOME/.ssh/"
        priv_key="$HOME/.ssh/$basename"
        pub_key="$HOME/.ssh/$basename.pub"
        chmod 600 "$priv_key"
        moved=1
    else
        echo "Note: \$HOME/.ssh does not exist — keys left in current directory" >&2
    fi
fi

echo
echo "✓ Key generated successfully"
echo "  Private key : $priv_key"
echo "  Public key  : $pub_key"

# Show fingerprint if possible
if command -v ssh-keygen >/dev/null 2>&1; then
    fp=$(ssh-keygen -lf "$pub_key" 2>/dev/null | awk '{print $2}')
    if [ -n "$fp" ]; then
        echo "  Fingerprint : $fp"
    fi
fi

echo
if [ "$use_encryption" -eq 1 ]; then
    echo "  (private key is encrypted with a passphrase)"
else
    echo "  (private key is NOT encrypted)"
fi
if [ "$moved" -eq 1 ]; then
    echo "  (keys moved to \$HOME/.ssh)"
fi
echo
