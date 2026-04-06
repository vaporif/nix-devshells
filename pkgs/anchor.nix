{
  lib,
  stdenv,
  craneLib,
  fetchFromGitHub,
  pkg-config,
  openssl,
  perl,
  udev,
}: let
  version = "0.32.1";

  src = fetchFromGitHub {
    owner = "solana-foundation";
    repo = "anchor";
    tag = "v${version}";
    hash = "sha256-oyCe8STDciRtdhOWgJrT+k50HhUWL2LSG8m4Ewnu2dc=";
    fetchSubmodules = true;
  };

  commonArgs = {
    inherit src version;
    pname = "anchor";
    strictDeps = true;

    nativeBuildInputs = [
      perl
      pkg-config
    ];

    buildInputs = [openssl] ++ lib.optionals stdenv.hostPlatform.isLinux [udev];
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
  craneLib.buildPackage (commonArgs
    // {
      inherit cargoArtifacts;

      cargoTestExtraArgs = lib.concatStringsSep " " [
        "--"
        "--skip=tests::test_check_and_get_full_commit_when_full_commit"
        "--skip=tests::test_check_and_get_full_commit_when_partial_commit"
        "--skip=tests::test_get_anchor_version_from_commit"
      ];

      meta = with lib; {
        description = "Solana Sealevel Framework";
        homepage = "https://github.com/solana-foundation/anchor";
        changelog = "https://github.com/solana-foundation/anchor/blob/v${version}/CHANGELOG.md";
        license = licenses.asl20;
        mainProgram = "anchor";
      };
    })
