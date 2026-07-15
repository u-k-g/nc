{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.generators) toJSON;
  inherit (lib.lists) singleton;

  user = config.nc.user;
in
{
  home-manager.users.${user.name} = {
    home.packages = singleton pkgs.radicle-node;

    home.sessionVariables.RAD_HOME = "${
      config.home-manager.users.${user.name}.home.homeDirectory
    }/.radicle";

    home.file.".radicle/config.json" = {
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
  };
}
