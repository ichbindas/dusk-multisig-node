#!/usr/bin/env bash

set -euo pipefail # euo: Exit settings
IFS=$'\n\t' # People are actually brave enough to use spaces in file names (wattba)

# ----------------------------------------------------------------------------
# Rust USB Environment Setup Script
# - Initializes Cargo & Rustup in USB directory
# - Installs Rust, wasm-pack
# - Clones and builds latest version of rusk-wallet
# ----------------------------------------------------------------------------

# Determine script directory (root of device)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CARGO_HOME="$SCRIPT_DIR/.cargo"
export RUSTUP_HOME="$SCRIPT_DIR/.rustup"
export PATH="$CARGO_HOME/bin:$PATH"

# Logging
info()    { printf "🔧 %s\n" "${*}"; }
success() { printf "✅ %s\n" "${*}"; }
error()   { printf "❌ %s\n" "${*}" >&2; exit 1; }

# Activate Environment
info "Rust USB environment activated."
info "CARGO_HOME: $CARGO_HOME"
info "RUSTUP_HOME: $RUSTUP_HOME"

# Install Rust via rustup (silent)
info "Installing Rust (default toolchain)..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path || error "Rust installation failed"
success "Rust installed."

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
if [ -x "$CARGO_HOME/bin/rusk-wallet" ]; then
    echo "✅ rusk-wallet already installed at $CARGO_HOME/bin/rusk-wallet"
else
    echo "🔍 Detecting latest rusk-wallet version..."
    LATEST_TAG=$(git ls-remote --tags https://github.com/dusk-network/rusk.git \
        | grep 'rusk-wallet-[0-9]' \
        | grep -v '\^{}' \
        | sed 's#.*refs/tags/##' \
        | sort -V \
        | tail -n1)

    if [ -z "$LATEST_TAG" ]; then
        echo "❌ No rusk-wallet tags found. Aborting."
        exit 1
    fi

    echo "📦 Latest wallet version tag detected: $LATEST_TAG"

    read -rp "Install $LATEST_TAG? [y/N]: " yn
    if [[ "$yn" =~ ^[Yy] ]]; then
        git clone --branch "$LATEST_TAG" --depth 1 https://github.com/dusk-network/rusk.git "$RUSK_DIR"

        echo "🔨 Installing rusk-wallet to USB-local bin..."
        cd "$WALLET_DIR" || exit 1
        cargo b --release

        # make sure the directory exists
        mkdir -p "$CARGO_HOME/bin"
        cp "$RUSK_DIR/target/release/rusk-wallet" "$CARGO_HOME/bin/" .

        echo "✅ rusk-wallet installed at $CARGO_HOME/bin/rusk-wallet" 
    fi
fi