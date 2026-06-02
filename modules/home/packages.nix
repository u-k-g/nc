{
  config,
  lib,
  pkgs,
  self,
  ...
}:

let
  inherit (lib) getExe hiPrio optionals;
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
    lazygit
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
    codex
    opencodeCli
    pnpm
    zig
    lua
    fnm

    llvm
    clang
    rustc
    cargo
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
  home-manager.users.${config.nc.user.name}.home.packages =
    commonPackages
    ++ optionals pkgs.stdenv.isLinux linuxPackages
    ++ optionals pkgs.stdenv.isDarwin darwinPackages;
}
