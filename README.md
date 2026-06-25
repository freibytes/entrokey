# entrokey

**The real magic:**  
Your SSH private key is **not stored** — it is **derived** from a seed phrase that you can remember.

This means you can take your SSH keys with you **anywhere** in the world.  
Just remember your custom passphrase/seed, and you can regenerate the exact same private + public key on any machine.

The seed can be **any string you like** — a BIP39 mnemonic, Diceware words, or your own memorable (but strong) passphrase.

---

Deterministic Ed25519 SSH key generator from a BIP39 mnemonic or Diceware words.

Fish and Bash versions with identical behavior.

Generates proper OpenSSH-format private + public keys that can be used with `ssh`, `ssh-add`, GitHub, servers, etc.

## Features

- Use an existing BIP39/Diceware mnemonic **or any custom memorable phrase**
- Optional passphrase encryption (`-n` to skip)
- Configurable word count for generated mnemonics (`-w`)
- Non-interactive mode (`-f` for filename)
- Safely move keys to `~/.ssh/` with correct permissions (`-m`)
- Shows key fingerprint after generation
- Same key derivation in both Fish and Bash (perfect parity)

## How It Works

1. You provide (or generate) a seed phrase (can be any memorable text).
2. The script feeds the seed to Python's `mnemonic` library to produce a seed.
3. It then runs **HKDF-SHA256** (with info label `ed25519-key-from-bip39`) to derive exactly 32 bytes.
4. Those 32 bytes become the raw Ed25519 private key.
5. The key is written in OpenSSH format (optionally encrypted with a passphrase).
6. A matching `.pub` file is also written.

This means the **same seed will always produce the exact same SSH key** — no matter where you run it.

The generated keys are fully compatible with standard `ssh-keygen` output.

## Installation

### Requirements

- Python 3.7+
- `pip install mnemonic cryptography`
- Bash or Fish shell
- `ssh-keygen` (usually pre-installed) — used only for showing the fingerprint

### Linux

**Debian / Ubuntu / Pop!_OS / Linux Mint**

```bash
sudo apt update
sudo apt install python3-pip fish   # fish is optional
pip3 install --user mnemonic cryptography
```

**Arch Linux**

```bash
sudo pacman -S python-pip fish   # fish optional
pip install --user mnemonic cryptography
```

**Fedora**

```bash
sudo dnf install python3-pip fish
pip3 install --user mnemonic cryptography
```

Clone the repository:

```bash
git clone https://github.com/freibytes/entrokey.git
cd entrokey
```

### macOS

```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install python fish
pip3 install mnemonic cryptography
```

Clone the repository:

```bash
git clone https://github.com/freibytes/entrokey.git
cd entrokey
```

### Optional but Recommended: Install to ~/.local/bin

This makes `entrokey` available from anywhere without typing the full path.

```bash
# 1. Create the directory if it doesn't exist
mkdir -p ~/.local/bin

# 2. Copy the scripts and the wordlist
cp entrokey.fish entrokey.sh diceware.txt ~/.local/bin/

# 3. Make them executable
chmod +x ~/.local/bin/entrokey.fish ~/.local/bin/entrokey.sh

# 4. Add ~/.local/bin to your PATH (add this to your shell config if not already present)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc     # for bash
# or for fish:
# echo 'set -U fish_user_paths $HOME/.local/bin $fish_user_paths' >> ~/.config/fish/config.fish
```

After this you can simply run:

```bash
entrokey.fish -g -n -f mykey
# or
entrokey.sh -g -n -f mykey
```

> **Important**: When using `-g`, the script looks for `diceware.txt` in the current working directory.  
> If you installed to `~/.local/bin`, you can still run `-g` from that directory, or copy `diceware.txt` to wherever you run the command.

### Other ways to run

- Add the cloned folder temporarily: `export PATH="$PWD:$PATH"`
- Always use the full path

## Usage

### Basic Examples

Generate a key interactively (will ask for filename and optional passphrase):

```bash
./entrokey.fish "abandon ability able about above absent absorb abstract absurd abuse access accident"
```

or

```bash
./entrokey.sh "word1 word2 word3 ..."
```

### Using your own custom memorable seed (the best part)

You can use **any phrase you can remember**. This is the most powerful way to use the tool.

```bash
# Example with a fun, nerdy, memorable seed
./entrokey.fish -f my-everywhere-key -n "the answer is 42 dont panic and always bring a towel"

# Same seed on another machine will produce the identical key
./entrokey.sh -f my-everywhere-key -n "the answer is 42 dont panic and always bring a towel"
```

### Generate a secure mnemonic automatically

```bash
# Default 12 words + unencrypted
./entrokey.fish -g -n -f mykey

# 18 words
./entrokey.fish -g -n -w 18 -f server-key

# With encryption (will prompt for passphrase)
./entrokey.sh -g -f id_ed25519
```

### Non-interactive (great for scripts)

```bash
./entrokey.fish -f my-server-key -n "your mnemonic words here"
```

### Move keys directly to ~/.ssh with correct permissions

```bash
./entrokey.fish -g -n -f id_ed25519 -m
# → Keys will be moved to ~/.ssh/id_ed25519 and ~/.ssh/id_ed25519.pub with chmod 600
```

### All Available Options

```
  -h, --help                  Show this help message and exit
  -V, --version               Show version and exit
  -f, --filename NAME         Output filename base (skips interactive prompt)
  -n, --no-password           Generate unencrypted private key (no passphrase)
  -g, --generate-mnemonic     Generate a secure Diceware mnemonic
  -w, --words N               Number of diceware words when using -g (default: 12)
  -m, --move-keys             Move keys to $HOME/.ssh/ (if dir exists) after chmod 600
```

### Full Example Workflow

```bash
cd ~/Downloads/entrokey

# 1. Generate a key from your custom memorable seed and move it to ~/.ssh
./entrokey.fish -f github-key -m -n "the answer is 42 dont panic and always bring a towel"

# 2. Add to ssh-agent
ssh-add ~/.ssh/github-key

# 3. Copy public key
cat ~/.ssh/github-key.pub
```

## Security Notes

- **12 words** ≈ 155 bits of entropy (perfectly fine for SSH keys)
- **18 words** ≈ 230 bits
- **24 words** ≈ 310 bits
- Never use `-n` / `--no-password` for keys that protect important systems
- The derivation is deterministic — **write down and protect your seed phrase**
- The script never sends anything over the network

## Troubleshooting

- `ModuleNotFoundError: No module named 'mnemonic'`  
  → Run `pip3 install --user mnemonic cryptography`

- Using `-g` says diceware.txt is missing  
  → Make sure you are in the directory that contains `diceware.txt`

- Fingerprint not shown  
  → `ssh-keygen` is not in PATH (harmless, keys are still generated correctly)

## License

See [LICENSE](LICENSE) file.

---

**Tip**: Both `entrokey.fish` and `entrokey.sh` produce **bit-for-bit identical keys** when given the same seed. You can use whichever shell you prefer.