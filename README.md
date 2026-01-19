# nix-devshells

Reusable Nix development shells for Rust, Go, and Solana development.

## Quick Start

```bash
# Enter devshells
nix develop           # Rust + Go
nix develop .#rust    # Rust only
nix develop .#go      # Go only
nix develop .#solana  # Solana/Anchor

# Use as template
nix flake init -t github:vaporif/nix-devshells#rust
nix flake init -t github:vaporif/nix-devshells#solana
```

## Devshells

| Shell | Description |
|-------|-------------|
| `default` | Rust + Go combined |
| `rust` | Rust stable via fenix with cargo tools |
| `go` | Go with gopls, delve, golangci-lint |
| `solana` | Rust + Agave CLI + Anchor |

## Rust Tools

cargo-make, cargo-watch, cargo-nextest, cargo-audit, cargo-expand, cargo-flamegraph, cargo-outdated, cargo-deny, cargo-bloat, cargo-udeps, cargo-criterion, cargo-mutants, bacon, taplo, sccache

## Go Tools

gopls, gofumpt, delve, golangci-lint, gotools, air, gotestsum, buf

## Solana Development

Use `anchor-nix` wrapper instead of `anchor` directly:

```bash
anchor-nix build       # Build + generate IDL
anchor-nix test        # Build + run tests
anchor-nix unit-test   # Build + cargo test
anchor-nix deploy      # Deploy programs
```

## Development

```bash
just check        # Run all linters
just fmt          # Format nix + toml
just cache        # Build + push to cachix
just setup-hooks  # Enable git hooks
```

## Structure

```
flake.nix          # Devshell definitions
lib/
  rust.nix         # Rust toolchain config
  go.nix           # Go toolchain config
pkgs/
  agave.nix        # Solana Agave CLI
  anchor.nix       # Anchor CLI
scripts/
  anchor-nix.sh    # Anchor wrapper script
templates/
  rust/            # Rust workspace template
  solana/          # Anchor workspace template
```

## License

MIT
