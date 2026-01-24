{pkgs}: let
  rust = pkgs.fenix.stable;
  toolchain = pkgs.fenix.combine [
    (rust.withComponents [
      "cargo"
      "clippy"
      "rustc"
      "rustfmt"
      "rust-analyzer"
      "rust-src"
    ])
  ];
in {
  packages = with pkgs; [
    cargo-make
    pkg-config
    openssl
    openssl.dev
    taplo
    toolchain
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
    cargo-machete
    cargo-pgo
    tokio-console
    samply
    grpcurl
  ];

  env = {
    RUST_SRC_PATH = "${rust.rust-src}/lib/rustlib/src/rust/library";
    RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
    NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [pkgs.stdenv.cc.cc];
  };

  shellHook = ''
    export PATH=$HOME/.cargo/bin:$PATH
  '';
}
