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
  environment.etc = optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    # launchd does not inherit the user's WATCHMAN_CONFIG_FILE.
    "watchman.json".source = "${
      config.home.users.${user.name}.xdg.config.directory
    }/watchman/watchman.json";
  };

  home.users.${user.name} = {
    packages = singleton pkgs.watchman;
    environment.sessionVariables.WATCHMAN_CONFIG_FILE = "${
      config.home.users.${user.name}.xdg.config.directory
    }/watchman/watchman.json";

    xdg.config.files."watchman/watchman.json" = {
      generator = toJSON { };
      value.ignore_dirs = [
        ".direnv"
        "node_modules"
        "target"
      ];
    };
  };
}
