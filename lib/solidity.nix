{pkgs}: {
  packages = with pkgs; [
    solc
    solc-select
    foundry
    slither-analyzer
    nodejs_22
    nodePackages.npm
    nodePackages.prettier
  ];

  shellHook = ''
    export PATH=$HOME/.solc-select/artifacts:$PATH
  '';
}
