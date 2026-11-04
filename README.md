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
1. Publish a prerelease in **this repository** with a tag that exists in the upstream AI Primitives Hub repository, or manually dispatch the workflow with `create_release` and `tag_name`
2. The workflow resolves the upstream source once and pins all builds to that commit
3. Binaries are built for all platforms using SEA (Single Executable Application)
4. Binaries are renamed to gh extension naming convention
5. Checksums are generated
6. Assets and upstream release notes are uploaded to the sidecar release; prereleases are then promoted to stable releases, while manually created releases remain drafts

Release notes use the matching upstream tag's published release body when available.
If the source has no release notes, the workflow generates a commit changelog from
the preceding reachable upstream tag (or the full history for a first release).
Every release includes a link to the exact upstream source commit. Existing sidecar
release bodies are replaced, so GitHub-generated notes from this proxy repository
are not retained.

Manual runs can select a different source using `repo` and `branch` (a branch, tag,
or commit); `tag_name` names only the sidecar release. Without `branch`, the latest
reachable upstream tag is used. A release event in the upstream repository does
not itself trigger this repository's workflow.

To run release-note regression tests without building binaries:

```bash
python3 -m unittest discover -s tests -v
```

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
