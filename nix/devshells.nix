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
            sccache
            vscode-extensions.vadimcn.vscode-lldb.adapter
          ];

          shellHook = ''
            export RUST_SRC_PATH="${rust.rust-src}/lib/rustlib/src/rust/library"
            export RUSTC_WRAPPER="${pkgs.sccache}/bin/sccache"
            export PATH=$HOME/.cargo/bin:$PATH
          '';
        };
      };
    };
}
