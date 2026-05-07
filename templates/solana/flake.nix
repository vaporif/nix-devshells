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

    devShells = forAllSystems (system: {
      default = anchor-overlay.devShells.${system}.default;
    });
  };
}
