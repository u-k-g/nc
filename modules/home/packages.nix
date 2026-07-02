{
  config,
  lib,
  pkgs,
  self,
  ...
}:

let
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe hiPrio;
  user = config.nc.user;

  bunGlobalPackages = [
    "tscircuit@0.0.1837"
  ];

  opencodeCli = hiPrio (
    pkgs.writeShellScriptBin "opencode" ''
      exec ${getExe pkgs.opencode} "$@"
    ''
  );
  opencodeDesktopApp = pkgs.symlinkJoin {
    name = "opencode-desktop-app";
    paths = [ pkgs.opencode-desktop ];
    postBuild = ''
      rm -rf $out/bin
    '';
  };
  corepackPnpm = pkgs.symlinkJoin {
    name = "corepack-pnpm";
    paths = [ pkgs.corepack ];
    postBuild = ''
      rm -f $out/bin/corepack
      rm -f $out/bin/yarn
    '';
  };

  dix =
    if pkgs.stdenv.isDarwin then
      pkgs.dix.overrideAttrs (_: {
        doCheck = false;
      })
    else
      pkgs.dix;

  rustToolchain = pkgs.rust-bin.stable."1.93.0".default.override {
    extensions = [
      "rust-src"
      "rustfmt"
      "llvm-tools"
    ];
    targets = [
      "thumbv7em-none-eabi"
    ];
  };

  commonPackages = with pkgs; [
    bash
    nushell
    atuin

    coreutils
    diffutils
    openssl
    less
    bat
    watch
    rsync
    rclone
    curl
    pkg-config
    cacert

    helix

    git
    jujutsu
    jjui
    radicle-node
    gh
    mergiraf

    tmux
    carapace
    zellij
    btop
    yazi
    lazyssh
    dialog
    fzf
    inshellisense
    fish
    hyperfine
    mosh
    dix

    ripgrep
    ast-grep
    gitleaks
    fd
    eza
    zoxide
    unzip
    unar
    just

    sd
    ffmpeg
    ffsend
    scrcpy
    tio
    imagemagick

    bun
    deno
    nodejs
    corepackPnpm
    opencodeCli
    zig
    lua
    fnm

    llvm
    clang
    rustToolchain
    clang-tools
    lld

    cmakeCurses

    ruff
    uv
    biome
    oxlint
    nixfmt
    topiary
    shfmt
    shellcheck

    cmake-language-server
    markdown-oxide
    nixd
    taplo
    texlab
    tree-sitter
    bash-language-server
    ty
    typos
    yaml-language-server
    zls

    arduino-cli
    platformio
    arduino-language-server
    micropython
    tytools

    arp-scan
    nmap
    nbtscan
    usbutils

    screenfetch
    fastfetch
    vivid
  ];

  linuxPackages = with pkgs; [
    docker
    docker-buildx
    opencode-desktop
  ];

  darwinPackages = with pkgs; [
    colima
    opencodeDesktopApp
    self.packages.${pkgs.stdenv.hostPlatform.system}.t3-code-nightly
  ];
in
{
  home-manager.users.${user.name} = {
    home.packages =
      commonPackages
      ++ optionals pkgs.stdenv.isLinux linuxPackages
      ++ optionals pkgs.stdenv.isDarwin darwinPackages;

    home.activation.bun-global-packages =
      config.home-manager.users.${user.name}.lib.dag.entryAfter [ "writeBoundary" ]
        ''
          export HOME=${lib.escapeShellArg user.homeDirectory}
          export BUN_INSTALL="$HOME/.bun"

          ${getExe pkgs.bun} install --global ${lib.escapeShellArgs bunGlobalPackages} \
            || printf 'warning: failed to install Bun global packages\n' >&2
        '';
  };
}
