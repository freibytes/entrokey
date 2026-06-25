# Makefile for entrokey
#
# make install          # user install to ~/.local (default)
# PREFIX=/usr/local make install
# make uninstall
#
# After install the scripts find diceware.txt automatically (relative to themselves).

PREFIX ?= $(HOME)/.local
BIN_DIR := $(PREFIX)/bin

.PHONY: install uninstall help

install:
	@echo "Installing entrokey to $(BIN_DIR) ..."
	@mkdir -p $(BIN_DIR)
	@cp -f entrokey.sh entrokey.fish diceware.txt $(BIN_DIR)/
	@chmod +x $(BIN_DIR)/entrokey.sh $(BIN_DIR)/entrokey.fish
	@echo "Installed:"
	@ls -l $(BIN_DIR)/entrokey.sh $(BIN_DIR)/entrokey.fish $(BIN_DIR)/diceware.txt
	@echo
	@echo "Add $(BIN_DIR) to PATH (see install.sh or README)."
	@echo "Test with: $(BIN_DIR)/entrokey.sh --help  or  $(BIN_DIR)/entrokey.fish -g -n -f /tmp/test"

uninstall:
	@echo "Removing entrokey from $(BIN_DIR) ..."
	@rm -f $(BIN_DIR)/entrokey.sh $(BIN_DIR)/entrokey.fish $(BIN_DIR)/diceware.txt
	@echo "Uninstalled."

help:
	@echo "Targets:"
	@echo "  make install   [PREFIX=...]"
	@echo "  make uninstall [PREFIX=...]"
	@echo
	@echo "Default PREFIX=$(HOME)/.local"
	@echo "Example system-wide: sudo make install PREFIX=/usr/local"
