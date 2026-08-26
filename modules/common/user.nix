{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.attrsets) attrValues optionalAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe';
  inherit (lib.modules) mkOrder;
  inherit (lib.options) mkOption;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.types)
    attrsOf
    lines
    path
    str
    ;

  userActivation = pkgs.writeShellScript "nc-user-activation" ''
    export HOME=${lib.escapeShellArg config.nc.user.homeDirectory}
    export USER=${lib.escapeShellArg config.nc.user.name}
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    DRY_RUN_CMD=
    VERBOSE_ARG=
    run() { "$@"; }

    ${
      concatStringsSep "\n"
      <|
        attrValues config.home.users.${config.nc.user.name}.activationScripts
        ++ attrValues config.nc.userActivationScripts
    }
  '';
in
{
  options.nc.userActivationScripts = mkOption {
    type = attrsOf lines;
    default = { };
    description = "Scripts run as the configured user after system activation.";
  };

  options.nc.user = {
    name = mkOption {
      type = str;
      description = "Host-local OS account username.";
    };

    handle = mkOption {
      type = str;
      default = "ukg";
      description = "Portable user handle used across machines.";
    };

    fullName = mkOption {
      type = str;
      default = "uzair khan ghori";
    };

    email = mkOption {
      type = str;
      default = "ukghori08@gmail.com";
    };

    homeDirectory = mkOption {
      type = path;
      description = "Home directory for the host-local OS account.";
    };
  };

  config.system.activationScripts =
    optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      postActivation.text = mkOrder 2000 ''
        /usr/bin/sudo -u ${lib.escapeShellArg config.nc.user.name} -H ${userActivation}
      '';
    }
    // optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      nc-user = {
        deps = singleton "users";
        text = ''
          ${getExe' pkgs.util-linux "runuser"} -u ${lib.escapeShellArg config.nc.user.name} -- ${userActivation}
        '';
      };
    };
}
