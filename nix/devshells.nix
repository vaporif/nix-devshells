{ ... }: {
  perSystem = { pkgs, ... }:
    let
      rust = pkgs.fenix.stable;
      rustToolchain = pkgs.fenix.combine [
        (rust.withComponents [
          "cargo"
          "clippy"
          "rustc"
          "rustfmt"
          "rust-analyzer"
        ])
      ];

      rustPackages = with pkgs; [
        cargo-make
        pkg-config
        taplo
        rustToolchain
        sccache
        vscode-extensions.vadimcn.vscode-lldb.adapter
        cargo-watch
        cargo-nextest
        cargo-audit
        bacon
        cargo-expand
        cargo-flamegraph
        cargo-outdated
        cargo-deny
        cargo-bloat
        cargo-udeps
        cargo-criterion
        cargo-mutants
      ];

      rustShellHook = ''
        export RUST_SRC_PATH="${rust.rust-src}/lib/rustlib/src/rust/library"
        export RUSTC_WRAPPER="${pkgs.sccache}/bin/sccache"
        export PATH=$HOME/.cargo/bin:$PATH
      '';

      goPackages = with pkgs; [
        go
        gopls
        gofumpt
        delve
        golangci-lint
        gotools
        air
        gotestsum
        buf
      ];

      goShellHook = ''
        export GOPATH=$HOME/go
        export PATH=$GOPATH/bin:$PATH
      '';
    in
    {
      devShells = {
        default = pkgs.mkShell {
          packages = rustPackages ++ goPackages ++ [ pkgs.nixd ];
          shellHook = rustShellHook + goShellHook;
        };

        rust = pkgs.mkShell {
          packages = rustPackages ++ [ pkgs.nixd ];
          shellHook = rustShellHook;
        };

        go = pkgs.mkShell {
          packages = goPackages ++ [ pkgs.nixd ];
          shellHook = goShellHook;
        };
      };
    };
}
