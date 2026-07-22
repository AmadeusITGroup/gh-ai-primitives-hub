.PHONY: help build build-local clean release

help:
	@echo "Available targets:"
	@echo "  make build-local  - Build for current platform with CI parity (Node 24 LTS)"
	@echo "  make build        - Build for all platforms (handled by CI matrix)"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make release      - Create release with proper naming"
	@echo ""
	@echo "Environment variables:"
	@echo "  AI_PRIMITIVES_HUB_REPO - Repository to clone (default: AmadeusITGroup/ai-primitives-hub)"
	@echo "  AI_PRIMITIVES_HUB_REF  - Git ref (tag or branch) to checkout"
	@echo "                         (default: main)"
	@echo "  (Legacy aliases still supported: PROMPT_REGISTRY_REPO / PROMPT_REGISTRY_REF)"
	@echo "  CLEAN_AFTER_BUILD     - Clean up cloned ai-primitives-hub directory after build"
	@echo "                         (default: false, set to 'true' to enable)"
	@echo ""
	@echo "CI Parity Features:"
	@echo "  - Automatically switches to Node 24 LTS (matching CI)"
	@echo "  - Saves and restores original Node version via nvm"
	@echo "  - Always starts with clean slate (removes ai-primitives-hub dir)"
	@echo "  - Uses corepack to install exact pnpm version from packageManager field"
	@echo ""
	@echo "Examples:"
	@echo "  make build-local"
	@echo "  AI_PRIMITIVES_HUB_REPO=AmadeusITGroup/ai-primitives-hub AI_PRIMITIVES_HUB_REF=main make build-local"
	@echo "  CLEAN_AFTER_BUILD=true make build-local"

build-local:
	@echo "Building with CI parity (Node 24 LTS)..."
	./scripts/build-with-ci-env.sh --local
	@echo "Local install artifact ready: gh-ai-primitives-hub"

build:
	@echo "Building for all platforms..."
	./scripts/build.sh

clean:
	@echo "Cleaning build artifacts..."
	rm -f linux-* darwin-* windows-* *.sha256
	rm -rf ai-primitives-hub prompt-registry

release:
	@echo "Creating release..."
	./scripts/build.sh
	@echo "Release artifacts ready in current directory"
	ls -lh linux-* darwin-* windows-* 2>/dev/null || true
