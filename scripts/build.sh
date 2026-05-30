#!/bin/bash
set -e

# Build script for gh-prompt-registry sidecar repository
# This script clones the official prompt-registry repository and builds CLI binaries

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OFFICIAL_REPO_URL=https://github.com/AmadeusITGroup/prompt-registry.git
OFFICIAL_REPO_DIR="$REPO_DIR/prompt-registry"

# Parse arguments
REF="${PROMPT_REGISTRY_REF:-}"
LOCAL=false
PLATFORM=""
LOCAL_REPO="${PROMPT_REGISTRY_REPO:-}"
REPO_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --ref)
      REF="$2"
      shift 2
      ;;
    --local)
      LOCAL=true
      shift
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --local-repo)
      LOCAL_REPO="$2"
      shift 2
      ;;
    --repo)
      REPO_OVERRIDE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Override official repo URL if --repo is provided
if [ -n "$REPO_OVERRIDE" ]; then
  OFFICIAL_REPO_URL="https://github.com/${REPO_OVERRIDE}.git"
fi

# Show configuration
echo "Configuration:"
echo "  Repository: ${LOCAL_REPO:-$OFFICIAL_REPO_URL}"
echo "  Ref: ${REF:-latest}"
echo "  Local build: $LOCAL"

# Use local repository if specified
if [ -n "$LOCAL_REPO" ]; then
  # Check if it's a local directory or a URL
  if [ -d "$LOCAL_REPO" ]; then
    OFFICIAL_REPO_DIR="$LOCAL_REPO"
    echo "Using local directory: $OFFICIAL_REPO_DIR"
    SKIP_GIT=true
  elif [[ "$LOCAL_REPO" == http://* ]] || [[ "$LOCAL_REPO" == https://* ]] || [[ "$LOCAL_REPO" == git@* ]]; then
    OFFICIAL_REPO_DIR="$REPO_DIR/prompt-registry"
    OFFICIAL_REPO_URL="$LOCAL_REPO"
    echo "Using remote repository: $OFFICIAL_REPO_URL"
  else
    OFFICIAL_REPO_DIR="$LOCAL_REPO"
    echo "Using local path: $OFFICIAL_REPO_DIR"
    SKIP_GIT=true
  fi
fi

# Clone official repository if not already present
if [ ! -d "$OFFICIAL_REPO_DIR" ]; then
  echo "Cloning official repository..."
  git clone "$OFFICIAL_REPO_URL" "$OFFICIAL_REPO_DIR"
else
  echo "Using existing repository..."
fi

cd "$OFFICIAL_REPO_DIR"

# Skip git operations if using local repository
if [ "$SKIP_GIT" = true ]; then
  echo "Skipping git checkout (using local repository state)"
else
  # Fetch latest tags and branches
  echo "Fetching latest tags and branches..."
  git fetch --tags --all

  # Checkout specific ref if provided
  if [ -n "$REF" ]; then
    echo "Checking out ref: $REF"
    git checkout "origin/$REF" -b "$REF"
  else
    echo "Checking out latest tag..."
    LATEST_TAG=$(git describe --tags --abbrev=0)
    git checkout "$LATEST_TAG"
  fi
fi

# Install dependencies from workspace root to link workspace packages
echo "Installing dependencies..."
cd "$OFFICIAL_REPO_DIR"
pnpm install

# Build CLI (build all workspace packages first to ensure dependencies are available)
echo "Building CLI..."
pnpm -r run build

# Build SEA binaries
echo "Building SEA binaries..."
cd "$OFFICIAL_REPO_DIR/packages/cli"
pnpm run build:sea:local

# Rename binaries to gh extension naming convention
echo "Renaming binaries to gh extension naming convention..."
cd "$OFFICIAL_REPO_DIR/packages/cli/dist"
for file in prompt-registry-*; do
  if [ -f "$file" ]; then
    # Rename to OS-ARCH[.exe] (extension name is inferred from repo name)
    new_name="${file#prompt-registry-}"
    mv "$file" "$new_name"
    echo "Renamed: $file -> $new_name"
  fi
done

cd "$REPO_DIR"

# Move binaries to appropriate location
if [ "$LOCAL" = true ]; then
  # Local mode: move to repository root
  echo "Moving binaries to repository root..."
  cd "$OFFICIAL_REPO_DIR/packages/cli/dist"
  for file in *; do
    if [ -f "$file" ]; then
      # Only move files that match the binary naming pattern (e.g., linux-x64, darwin-arm64)
      # Skip TypeScript compilation artifacts (.js, .d.ts, .map files)
      case "$file" in
        *.js|*.d.ts|*.map)
          echo "Skipping TypeScript artifact: $file"
          ;;
        *)
          mv "$file" "$REPO_DIR/"
          echo "Moved: $file"
          ;;
      esac
    fi
  done
else
  # CI mode: move to .tmp/dist for simple artifact upload
  echo "Moving binaries to .tmp/dist for CI artifact upload..."
  mkdir -p "$REPO_DIR/.tmp/dist"
  cd "$OFFICIAL_REPO_DIR/packages/cli/dist"
  for file in *; do
    if [ -f "$file" ]; then
      # Only move files that match the binary naming pattern (e.g., linux-x64, darwin-arm64)
      # Skip TypeScript compilation artifacts (.js, .d.ts, .map files)
      case "$file" in
        *.js|*.d.ts|*.map)
          echo "Skipping TypeScript artifact: $file"
          ;;
        *)
          mv "$file" "$REPO_DIR/.tmp/dist/"
          echo "Moved: $file"
          ;;
      esac
    fi
  done
fi

echo "Build complete!"
