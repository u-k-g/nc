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
  radicleHome = "${config.home-manager.users.${user.name}.xdg.dataHome}/radicle";
in
{
  home-manager.users.${user.name} = {
    home.packages = singleton pkgs.radicle-node;

    home.sessionVariables.RAD_HOME = radicleHome;

    xdg.dataFile."radicle/config.json".text = toJSON { } {
      publicExplorer = "https://radicle.network/nodes/$host/$rid$path";
      preferredSeeds = [
        "z6MkrLMMsiPWUcNPHcRajuMi9mDfYckSoJyPwwnknocNYPm7@iris.radicle.xyz:8776"
        "z6Mkmqogy2qEM2ummccUthFEaaHvyYmYBYh3dbe9W4ebScxo@rosa.radicle.xyz:8776"
      ];

      node.alias = user.handle;
    };
  };
}
