{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.generators) toJSON;
  inherit (lib.lists) singleton;

  user = config.nc.user;
in
{
  secrets.radicle = {
    file = ./radicle.age;
  }
  // optionalAttrs pkgs.stdenv.isDarwin {
    owner = config.system.primaryUser;
  };

  home-manager.users.${user.name} =
    { config, osConfig, ... }:
    {
      home.packages = singleton pkgs.radicle-node;

      home.sessionVariables.RAD_HOME = "${config.xdg.dataHome}/radicle";

      xdg.dataFile."radicle/config.json" = {
        force = true;
        text = toJSON { } {
          publicExplorer = "https://radicle.network/nodes/$host/$rid$path";
          preferredSeeds = [
            "z6MkrLMMsiPWUcNPHcRajuMi9mDfYckSoJyPwwnknocNYPm7@iris.radicle.network:8776"
            "z6Mkmqogy2qEM2ummccUthFEaaHvyYmYBYh3dbe9W4ebScxo@rosa.radicle.network:8776"
          ];

          node.alias = user.handle;
        };
      };

      xdg.dataFile."radicle/keys/radicle".source =
        config.lib.file.mkOutOfStoreSymlink osConfig.secrets.radicle.path;
      xdg.dataFile."radicle/keys/radicle.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINzDlJy403zDuRlof2dJcMGxHz9XZwSMIJkb4a64Hs5Z
      '';
    };
}
