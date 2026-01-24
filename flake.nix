{
  description = "Nix development shells";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    flake-parts,
    fenix,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-darwin"];

      flake.templates = {
        rust = {
          path = ./templates/rust;
          description = "Rust workspace with devshell";
        };
        solana = {
          path = ./templates/solana;
          description = "Solana Anchor workspace with devshell";
        };
      };

      perSystem = {
        system,
        pkgs,
        ...
      }: let
        rust = import ./lib/rust.nix {inherit pkgs;};
        go = import ./lib/go.nix {inherit pkgs;};

        anchor = pkgs.callPackage ./pkgs/anchor.nix {};
        solana-agave = pkgs.callPackage ./pkgs/agave.nix {
          inherit (pkgs) fenix;
          inherit anchor;
        };

        commonPackages = with pkgs; [nixd vulnix alejandra just nix-output-monitor];
      in {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [fenix.overlays.default];
        };

        formatter = pkgs.alejandra;

        devShells = {
          default =
            pkgs.mkShell {
              packages = rust.packages ++ go.packages ++ commonPackages;
              shellHook = rust.shellHook + go.shellHook;
            }
            // rust.env;

          rust =
            pkgs.mkShell {
              packages = rust.packages ++ commonPackages;
              shellHook = rust.shellHook;
            }
            // rust.env;

          go = pkgs.mkShell {
            packages = go.packages ++ commonPackages;
            shellHook = go.shellHook;
          };

          solana = pkgs.mkShell ({
              packages =
                rust.packages
                ++ commonPackages
                ++ [
                  pkgs.gawk
                  solana-agave
                ]
                ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
                  pkgs.apple-sdk_15
                ];
              shellHook =
                rust.shellHook
                + ''
                  export PATH="${solana-agave}/bin:$PATH"
                  if [[ "$OSTYPE" == "darwin"* ]]; then
                    unset DEVELOPER_DIR_FOR_TARGET
                    unset NIX_APPLE_SDK_VERSION_FOR_TARGET
                    unset SDKROOT_FOR_TARGET
                  fi
                '';
            }
            // rust.env);
        };
      };
    };
}
