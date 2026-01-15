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
  writeShellScriptBin,
  anchor,
  jq,
  solanaPkgs ? [
    "cargo-build-sbf"
    "cargo-test-sbf"
    "solana"
    "solana-bench-tps"
    "solana-faucet"
    "solana-gossip"
    "solana-keygen"
    "solana-log-analyzer"
    "solana-net-shaper"
    "solana-test-validator"
    "solana-genesis"
    "agave-ledger-tool"
    "agave-install"
    "agave-validator"
  ],
}: let
  inherit (lib) optionals;
  inherit (stdenv) hostPlatform isLinux;

  versions = {
    agave = "2.2.17";
    platformTools = "v1.48";
  };

  # Create nightly toolchain from fenix (used for IDL generation)
  rustNightly = fenix.latest.withComponents [
    "cargo"
    "rustc"
    "rust-src"
  ];

  platformConfig = {
    x86_64-darwin = {
      archive = "platform-tools-osx-x86_64.tar.bz2";
      sha256 = "sha256-vLTtCmUkxxkd8KKQa8qpQ7kb5S52EI/DVllgtu8zM2I=";
    };
    aarch64-darwin = {
      archive = "platform-tools-osx-aarch64.tar.bz2";
      sha256 = "sha256-eZ5M/O444icVXIP7IpT5b5SoQ9QuAcA1n7cSjiIW0t0=";
    };
    x86_64-linux = {
      archive = "platform-tools-linux-x86_64.tar.bz2";
      sha256 = "sha256-qdMVf5N9X2+vQyGjWoA14PgnEUpmOwFQ20kuiT7CdZc=";
    };
    aarch64-linux = {
      archive = "platform-tools-linux-aarch64.tar.bz2";
      sha256 = "sha256-rsYCIiL3ueJHkDZkhLzGz59mljd7uY9UHIhp4vMecPI=";
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
    sha256 = "18nh745djcnkbs0jz7bkaqrlwkbi5x28xdnr2lkgrpybwmdfg06s";
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

  # Use Rust nightly version that's compatible with Agave version (via fenix)
  nightlyToolchain = fenix.toolchainOf {
    channel = "nightly";
    date = "2024-11-15";
    sha256 = "sha256-1uC3iVKIjZAtQ57qtpGIfvCPl1MTdTfWibjB37VWFPg=";
  };
  rustForAgave = fenix.combine [
    nightlyToolchain.cargo
    nightlyToolchain.rustc
    nightlyToolchain.rust-src
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
        hash = "sha256-Xbv00cfl40EctQhjIcysnkVze6aP5z2SKpzA2hWn54o=";
        fetchSubmodules = true;
      };

      cargoHash = "sha256-DEMbBkQPpeChmk9VtHq7asMrl5cgLYqNC/vGwrmdz3A=";

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
  anchorNix = writeShellScriptBin "anchor-nix" ''
        #!${stdenv.shell}
        set -euo pipefail

        readonly REAL_ANCHOR="${anchor}/bin/anchor"
        export SBF_SDK_PATH="${sbfSdk}"

        clean_rust_from_path() {
          echo "$PATH" | tr ':' '\n' | \
            grep -v "fenix" | \
            grep -v ".cargo/bin" | \
            grep -v "rustup" | \
            tr '\n' ':'
        }

        setup_solana() {
          export PATH=$(clean_rust_from_path)

          export PATH="${platformTools}/rust/bin:$PATH"
          export RUSTC="${platformTools}/rust/bin/rustc"
          export CARGO="${platformTools}/rust/bin/cargo"
        }

        setup_nightly() {
          export PATH=$(clean_rust_from_path | sed "s|${platformTools}||g")

          unset RUSTC CARGO || true

          export PATH="${rustNightly}/bin:$PATH"

          export RUST_TARGET_PATH="${platformTools}/rust/lib/rustlib"
        }

        has_idl_build_feature() {
          find programs -name "Cargo.toml" -type f 2>/dev/null | \
            xargs grep -l "idl-build" 2>/dev/null | \
            head -n1
        }

        run_build() {
          local extra_args=("$@")

          echo "Building Solana program with solana toolchain setup..."
          echo "Building program with Solana/Agave toolchain..."

          setup_solana

          local skip_idl=false
          local cargo_args=()
          local specific_package=""

          for arg in "''${extra_args[@]}"; do
            if [[ "$arg" == "--no-idl" ]]; then
              skip_idl=true
            elif [[ "$arg" != "--" ]]; then
              cargo_args+=("$arg")
            fi
          done

          for ((i=0; i<''${#cargo_args[@]}; i++)); do
            if [[ "''${cargo_args[$i]}" == "-p" && $((i+1)) -lt ''${#cargo_args[@]} ]]; then
              specific_package="''${cargo_args[$((i+1))]}"
              echo "Building package: $specific_package"
              break
            fi
          done

          if [ -n "$specific_package" ]; then
            local program_dir=""
            for dir in programs/*/; do
              if [ "$(basename "$dir")" = "$specific_package" ]; then
                program_dir="$dir"
                break
              fi
            done

            if [ -z "$program_dir" ]; then
              echo "Program directory not found for: $specific_package"
              return 1
            fi

            if ! cargo build-sbf --manifest-path "''${program_dir}Cargo.toml" --no-rustup-override --skip-tools-install; then
              echo "Program build failed"
              return 1
            fi
          else
            if ! "$REAL_ANCHOR" build --no-idl -- --no-rustup-override --skip-tools-install; then
              echo "Program build failed"
              return 1
            fi
          fi

          if [ "$skip_idl" = true ]; then
            echo "Skipping IDL generation (--no-idl flag)"
            return 0
          fi

          if cargo_toml=$(has_idl_build_feature); then
            echo "Generating IDL with nightly toolchain..."

            setup_nightly

            echo "Extracting IDL files..."
            mkdir -p target/idl

            local idl_success=0
            local idl_failed=0
            local idl_total=0

            for program_dir in programs/*/; do
              program_name=$(basename "$program_dir")

              if [ -n "$specific_package" ] && [ "$program_name" != "$specific_package" ]; then
                continue
              fi

              has_idl_build=false
              if [ -f "$program_dir/Cargo.toml" ]; then
                if grep -q "idl-build" "$program_dir/Cargo.toml" 2>/dev/null || true; then
                  has_idl_build=true
                fi
              fi

              if [ "$has_idl_build" = "true" ]; then
                ((idl_total++)) || true
                echo "   $program_name has idl-build feature ($idl_total)..."

                export ANCHOR_IDL_BUILD_PROGRAM_PATH="$program_dir"
                export ANCHOR_IDL_BUILD_RESOLUTION="TRUE"
                export ANCHOR_IDL_BUILD_NO_DOCS="FALSE"
                export ANCHOR_IDL_BUILD_SKIP_LINT="TRUE"
                export RUSTFLAGS="-A warnings"

                echo "      Building with idl-build feature..."
                build_output=$(cargo build \
                  --manifest-path "$program_dir/Cargo.toml" \
                  --features idl-build \
                  --lib 2>&1) || build_exit=$?
                build_exit=''${build_exit:-0}

                if [ "$build_exit" -ne 0 ]; then
                  echo "   Build failed for $program_name, skipping IDL extraction"
                  echo "   Build output (last 10 lines):" >&2
                  echo "$build_output" | tail -10 >&2
                  ((idl_failed++)) || true
                  unset ANCHOR_IDL_BUILD_PROGRAM_PATH ANCHOR_IDL_BUILD_RESOLUTION
                  unset ANCHOR_IDL_BUILD_NO_DOCS ANCHOR_IDL_BUILD_SKIP_LINT RUSTFLAGS
                  continue
                fi

                echo "      Build succeeded, now extracting IDL..."
                temp_output="/tmp/idl_$program_name.txt"

                set +e
                cargo test \
                  --manifest-path "$program_dir/Cargo.toml" \
                  --features idl-build \
                  --lib \
                  __anchor_private_print_idl \
                  -- \
                  --show-output \
                  --quiet \
                  --test-threads=1 > "$temp_output" 2>&1
                test_exit=$?
                set -e

                if [ "$test_exit" -eq 0 ]; then
                  idl_json=$(cat "$temp_output" | awk '
                    BEGIN { in_program=0; program="" }
                    /--- IDL begin program ---/ { in_program=1; next }
                    /--- IDL end program ---/ { in_program=0; next }
                    in_program { program = program $0 "\n" }
                    END { printf "%s", program }
                  ')

                  if [ -n "$idl_json" ] && [ "$(echo "$idl_json" | tr -d '[:space:]')" != "" ]; then
                    idl_filename=$(echo "$program_name" | tr '-' '_')

                    keypair_file="target/deploy/''${idl_filename}-keypair.json"
                    if [ -f "$keypair_file" ]; then
                      program_id=$(${agave}/bin/solana-keygen pubkey "$keypair_file")
                      idl_json=$(echo "$idl_json" | ${jq}/bin/jq --arg addr "$program_id" '. + {address: $addr}')
                      echo "    Added program ID: $program_id"
                    fi

                    echo "$idl_json" > "target/idl/''${idl_filename}.json"
                    echo "    Generated target/idl/''${idl_filename}.json"
                    ((idl_success++)) || true
                    rm -f "$temp_output"
                  else
                    echo "   Failed to extract IDL for $program_name (no program section found)"
                    ((idl_failed++)) || true
                    rm -f "$temp_output"
                  fi
                else
                  echo "   IDL test failed for $program_name (exit code: $test_exit)"
                  ((idl_failed++)) || true
                  rm -f "$temp_output"
                fi

                unset ANCHOR_IDL_BUILD_PROGRAM_PATH ANCHOR_IDL_BUILD_RESOLUTION
                unset ANCHOR_IDL_BUILD_NO_DOCS ANCHOR_IDL_BUILD_SKIP_LINT RUSTFLAGS
              fi
            done

            if [ "$idl_success" -gt 0 ] && [ "$idl_failed" -eq 0 ]; then
              echo "Build complete: generated $idl_success IDL file(s)"
            elif [ "$idl_success" -gt 0 ] && [ "$idl_failed" -gt 0 ]; then
              echo "Build complete: generated $idl_success IDL file(s), $idl_failed failed"
              return 1
            elif [ "$idl_failed" -gt 0 ]; then
              echo "Build complete but all IDL generation failed ($idl_failed program(s))"
              return 1
            else
              echo "No programs with idl-build feature found"
            fi
          else
            echo "Skipping IDL generation (no idl-build feature found in Cargo.toml)"
            echo "Build complete: program built with Solana toolchain"
          fi
        }

        run_test() {
          local extra_args=("$@")

          echo "Testing Solana program..."

          if ! run_build "''${extra_args[@]}"; then
            return 1
          fi

          setup_nightly

          echo "Running tests with nightly toolchain..."
          "$REAL_ANCHOR" test --skip-build "''${extra_args[@]}"
        }

        run_unit_test() {
          local extra_args=("$@")

          echo "Running unit tests..."

          if ! run_build; then
            return 1
          fi

          setup_nightly

          echo "Running cargo test with nightly toolchain..."
          cargo test "''${extra_args[@]}"
        }

        case "''${1:-}" in
          build)
            shift
            run_build "$@"
            ;;

          test)
            shift
            run_test "$@"
            ;;

          unit-test)
            shift
            run_unit_test "$@"
            ;;

          keys)
            "$REAL_ANCHOR" "$@"
            ;;

          deploy)
            "$REAL_ANCHOR" "$@"
            ;;

          *)
            cat <<EOF
    anchor-nix: Anchor wrapper for Nix environments

    Usage:
      anchor-nix build [options]      - Build program with Solana toolchain, generate IDL with nightly
      anchor-nix test [options]       - Build and run anchor client tests
      anchor-nix unit-test [options]  - Build program then run cargo test
      anchor-nix keys [subcommand]    - Manage program keypairs (sync, list, etc.)
      anchor-nix deploy [options]     - Deploy programs to specified cluster

    EOF
            exit 1
            ;;
        esac
  '';
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
