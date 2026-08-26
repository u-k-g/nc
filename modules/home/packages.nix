{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe;
  user = config.nc.user;

  bunGlobalPackages = [
    "tscircuit@0.0.1837"
  ];

  kicadCli = pkgs.writeShellScriptBin "kicad-cli" ''
    exec /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli "$@"
  '';
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

  commonPackages = with pkgs; [
    bash
    nushell
    atuin

    coreutils
    diffutils
    openssl
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
    gh
    mergiraf

    tmux
    carapace
    zellij
    btop
    yazi
    lazyssh
    dialog
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
    just

    sd
    ffmpeg
    ffsend
    handy
    scrcpy
    tio
    imagemagick

    bun
    deno
    nodejs
    corepackPnpm
    zig
    lua
    fnm

    llvm
    clang
    clang-tools
    lld

    cargo-deny
    cargo-expand
    cargo-fuzz
    cargo-nextest
    evcxr
    cargo
    clippy
    rust-analyzer
    rustc
    rustfmt

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
    tytools

    arp-scan
    nmap
    nbtscan
    usbutils

    microfetch
    vivid
  ];

  linuxPackages = with pkgs; [
    docker
    docker-buildx
    kicad
    opencode-desktop
    unar
  ];

  darwinPackages = [
    kicadCli
  ];
in
{
  home.users.${user.name} = {
    packages =
      commonPackages
      ++ optionals pkgs.stdenv.isLinux linuxPackages
      ++ optionals pkgs.stdenv.isDarwin darwinPackages;

  };

  nc.userActivationScripts.bun-global-packages = ''
    export BUN_INSTALL="$HOME/.bun"

    ${getExe pkgs.bun} install --global ${lib.escapeShellArgs bunGlobalPackages} \
      || printf 'warning: failed to install Bun global packages\n' >&2
  '';
}
