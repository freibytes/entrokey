#!/usr/bin/env fish

set -g VERSION "0.2.0"

function show_version
    echo "entrokey $VERSION"
end

function show_help
    echo "entrokey.fish - Generate deterministic ed25519 SSH keys from BIP39 or Diceware"
    echo ""
    echo "Usage: entrokey.fish [OPTIONS] [MNEMONIC WORDS...]"
    echo ""
    echo "Options:"
    echo "  -h, --help                  Show this help message and exit"
    echo "  -V, --version               Show version and exit"
    echo "  -f, --filename NAME         Output filename base (skips interactive prompt)"
    echo "  -n, --no-password           Generate unencrypted private key (no passphrase)"
    echo "  -g, --generate-mnemonic     Generate a secure Diceware mnemonic"
    echo "  -w, --words N               Number of diceware words when using -g (default: 12)"
    echo "  -m, --move-keys             Move keys to \$HOME/.ssh/ (if dir exists) after chmod 600"
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
    echo "  entrokey.fish -g -n -w 18 -f mykey"
    echo "  entrokey.fish -f id_ed25519 \"word1 word2 ...\""
    echo "  entrokey.fish -g --no-password"
    echo "  entrokey.fish -h"
end

argparse \
    'h/help' \
    'V/version' \
    'f/filename=' \
    'n/no-password' \
    'g/generate-mnemonic' \
    'w/words=' \
    'm/move-keys' \
    -- $argv
or return 1

if set -q _flag_help
    show_help
    exit 0
end

if set -q _flag_version
    show_version
    exit 0
end

# Determine word count
set -l word_count 12
if set -q _flag_words
    set word_count $_flag_words
    if not string match -qr '^[0-9]+$' -- $word_count
        or test $word_count -lt 6
        or test $word_count -gt 24
        echo "Error: --words must be a number between 6 and 24" >&2
        exit 1
    end
end

# Handle mnemonic generation or input
if set -q _flag_generate_mnemonic
    if not test -f diceware.txt
        echo "Error: diceware.txt not found in current directory." >&2
        echo "Please ensure the wordlist is present." >&2
        exit 1
    end

    set mnemonic (shuf -n $word_count diceware.txt | string join ' ')
    echo "Generated $word_count-word mnemonic (WRITE THIS DOWN!):"
    echo "  $mnemonic"
    echo ""
else
    if test (count $argv) -eq 0
        echo "Error: No mnemonic provided. Use -g/--generate-mnemonic or provide words." >&2
        exit 1
    end
    set mnemonic $argv
end

set -l use_encryption 1
if set -q _flag_no_password
    set use_encryption 0
end

# Filename handling (non-interactive if -f given)
if set -q _flag_filename
    set basename $_flag_filename
else
    read -P "Filename without extension (e.g. id_ed25519): " basename
end

if test -z "$basename"
    echo "No filename provided. Aborting." >&2
    exit 1
end

if test $use_encryption -eq 1
    read -s -P "Enter passphrase for private key: " passphrase
    echo
    read -s -P "Confirm passphrase: " passphrase2
    echo

    if test "$passphrase" != "$passphrase2"
        echo "Passphrases do not match. Aborting." >&2
        exit 1
    end

    if test -z "$passphrase"
        echo "No passphrase provided. Aborting." >&2
        exit 1
    end
else
    set passphrase ""
end

set priv_key "$basename"
set pub_key  "$basename.pub"

# Generate the key
if test $use_encryption -eq 1
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
    echo "Failed to generate key." >&2
    echo "Make sure the packages are installed: pip install mnemonic cryptography" >&2
    exit 1
end

chmod 600 "$priv_key"
chmod 644 "$pub_key" 2>/dev/null || true

set -l moved 0
if set -q _flag_move_keys
    if test -d "$HOME/.ssh"
        mv "$priv_key" "$pub_key" "$HOME/.ssh/"
        set priv_key "$HOME/.ssh/$basename"
        set pub_key "$HOME/.ssh/$basename.pub"
        chmod 600 "$priv_key"
        set moved 1
    else
        echo "Note: \$HOME/.ssh does not exist — keys left in current directory" >&2
    end
end

echo
echo "✓ Key generated successfully"
echo "  Private key : $priv_key"
echo "  Public key  : $pub_key"

# Show fingerprint if possible
if command -v ssh-keygen >/dev/null 2>&1
    set fp (ssh-keygen -lf "$pub_key" 2>/dev/null | awk '{print $2}')
    if test -n "$fp"
        echo "  Fingerprint : $fp"
    end
end

echo
if test $use_encryption -eq 1
    echo "  (private key is encrypted with a passphrase)"
else
    echo "  (private key is NOT encrypted)"
end
if test $moved -eq 1
    echo "  (keys moved to \$HOME/.ssh)"
end
echo
