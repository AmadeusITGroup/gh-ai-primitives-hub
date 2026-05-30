.PHONY: help build build-local clean release

help:
	@echo "Available targets:"
	@echo "  make build-local  - Build for current platform with CI parity (Node 24 LTS)"
	@echo "  make build        - Build for all platforms (handled by CI matrix)"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make release      - Create release with proper naming"
	@echo ""
	@echo "Environment variables:"
	@echo "  PROMPT_REGISTRY_REPO  - Repository to clone (default: wherka-ama/prompt-registry)"
	@echo "  PROMPT_REGISTRY_REF   - Git ref (tag or branch) to checkout"
	@echo "                         (default: feature/library-centric-flows-with-cli_phase-3)"
	@echo "  CLEAN_AFTER_BUILD     - Clean up prompt-registry directory after build"
	@echo "                         (default: false, set to 'true' to enable)"
	@echo ""
	@echo "CI Parity Features:"
	@echo "  - Automatically switches to Node 24 LTS (matching CI)"
	@echo "  - Saves and restores original Node version via nvm"
	@echo "  - Always starts with clean slate (removes prompt-registry dir)"
	@echo "  - Uses corepack to install exact pnpm version from packageManager field"
	@echo ""
	@echo "Examples:"
	@echo "  make build-local"
	@echo "  PROMPT_REGISTRY_REPO=AmadeusITGroup/prompt-registry PROMPT_REGISTRY_REF=main make build-local"
	@echo "  CLEAN_AFTER_BUILD=true make build-local"

build-local:
	@echo "Building with CI parity (Node 24 LTS)..."
	./scripts/build-with-ci-env.sh --local
	@echo "Local install artifact ready: gh-prompt-registry"

build:
	@echo "Building for all platforms..."
	./scripts/build.sh

clean:
	@echo "Cleaning build artifacts..."
	rm -f linux-* darwin-* windows-* *.sha256
	rm -rf prompt-registry

release:
	@echo "Creating release..."
	./scripts/build.sh
	@echo "Release artifacts ready in current directory"
	ls -lh linux-* darwin-* windows-* 2>/dev/null || true
