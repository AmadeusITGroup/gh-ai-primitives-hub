# gh-ai-primitives-hub

GitHub CLI extension for the AI Primitives Hub CLI tool.

## Purpose

This is a **sidecar repository** that builds and distributes the AI Primitives Hub CLI as a GitHub CLI extension. The main AI Primitives Hub repository is at [AmadeusITGroup/ai-primitives-hub](https://github.com/AmadeusITGroup/ai-primitives-hub).

## Installation

```bash
gh extension install AmadeusITGroup/gh-ai-primitives-hub
```

## Usage

```bash
# Show help
gh ai-primitives-hub --help

# Validate collections
gh ai-primitives-hub collection validate

# Build bundles
gh ai-primitives-hub bundle build

# Install bundles
gh ai-primitives-hub install
```

## Development

### Local Build

```bash
# Build for current platform only
make build-local

# Build for all platforms (handled by CI matrix)
make build

# Clean build artifacts
make clean
```

### Manual Build

```bash
# Build from specific ref (tag or branch)
./scripts/build.sh --ref v1.0.4

# Build from specific branch
./scripts/build.sh --ref main

# Build for current platform
./scripts/build.sh --local

# Build using local repository (with environment variable)
AI_PRIMITIVES_HUB_REPO=/path/to/ai-primitives-hub ./scripts/build.sh --local

# Build using local repository with specific ref (with environment variables)
AI_PRIMITIVES_HUB_REPO=/path/to/ai-primitives-hub AI_PRIMITIVES_HUB_REF=v1.0.4 ./scripts/build.sh --local

# Build using remote repository with specific branch (with environment variables)
AI_PRIMITIVES_HUB_REPO=https://github.com/user/ai-primitives-hub.git AI_PRIMITIVES_HUB_REF=main ./scripts/build.sh --local

# Build using local repository (with command-line flag)
./scripts/build.sh --local --local-repo /path/to/ai-primitives-hub
```

**Environment Variables:**
- `AI_PRIMITIVES_HUB_REPO` - Path or URL to ai-primitives-hub repository (overrides cloning from GitHub)
- `AI_PRIMITIVES_HUB_REF` - Git ref (tag or branch) to checkout (defaults to latest tag if not specified)
- Legacy aliases remain supported: `PROMPT_REGISTRY_REPO` and `PROMPT_REGISTRY_REF`

**Note:** The SEA (Single Executable Application) build process is now implemented in the new monorepo structure. The build produces standalone binaries for all platforms.

### Testing GitHub CLI Extension Locally

```bash
# Build locally
make build-local

# Install as local extension (requires SEA binaries)
gh extension install ./gh-ai-primitives-hub-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)

# Test the extension
gh ai-primitives-hub --help

# Uninstall when done
gh extension remove gh-ai-primitives-hub
```

## Binary Naming Convention

GitHub CLI extensions require specific naming for binary assets:
```
OS-ARCH[.exe]

Examples:
linux-amd64
linux-arm64
darwin-amd64
darwin-arm64
windows-amd64.exe
windows-arm64.exe
```

The extension name is inferred from the repository name (`gh-ai-primitives-hub`), not part of the binary filename.

## Release Process

Releases are automated via GitHub Actions:
1. Create a release in the main AI Primitives Hub repository
2. This repository's workflow triggers on the release
3. Binaries are built for all platforms using SEA (Single Executable Application)
4. Binaries are renamed to gh extension naming convention
5. Checksums are generated
6. Assets are uploaded to the release

## Repository Structure

```
gh-ai-primitives-hub/
├── .github/
│   └── workflows/
│       └── release.yml          # CI/CD for building and releasing
├── scripts/
│   └── build.sh                  # Build script for all platforms
├── Makefile                      # Build targets for local development
└── README.md                     # This file
```

## License

MIT License - see the main AI Primitives Hub repository for details.
