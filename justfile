# List available recipes
default:
    @just --list

# Run all checks
check: lint-nix lint-toml lint-shell lint-actions check-typos check-vulns

# Scan for vulnerabilities
check-vulns:
    #!/usr/bin/env bash
    set -euo pipefail
    system=$(nix eval --impure --raw --expr 'builtins.currentSystem')
    for shell in default rust go solidity solana; do
        echo "=== Scanning $shell shell ==="
        nix build ".#devShells.${system}.${shell}" -o "result-${shell}"
        vulnix "./result-${shell}" --whitelist vulnix-whitelist.toml
    done

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
    shellcheck -S style -o all scripts/*.sh

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
    #!/usr/bin/env bash
    set -euo pipefail
    system=$(nix eval --impure --raw --expr 'builtins.currentSystem')
    for shell in default rust go solidity solana; do
        nix build ".#devShells.${system}.${shell}" && cachix push vaporif ./result
    done
