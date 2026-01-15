{...}: {
  perSystem = {pkgs, ...}: let
    rust = pkgs.fenix.stable;
    rustToolchain = pkgs.fenix.combine [
      (rust.withComponents [
        "cargo"
        "clippy"
        "rustc"
        "rustfmt"
        "rust-analyzer"
        "rust-src"
      ])
    ];

    # Solana packages
    anchor = pkgs.callPackage ../pkgs/solana/anchor.nix {};
    solana-agave = pkgs.callPackage ../pkgs/solana/agave.nix {
      inherit (pkgs) fenix;
      inherit anchor;
    };

    rustPackages = with pkgs; [
      cargo-make
      pkg-config
      openssl
      openssl.dev
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

    rustEnv = {
      RUST_SRC_PATH = "${rust.rust-src}/lib/rustlib/src/rust/library";
      RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
      NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [pkgs.stdenv.cc.cc];
    };

    rustShellHook = ''
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
  in {
    devShells = {
      default =
        pkgs.mkShell {
          packages = rustPackages ++ goPackages ++ [pkgs.nixd];
          shellHook = rustShellHook + goShellHook;
        }
        // rustEnv;

      rust =
        pkgs.mkShell {
          packages = rustPackages ++ [pkgs.nixd];
          shellHook = rustShellHook;
        }
        // rustEnv;

      go = pkgs.mkShell {
        packages = goPackages ++ [pkgs.nixd];
        shellHook = goShellHook;
      };

      solana = pkgs.mkShell ({
          packages =
            rustPackages
            ++ [
              pkgs.nixd
              pkgs.gawk
              pkgs.just
              solana-agave
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.apple-sdk_15
            ];
          shellHook =
            rustShellHook
            + ''
              export PATH="${solana-agave}/bin:$PATH"

              # Darwin SDK workaround
              if [[ "$OSTYPE" == "darwin"* ]]; then
                unset DEVELOPER_DIR_FOR_TARGET
                unset NIX_APPLE_SDK_VERSION_FOR_TARGET
                unset SDKROOT_FOR_TARGET
              fi
            '';
        }
        // rustEnv);
    };
  };
}
