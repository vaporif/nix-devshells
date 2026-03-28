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

  # Wrap codelldb only on Darwin, auto-detect debugserver path
  codelldb =
    if pkgs.stdenv.isDarwin
    then
      pkgs.writeShellScriptBin "codelldb" ''
        if [[ -z "$LLDB_DEBUGSERVER_PATH" ]]; then
          if [[ -x "/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Versions/A/Resources/debugserver" ]]; then
            export LLDB_DEBUGSERVER_PATH="/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Versions/A/Resources/debugserver"
          elif [[ -x "/Library/Developer/CommandLineTools/Library/PrivateFrameworks/LLDB.framework/Versions/A/Resources/debugserver" ]]; then
            export LLDB_DEBUGSERVER_PATH="/Library/Developer/CommandLineTools/Library/PrivateFrameworks/LLDB.framework/Versions/A/Resources/debugserver"
          fi
        fi
        exec ${pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter}/bin/codelldb "$@"
      ''
    else pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter;
in {
  packages = with pkgs; [
    cargo-make
    pkg-config
    openssl
    openssl.dev
    taplo
    toolchain
    sccache
    codelldb
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
    cargo-depgraph
    cargo-modules
    rust-code-analysis
    tokio-console
    samply
    grpcurl
    clang
  ];

  env =
    {
      RUST_SRC_PATH = "${rust.rust-src}/lib/rustlib/src/rust/library";
      RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
      NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [pkgs.stdenv.cc.cc];
      LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
    }
    // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
      BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.glibc.dev}/include";
    }
    // pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
      BINDGEN_EXTRA_CLANG_ARGS = "--sysroot=${pkgs.apple-sdk_26.sdkroot}";
      CC = "${pkgs.stdenv.cc}/bin/cc";
      CXX = "${pkgs.stdenv.cc}/bin/c++";
    };

  shellHook = ''
    export PATH=$HOME/.cargo/bin:$PATH
  '';
}
