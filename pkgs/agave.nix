{
  lib,
  stdenv,
  fetchFromGitHub,
  symlinkJoin,
  fetchurl,
  rustPlatform,
  pkg-config,
  openssl,
  zlib,
  protobuf,
  perl,
  hidapi,
  udev,
  llvmPackages,
  fenix,
  writeShellApplication,
  makeWrapper,
  anchor,
  jq,
  solanaPkgs ? [
    "cargo-build-sbf"
    "cargo-test-sbf"
    "solana"
    "solana-faucet"
    "solana-genesis"
    "solana-gossip"
    "solana-keygen"
    "solana-test-validator"
    "agave-install"
    "agave-validator"
  ],
}: let
  inherit (lib) optionals;
  inherit (stdenv) hostPlatform isLinux;

  versions = {
    agave = "3.1.6";
    platformTools = "v1.52";
  };

  # Pinned nightly toolchain for IDL generation
  nightly = fenix.toolchainOf {
    channel = "nightly";
    date = "2025-01-01";
    sha256 = "sha256-0Hcko7V5MUtH1RqrOyKQLg0ITjJjtyRPl2P+cJ1p1cY=";
  };
  rustNightly = nightly.withComponents [
    "cargo"
    "rustc"
    "rust-src"
  ];

  platformConfig = {
    x86_64-darwin = {
      archive = "platform-tools-osx-x86_64.tar.bz2";
      sha256 = "sha256-HdTysfe1MWwvGJjzfHXtSV7aoIMzM0kVP+lV5Wg3kdE=";
    };
    aarch64-darwin = {
      archive = "platform-tools-osx-aarch64.tar.bz2";
      sha256 = "sha256-Fyffsx6DPOd30B5wy0s869JrN2vwnYBSfwJFfUz2/QA=";
    };
    x86_64-linux = {
      archive = "platform-tools-linux-x86_64.tar.bz2";
      sha256 = "sha256-izhh6T2vCF7BK2XE+sN02b7EWHo94Whx2msIqwwdkH4=";
    };
    aarch64-linux = {
      archive = "platform-tools-linux-aarch64.tar.bz2";
      sha256 = "sha256-sfhbLsR+9tUPZoPjUUv0apUmlQMVUXjN+0i9aUszH5g=";
    };
  };

  currentPlatform =
    platformConfig.${hostPlatform.system}
      or (throw "Unsupported platform: ${hostPlatform.system}");

  platformToolsArchive = fetchurl {
    url = "https://github.com/anza-xyz/platform-tools/releases/download/${versions.platformTools}/${currentPlatform.archive}";
    inherit (currentPlatform) sha256;
  };

  # Download SBF SDK archive from Agave releases
  sbfSdkArchive = fetchurl {
    url = "https://github.com/anza-xyz/agave/releases/download/v${versions.agave}/sbf-sdk.tar.bz2";
    sha256 = "sha256-4iV6NhfisZuLlwwhIi4OIbxj8Nzx+EFcG5cmK36fFAc=";
  };

  # SBF SDK derivation
  sbfSdk = stdenv.mkDerivation {
    pname = "sbf-sdk";
    version = versions.agave;

    src = sbfSdkArchive;

    unpackPhase = ''
      mkdir -p $out
      tar -xjf $src -C $out

      # Create symlink to platform tools
      mkdir -p $out/dependencies
      ln -s ${platformTools} $out/dependencies/platform-tools

      # Extract scripts from agave/platform-tools-sdk/sbf/scripts/
      if [ -d "${agave.src}/platform-tools-sdk/sbf/scripts" ]; then
        mkdir -p $out/scripts
        cp -r ${agave.src}/platform-tools-sdk/sbf/scripts/* $out/scripts/
        chmod +x $out/scripts/*.sh 2>/dev/null || true
      fi

      # Create env.sh at the root to fix strip.sh script path
      if [ -f "$out/sbf-sdk/env.sh" ]; then
        ln -s $out/sbf-sdk/env.sh $out/env.sh
      fi
    '';

    meta = with lib; {
      description = "Solana BPF SDK for building on-chain programs";
      homepage = "https://github.com/anza-xyz/agave";
      license = licenses.asl20;
      platforms = platforms.unix;
    };
  };

  platformTools = stdenv.mkDerivation {
    pname = "platformTools";
    version = versions.platformTools;

    src = platformToolsArchive;

    unpackPhase = ''
      mkdir -p $out
      tar -xjf $src -C $out

      # ldb-argdumper in this package will point to a dangling link
      # we're only building not debugging so safe to just ignore
      find $out -type l ! -exec test -e {} \; -delete 2>/dev/null || true
    '';

    meta = with lib; {
      description = "Solana platform tools for building on-chain programs";
      homepage = "https://github.com/anza-xyz/platformTools";
      license = licenses.asl20;
      platforms = platforms.unix;
    };
  };

  # Use Rust 1.86.0 as specified in agave's rust-toolchain.toml
  rust186 = fenix.toolchainOf {
    channel = "1.86.0";
    sha256 = "sha256-X/4ZBHO3iW0fOenQ3foEvscgAPJYl2abspaBThDOukI=";
  };
  rustForAgave = rust186.withComponents [
    "cargo"
    "rustc"
    "rust-src"
  ];

  agave =
    rustPlatform.buildRustPackage.override
    {
      rustc = rustForAgave;
      cargo = rustForAgave;
    }
    {
      pname = "agave";
      version = versions.agave;

      src = fetchFromGitHub {
        owner = "anza-xyz";
        repo = "agave";
        rev = "v${versions.agave}";
        hash = "sha256-pIvShCRy1OQcFwSkXZ/lLF+2LoAd2wyAQfyyUtj9La0=";
        fetchSubmodules = true;
      };

      cargoHash = "sha256-eendPKd1oZmVqWAGWxm+AayLDm5w9J6/gSEPUXJZj88=";

      cargoBuildFlags = map (n: "--bin=${n}") solanaPkgs;

      nativeBuildInputs = [
        pkg-config
        protobuf
        perl
        llvmPackages.clang
      ];

      buildInputs =
        [
          openssl
          zlib
          llvmPackages.libclang.lib
        ]
        ++ optionals isLinux [
          hidapi
          udev
        ];

      LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

      BINDGEN_EXTRA_CLANG_ARGS = toString (
        [
          "-isystem ${llvmPackages.libclang.lib}/lib/clang/${lib.getVersion llvmPackages.clang}/include"
        ]
        ++ optionals isLinux [
          "-isystem ${stdenv.cc.libc.dev}/include"
        ]
        ++ optionals hostPlatform.isDarwin [
          "-isystem ${stdenv.cc.libc}/include"
        ]
      );

      postPatch = ''
        substituteInPlace scripts/cargo-install-all.sh \
          --replace-fail './fetch-perf-libs.sh' 'echo "Skipping fetch-perf-libs in Nix build"' \
          --replace-fail '"$cargo" $maybeRustVersion install' 'echo "Skipping cargo install"'
      '';

      doCheck = false;

      meta = with lib; {
        description = "Solana cli and programs";
        homepage = "https://github.com/anza-xyz/agave";
        license = licenses.asl20;
        platforms = platforms.unix;
      };
    };

  # Anchor-nix wrapper script
  anchorNixUnwrapped = writeShellApplication {
    name = "anchor-nix";
    runtimeInputs = [anchor agave jq];
    text = builtins.readFile ../scripts/anchor-nix.sh;
  };

  anchorNix = symlinkJoin {
    name = "anchor-nix-wrapped";
    paths = [anchorNixUnwrapped];
    nativeBuildInputs = [makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/anchor-nix \
        --set PLATFORM_TOOLS "${platformTools}" \
        --set RUST_NIGHTLY "${rustNightly}" \
        --set SBF_SDK_PATH "${sbfSdk}"
    '';
  };
in
  symlinkJoin {
    name = "agave-with-toolchain-${versions.agave}";
    paths = [
      agave
      anchorNix
      anchor
    ];

    passthru = {
      inherit agave rustNightly;
    };

    meta =
      agave.meta
      // {
        description = "Solana programs & tooling with Anchor wrapper";
        mainProgram = "anchor-nix";
      };
  }
