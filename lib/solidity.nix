{pkgs}: {
  packages = with pkgs; [
    solc
    solc-select
    foundry
    slither-analyzer
    nodejs_22
  ];

  shellHook = ''
    export PATH=$HOME/.solc-select/artifacts:$PATH
  '';
}
