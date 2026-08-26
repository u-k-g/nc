{ config, lib, ... }:

let
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf lines;
in
{
  options.activationScripts = mkOption {
    type = attrsOf lines;
    default = { };
    description = "Scripts run as this user after system activation.";
  };

  config.environment.sessionVariables = {
    XDG_CACHE_HOME = "${config.directory}/.cache";
    XDG_CONFIG_HOME = "${config.directory}/.config";
    XDG_DATA_HOME = "${config.directory}/.local/share";
    XDG_STATE_HOME = "${config.directory}/.local/state";
    OPENCODE_DB = "opencode-stable.db";
    ZDOTDIR = "${config.directory}/.config/zsh";
  };
}
