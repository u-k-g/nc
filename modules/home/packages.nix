{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.lists) optionals;
  user = config.nc.user;
  workstation = pkgs.stdenv.hostPlatform.isDarwin || config.nc.nixos.workstation.enable;

  kicadCli = pkgs.writeShellScriptBin "kicad-cli" ''
    exec /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli "$@"
  '';
  dix =
    if pkgs.stdenv.hostPlatform.isDarwin then
      pkgs.dix.overrideAttrs (_: {
        doCheck = false;
      })
    else
      pkgs.dix;

  essentialPackages = with pkgs; [
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
    cacert

    helix

    git
    jujutsu
    jjui
    gh
    mergiraf

    carapace
    btop
    yazi
    dialog
    inshellisense
    fish
    hyperfine
    mosh

    ripgrep
    ast-grep
    fd
    eza
    zoxide
    unzip
    just
    jq

    sd

    arp-scan
    nmap
    nbtscan
    usbutils

    microfetch
    vivid

    pkg-config
    python3
    uv

    nodejs
    pnpm
    tio
  ];

  extendedPackages = with pkgs; [
    dix

    ffsend
    handy

    lua

    nixfmt
    topiary
    shfmt
    shellcheck

    markdown-oxide
    nixd
    taplo
    tree-sitter
    bash-language-server
    typos
    yaml-language-server
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
    pkgs.clang
  ];
in
{
  home.users.${user.name} = {
    xdg.config.files."pnpm/config.yaml" = {
      generator = (pkgs.formats.yaml { }).generate "pnpm-config.yaml";
      value.minimumReleaseAge = 72 * 60;
    };

    packages =
      essentialPackages
      ++ optionals workstation extendedPackages
      ++ optionals (workstation && pkgs.stdenv.hostPlatform.isLinux) linuxPackages
      ++ optionals (workstation && pkgs.stdenv.hostPlatform.isDarwin) darwinPackages;
  };
}
