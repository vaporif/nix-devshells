{ ... }: {
  perSystem = { pkgs, ... }:
    let
      rust = pkgs.fenix.stable;
      rustToolchain = pkgs.fenix.combine [
        (rust.withComponents [
          "cargo"
          "clippy"
          "rustc"
        ])
        pkgs.fenix.latest.rustfmt
        pkgs.fenix.latest.rust-analyzer
      ];
    in
    {
      devShells = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            cargo-make
            pkg-config
            taplo
            nixd
            rustToolchain
            vscode-extensions.vadimcn.vscode-lldb
          ];

          shellHook = ''
            export RUST_SRC_PATH="${rust.rust-src}/lib/rustlib/src/rust/library";
            export PATH=$HOME/.cargo/bin:$PATH
          '';
        };
      };
    };
}
