{
  description = "Solana Anchor project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    anchor-overlay.url = "github:vaporif/anchor-overlay";
    anchor-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    anchor-overlay,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        inputsFrom = [anchor-overlay.devShells.${system}.default];
        packages = [pkgs.sccache];
        RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
      };
    });
  };
}
