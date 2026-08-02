{ lib, pkgs, ... }:

let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
in
{
  services.flatpak.enable = true;
  xdg.portal.config.common.default = "kde";

  systemd.services.flatpak-add-flathub = {
    description = "Add the Flathub Flatpak repository";
    wantedBy = singleton "multi-user.target";
    wants = singleton "network-online.target";
    after = singleton "network-online.target";

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${getExe pkgs.flatpak} remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
    };
  };
}
