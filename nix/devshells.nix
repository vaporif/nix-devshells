{ ... }: {
  perSystem = { pkgs, ... }:
    let
      rust = pkgs.fenix.stable;
      rustToolchain = pkgs.fenix.combine [
        (rust.withComponents [
          "cargo"
          "clippy"
          "rustc"
          "rust-analyzer"
        ])
        pkgs.fenix.latest.rustfmt
      ];
    in
    {
      devShells = {
        default = pkgs.mkShell {
          packages = with pkgs; [ cargo-make pkg-config nixd rustToolchain ];

          shellHook = ''
            export RUST_SRC_PATH="${rust.rust-src}/lib/rustlib/src/rust/library";
            export PATH=$HOME/.cargo/bin:$PATH
          '';
        };
      };
    };
}
