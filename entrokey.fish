#!/usr/bin/env fish

function show_help
    echo "entrokey.fish - Generate encrypted ed25519 SSH keys from a BIP39 mnemonic or Diceware words"
    echo ""
    echo "Usage: entrokey.fish [OPTIONS] [MNEMONIC WORDS...]"
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
    echo "  entrokey.fish \"abandon ability able about above absent absorb abstract absurd abuse access accident\""
    echo "  entrokey.fish -g -n"
    echo "  entrokey.fish -h"
end

argparse --stop-nonopt 'h/help' 'n/no-password' 'g/generate-mnemonic' -- $argv
or return 1

if set -q _flag_help
    show_help
    exit 0
end

if set -q _flag_generate_mnemonic
    set mnemonic (shuf -n 12 diceware.txt | string join ' ')
    echo "Generated mnemonic (SAVE THIS!): $mnemonic"
else
    if test (count $argv) -eq 0
        echo "Error: No mnemonic provided. Use -g/--generate-mnemonic to auto-generate one."
        exit 1
    end
    set mnemonic $argv
end

set -l use_encryption 1
if set -q _flag_no_password
    set use_encryption 0
end

read -P "Filename without extension (e.g. id_ed25519): " basename

if test -z "$basename"
    echo "No filename provided. Aborting."
    exit 1
end

if test $use_encryption -eq 1
    read -s -P "Enter passphrase for private key: " passphrase
    read -s -P "Confirm passphrase: " passphrase2

    if test "$passphrase" != "$passphrase2"
        echo "Passphrases do not match. Aborting."
        exit 1
    end

    if test -z "$passphrase"
        echo "No passphrase provided. Aborting."
        exit 1
    end
else
    set passphrase ""
end

set priv_key "$basename"
set pub_key  "$basename.pub"

if test $use_encryption -eq 1
    python3 -c "
from mnemonic import Mnemonic
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
import getpass
import sys

mnemo = Mnemonic('english')
seed = mnemo.to_seed('$mnemonic', passphrase='')

hkdf = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=b'ed25519-key-from-bip39')
key_bytes = hkdf.derive(seed)

priv = Ed25519PrivateKey.from_private_bytes(key_bytes)
pub = priv.public_key()

encryption = serialization.BestAvailableEncryption(b'$passphrase')

with open('$priv_key', 'wb') as f:
    f.write(priv.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.OpenSSH,
        encryption_algorithm=encryption
    ))

with open('$pub_key', 'wb') as f:
    f.write(pub.public_bytes(
        encoding=serialization.Encoding.OpenSSH,
        format=serialization.PublicFormat.OpenSSH
    ))

print('Encrypted private key generated successfully')
" 2>&1
else
    python3 -c "
from mnemonic import Mnemonic
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
import sys

mnemo = Mnemonic('english')
seed = mnemo.to_seed('$mnemonic', passphrase='')

hkdf = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=b'ed25519-key-from-bip39')
key_bytes = hkdf.derive(seed)

priv = Ed25519PrivateKey.from_private_bytes(key_bytes)
pub = priv.public_key()

with open('$priv_key', 'wb') as f:
    f.write(priv.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.OpenSSH,
        encryption_algorithm=serialization.NoEncryption()
    ))

with open('$pub_key', 'wb') as f:
    f.write(pub.public_bytes(
        encoding=serialization.Encoding.OpenSSH,
        format=serialization.PublicFormat.OpenSSH
    ))

print('Unencrypted private key generated successfully')
" 2>&1
end

if test $status -ne 0
    echo "Failed to generate key."
    echo "Make sure the packages are installed: pip install mnemonic cryptography"
    exit 1
end

chmod 600 "$priv_key"

echo
if test $use_encryption -eq 1
    echo "✓ Created (private key is encrypted with passphrase):"
else
    echo "✓ Created (private key is NOT encrypted):"
end
echo "  Private key : $priv_key"
echo "  Public key  : $pub_key"
echo
