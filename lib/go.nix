{pkgs}: {
  packages = with pkgs; [
    go
    gopls
    gofumpt
    delve
    golangci-lint
    gotools
    air
    gotestsum
    buf
  ];

  shellHook = ''
    export GOPATH=$HOME/go
    export PATH=$GOPATH/bin:$PATH
  '';
}
