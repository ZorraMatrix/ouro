#!/bin/sh
# install.sh - Install all required dependencies for current user (non-root, no sudo)
# Run with: sh install.sh or bash install.sh

set -e

# Detect shell profile to reload
DETECT_PROFILE=""
if [ -n "$BASH_VERSION" ]; then
    DETECT_PROFILE="$HOME/.bashrc"
elif [ -n "$ZSH_VERSION" ]; then
    DETECT_PROFILE="$HOME/.zshrc"
else
    DETECT_PROFILE="$HOME/.profile"
fi

# Reload profile function
reload_profile() {
    if [ -n "$DETECT_PROFILE" ] && [ -f "$DETECT_PROFILE" ]; then
        # shellcheck disable=SC1090
        . "$DETECT_PROFILE"
    fi
    # Re-export PATH to ensure new installations are found
    export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
}

echo "=== Checking and installing uv (Python package manager) ==="
if ! command -v uv >/dev/null 2>&1; then
    echo "uv not found, installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Source the uv environment
    . "$HOME/.local/bin/env"
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "uv is already installed: $(uv --version)"
fi

echo ""
echo "=== Setting up Python virtual environment with uv ==="
# Create venv in project directory using uv
if [ ! -d ".venv" ]; then
    uv venv
fi

echo ""
echo "=== Installing Python dependencies ==="
# Install dependencies into the venv using uv
uv pip install -r requirements.txt

echo ""
echo "=== Checking for Node.js ==="
if ! command -v node >/dev/null 2>&1; then
    echo "Node.js not found, installing via fnm (user-level)..."
    # Install fnm (Fast Node Manager) for user-level Node.js
    curl -fsSL https://fnm.vercel.app/install | sh

    # fnm is installed at ~/.local/share/fnm/bin
    export PATH="$HOME/.local/share/fnm/bin:$PATH"

    # Install and use Node.js 22
    "$HOME/.local/share/fnm/bin/fnm" install 22
    "$HOME/.local/share/fnm/bin/fnm" use 22

    # After fnm use, node is installed to ~/.local/share/fnm/node-versions/v22/*/installation/bin
    # We need to source the env to get the correct PATH
    # shellcheck disable=SC1090
    if [ -f "$HOME/.local/share/fnm/fnm-env" ]; then
        . "$HOME/.local/share/fnm/fnm-env"
    fi
    echo "Node.js installed: $(node --version)"
else
    echo "Node.js is already installed: $(node --version)"
fi

echo ""
echo "=== Checking for GitHub CLI ==="
if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI not found, installing for current user..."
    # Detect architecture
    GH_ARCH=$(uname -m)
    case "$GH_ARCH" in
        x86_64) GH_ARCH="amd64" ;;
        aarch64|arm64) GH_ARCH="arm64" ;;
        *) echo "Unsupported architecture: $GH_ARCH"; return 1 ;;
    esac
    GH_VERSION="2.67.0"
    GH_ARCHIVE="gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz"
    GH_TMPDIR=$(mktemp -d)
    GH_URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_ARCHIVE}"
    echo "Downloading $GH_URL..."
    curl -LsSf "$GH_URL" -o "${GH_TMPDIR}/${GH_ARCHIVE}"
    tar -xzf "${GH_TMPDIR}/${GH_ARCHIVE}" -C "$HOME/.local" --strip-components=1
    rm -rf "$GH_TMPDIR"
    export PATH="$HOME/.local/bin:$PATH"
    echo "GitHub CLI installed: $(gh --version)"
else
    echo "GitHub CLI is already installed: $(gh --version)"
fi

echo ""
echo "=== Setting up npm global packages directory ==="
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$PATH"

echo ""
echo "=== Installing Claude Code CLI ==="
if ! command -v claude >/dev/null 2>&1; then
    echo "Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
    reload_profile
    echo "Claude Code CLI installed: $(claude --version)"
else
    echo "Claude Code CLI is already installed: $(claude --version)"
fi

echo ""
echo "=== Installing Playwright Chromium browser ==="
if ! command -v playwright >/dev/null 2>&1; then
    echo "Playwright not found, checking..."
fi
# Install Chromium for Playwright using uv run
uv run playwright install chromium

echo ""
echo "=== Verifying installations ==="
echo "uv:         $(uv --version 2>/dev/null || echo 'not found')"
echo "Node.js:    $(node --version 2>/dev/null || echo 'not found')"
echo "npm:        $(npm --version 2>/dev/null || echo 'not found')"
echo "GitHub CLI: $(gh --version 2>/dev/null || echo 'not found')"
echo "Python:     $(uv run python --version 2>/dev/null || echo 'not found')"
echo "Playwright: $(uv run playwright --version 2>/dev/null || echo 'not found')"

echo ""
echo "=== Installation complete ==="
echo "To activate the virtual environment, run: source .venv/bin/activate"
echo "Or use 'uv run python' or 'uv run <command>' to execute with dependencies available."
