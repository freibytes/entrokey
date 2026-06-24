#!/usr/bin/env fish

if test (count $argv) -eq 0
    echo "Usage: sshdkey.fish \"your mnemonic words here\""
    exit 1
end

set mnemonic $argv

read -P "Filename without extension (e.g. id_ed25519): " basename

if test -z "$basename"
    echo "No filename provided. Aborting."
    exit 1
end

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

set priv_key "$basename"
set pub_key  "$basename.pub"

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

if test $status -ne 0
    echo "Failed to generate key."
    echo "Make sure the packages are installed: pip install mnemonic cryptography"
    exit 1
end

chmod 600 "$priv_key"

echo
echo "✓ Created (private key is encrypted with passphrase):"
echo "  Private key : $priv_key"
echo "  Public key  : $pub_key"
echo
