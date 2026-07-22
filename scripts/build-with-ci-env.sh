#!/bin/bash
set -e

# Build script wrapper that ensures CI parity
# This script switches to Node 24 LTS (matching CI) before building,
# then restores the original Node version after completion.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

# Clean slate: remove existing cloned repository directory before build
echo "Cleaning slate: removing existing ai-primitives-hub directory..."
rm -rf "$REPO_DIR/ai-primitives-hub"

# Unique temp file using PID to avoid race conditions
TEMP_FILE="/tmp/gh-ai-primitives-hub-node-version.$$"

# Disable corepack download prompt for non-interactive CI parity
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0

# Cleanup function to restore environment on exit/interrupt
cleanup() {
  # Clean up cloned repository directory if requested
  if [ "${CLEAN_AFTER_BUILD:-false}" = "true" ]; then
    echo "Cleaning up ai-primitives-hub directory..."
    rm -rf "$REPO_DIR/ai-primitives-hub"
  fi

  # Restore Node version
  if [ -f "$TEMP_FILE" ] && [ -n "$NVM_DIR" ] && [ -f "$NVM_DIR/nvm.sh" ]; then
    source "$NVM_DIR/nvm.sh"
    SAVED_VERSION=$(cat "$TEMP_FILE")
    echo "Restoring Node version to $SAVED_VERSION"
    nvm use "$SAVED_VERSION" 2>/dev/null || echo "Could not restore Node version $SAVED_VERSION"
    rm -f "$TEMP_FILE"
  fi
}
trap cleanup EXIT INT TERM

# Save current nvm version (if nvm is active)
if [ -n "$NVM_DIR" ] && [ -f "$NVM_DIR/nvm.sh" ]; then
  source "$NVM_DIR/nvm.sh"
  CURRENT_NODE_VERSION=$(node --version)
  echo "$CURRENT_NODE_VERSION" > "$TEMP_FILE"
  echo "Saved current Node version: $CURRENT_NODE_VERSION"
fi

# Switch to Node 24 LTS
if command -v nvm &> /dev/null || [ -n "$NVM_DIR" ]; then
  [ -n "$NVM_DIR" ] && source "$NVM_DIR/nvm.sh" 2>/dev/null || true
  if ! nvm use 24 2>/dev/null; then
    echo "Node 24 not found, installing..."
    nvm install 24
    nvm use 24
  fi
  echo "Using Node $(node --version)"
else
  echo "ERROR: nvm not found. Please install nvm to ensure CI parity."
  echo "Visit: https://github.com/nvm-sh/nvm"
  exit 1
fi

# Install pnpm globally (bypasses corepack download prompt)
# This matches what corepack enable does internally without the interactive prompt
if ! command -v pnpm &> /dev/null; then
  echo "Installing pnpm globally..."
  npm install -g pnpm@11.5.0
else
  echo "pnpm already available at $(pnpm --version)"
fi

# Validate pnpm version matches packageManager field (if in repository dir)
if [ -f "package.json" ]; then
  EXPECTED_PNPM=$(grep -o '"packageManager": "pnpm@[^"]*"' package.json 2>/dev/null | cut -d@ -f2 || echo "")
  if [ -n "$EXPECTED_PNPM" ]; then
    ACTUAL_PNPM=$(pnpm --version)
    echo "Expected pnpm: $EXPECTED_PNPM, Actual: $ACTUAL_PNPM"
    if [ "$EXPECTED_PNPM" != "$ACTUAL_PNPM" ]; then
      echo "WARNING: pnpm version mismatch. corepack should handle this."
    fi
  fi
fi

# Call the original build script with all arguments
# Set default remote repo and branch for CI parity testing
DEFAULT_REPO="AmadeusITGroup/ai-primitives-hub"
AI_PRIMITIVES_HUB_REPO="${AI_PRIMITIVES_HUB_REPO:-${PROMPT_REGISTRY_REPO:-$DEFAULT_REPO}}"
AI_PRIMITIVES_HUB_REF="${AI_PRIMITIVES_HUB_REF:-${PROMPT_REGISTRY_REF:-main}}"

# Convert owner/repo format to full GitHub URL if needed
# Skip conversion for absolute paths
if [[ "$AI_PRIMITIVES_HUB_REPO" == */* ]] && [[ ! "$AI_PRIMITIVES_HUB_REPO" == /* ]] && [[ ! "$AI_PRIMITIVES_HUB_REPO" == http://* ]] && [[ ! "$AI_PRIMITIVES_HUB_REPO" == https://* ]] && [[ ! "$AI_PRIMITIVES_HUB_REPO" == git@* ]]; then
  AI_PRIMITIVES_HUB_REPO="https://github.com/$AI_PRIMITIVES_HUB_REPO"
fi

PROMPT_REGISTRY_REPO="$AI_PRIMITIVES_HUB_REPO"
PROMPT_REGISTRY_REF="$AI_PRIMITIVES_HUB_REF"

export AI_PRIMITIVES_HUB_REPO
export AI_PRIMITIVES_HUB_REF
export PROMPT_REGISTRY_REPO
export PROMPT_REGISTRY_REF
echo "Using repository: $AI_PRIMITIVES_HUB_REPO"
echo "Using branch/ref: $AI_PRIMITIVES_HUB_REF"

./scripts/build.sh "$@"
