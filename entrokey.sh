#!/usr/bin/env bash

show_help() {
    echo "entrokey.sh - Generate encrypted ed25519 SSH keys from a BIP39 mnemonic or Diceware words"
    echo ""
    echo "Usage: entrokey.sh [OPTIONS] [MNEMONIC WORDS...]"
    echo ""
    echo "Options:"
    echo "  -h, --help                  Show this help message and exit"
    echo "  -n, --no-password           Skip passphrase prompt and do not encrypt the private key"
    echo "  -g, --generate-mnemonic     Generate a secure 12-word Diceware mnemonic instead of requiring one"
    echo ""
    echo "Description:"
    echo "  Takes a space-separated BIP39 mnemonic (or Diceware words) as input,"
    echo "  derives a deterministic ed25519 private key using HKDF-SHA256,"
    echo "  and writes an OpenSSH-formatted private key (optionally encrypted)"
    echo "  plus the corresponding .pub file."
    echo ""
    echo "  Use -g to auto-generate a cryptographically secure 12-word mnemonic from the"
    echo "  EFF Diceware list (printed for you to save/write down)."
    echo ""
    echo "Examples:"
    echo "  entrokey.sh \"abandon ability able about above absent absorb abstract absurd abuse access accident\""
    echo "  entrokey.sh -g -n"
    echo "  entrokey.sh -h"
}

help=0
no_password=0
generate_mnemonic=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            help=1
            shift
            ;;
        -n|--no-password)
            no_password=1
            shift
            ;;
        -g|--generate-mnemonic)
            generate_mnemonic=1
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

if [ "$generate_mnemonic" -eq 1 ]; then
    mnemonic=$(shuf -n 12 diceware.txt | tr '\n' ' ' | sed 's/ *$//')
    echo "Generated mnemonic (SAVE THIS!): $mnemonic"
else
    if [ $# -eq 0 ]; then
        echo "Error: No mnemonic provided. Use -g/--generate-mnemonic to auto-generate one."
        exit 1
    fi
    mnemonic="$*"
fi

use_encryption=1
if [ "$no_password" -eq 1 ]; then
    use_encryption=0
fi

read -p "Filename without extension (e.g. id_ed25519): " basename

if [ -z "$basename" ]; then
    echo "No filename provided. Aborting."
    exit 1
fi

if [ "$use_encryption" -eq 1 ]; then
    read -s -p "Enter passphrase for private key: " passphrase
    echo
    read -s -p "Confirm passphrase: " passphrase2
    echo

    if [ "$passphrase" != "$passphrase2" ]; then
        echo "Passphrases do not match. Aborting."
        exit 1
    fi

    if [ -z "$passphrase" ]; then
        echo "No passphrase provided. Aborting."
        exit 1
    fi
else
    passphrase=""
fi

priv_key="$basename"
pub_key="${basename}.pub"

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
    echo "Failed to generate key."
    echo "Make sure the packages are installed: pip install mnemonic cryptography"
    exit 1
fi

chmod 600 "$priv_key"

echo
if [ "$use_encryption" -eq 1 ]; then
    echo "✓ Created (private key is encrypted with passphrase):"
else
    echo "✓ Created (private key is NOT encrypted):"
fi
echo "  Private key : $priv_key"
echo "  Public key  : $pub_key"
echo
