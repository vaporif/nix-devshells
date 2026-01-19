# List available recipes
default:
    @just --list

# Run all checks
check: lint-nix lint-toml lint-shell lint-actions check-typos

# Lint nix files
lint-nix:
    nix flake check
    alejandra --check .

# Format nix files
fmt-nix:
    alejandra .

# Lint TOML files
lint-toml:
    taplo check

# Format TOML files
fmt-toml:
    taplo fmt

# Lint shell scripts
lint-shell:
    shellcheck -S warning scripts/*.sh

# Lint GitHub Actions
lint-actions:
    actionlint

# Check for typos
check-typos:
    typos

# Format all
fmt: fmt-nix fmt-toml

# Set up git hooks
setup-hooks:
    git config core.hooksPath .githooks

# Build and push to cachix
cache:
    nix build .#devShells.aarch64-darwin.default && cachix push vaporif ./result
    nix build .#devShells.aarch64-darwin.rust && cachix push vaporif ./result
    nix build .#devShells.aarch64-darwin.go && cachix push vaporif ./result
    nix build .#devShells.aarch64-darwin.solana && cachix push vaporif ./result
