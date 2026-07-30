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
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) bool;

  user = config.nc.user;
in
{
  options.nc.radicle.enable = mkOption {
    type = bool;
    default = true;
    description = "Whether to configure Radicle and decrypt its identity secret.";
  };

  config = {
    secrets.radicle =
      mkIf config.nc.radicle.enable
      <|
        {
          file = ./radicle.age;
        }
        // optionalAttrs pkgs.stdenv.isDarwin {
          owner = config.system.primaryUser;
        };

    environment.variables.RAD_HOME = mkIf config.nc.radicle.enable "${user.homeDirectory}/.radicle";

    home-manager.users.${user.name} =
      { config, osConfig, ... }:
      {
        home.packages = mkIf osConfig.nc.radicle.enable <| singleton pkgs.radicle-node;

        home.sessionVariables.RAD_HOME = mkIf osConfig.nc.radicle.enable "${config.home.homeDirectory}/.radicle";

        home.file.".radicle/config.json" = mkIf osConfig.nc.radicle.enable {
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

        home.file.".radicle/keys/radicle" = mkIf osConfig.nc.radicle.enable {
          force = true;
          source = config.lib.file.mkOutOfStoreSymlink osConfig.secrets.radicle.path;
        };
        home.file.".radicle/keys/radicle.pub" = mkIf osConfig.nc.radicle.enable {
          force = true;
          text = ''
            ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINzDlJy403zDuRlof2dJcMGxHz9XZwSMIJkb4a64Hs5Z
          '';
        };
      };
  };
}
