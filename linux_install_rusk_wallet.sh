#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------------------------
# Rust USB Environment Setup Script (Ubuntu-safe, no symlinks)
# - Installs Rust locally
# - Clones and builds latest version of rusk-wallet  locally
# - Copies the rusk-wallet to the USB drive
# ----------------------------------------------------------------------------

# Determine script directory (USB root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.cargo/bin:$PATH"

# Logging
info()    { printf "🔧 %s\n" "${*}"; }
success() { printf "✅ %s\n" "${*}"; }
error()   { printf "❌ %s\n" "${*}" >&2; exit 1; }

# Show environment
info "Rust environment setup started."
info "Script directory: $SCRIPT_DIR"

# Install Rust if missing
if ! command -v rustc &>/dev/null; then
    info "Rust not found. Installing..."
    if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
        error "Rust installation failed."
    fi
    success "Rust installed."
else
    success "Rust already installed: $(rustc --version)"
fi

# Display versions
info "cargo: $(command -v cargo)"
info "rustc: $(command -v rustc)"
RUST_VERSION=$(rustc --version)
success "Rust version: $RUST_VERSION"

# Install wasm-pack if missing
if ! command -v wasm-pack &>/dev/null; then
    info "Installing wasm-pack..."
    cargo install wasm-pack || error "wasm-pack installation failed"
    success "wasm-pack installed."
else
    success "wasm-pack already present: $(command -v wasm-pack)"
fi

# Clone & build rusk-wallet
RUSK_DIR="$SCRIPT_DIR/rusk"
WALLET_DIR="$RUSK_DIR/rusk-wallet"
if command -v rusk-wallet &>/dev/null; then
    echo "✅ rusk-wallet already installed and in PATH"
else
    echo "🔍 Detecting latest rusk-wallet version..."
    LATEST_TAG=$(git ls-remote --tags https://github.com/dusk-network/rusk.git \
        | grep 'rusk-wallet-[0-9]' \
        | grep -v '\^{}' \
        | sed 's#.*refs/tags/##' \
        | sort -V \
        | tail -n1)

    if [ -z "$LATEST_TAG" ]; then
        error "No rusk-wallet tags found. Aborting."
    fi

    echo "📦 Latest wallet version tag detected: $LATEST_TAG"

    read -rp "Install $LATEST_TAG? [y/N]: " yn
    if [[ "$yn" =~ ^[Yy] ]]; then
        git clone --branch "$LATEST_TAG" --depth 1 https://github.com/dusk-network/rusk.git "$RUSK_DIR"

        echo "🔨 Building rusk-wallet..."
        cd "$WALLET_DIR" || error "Wallet dir missing"
        cargo build --release

        echo "📥 Copying binary to USB root..."
        cp "$RUSK_DIR/target/release/rusk-wallet" "$SCRIPT_DIR/"

        echo "✅ rusk-wallet installed at: $SCRIPT_DIR/rusk-wallet"
    fi
fi