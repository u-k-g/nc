{
  config,
  lib,
  pkgs,
  self,
  ...
}:

let
  inherit (lib.lists) singleton;
  inherit (lib.meta) getExe;
  amp = self.packages.${pkgs.stdenv.hostPlatform.system}.amp;
in
{
  environment.systemPackages = singleton amp;

  security.sudo.extraConfig = ''
    ${config.nc.user.name} ALL = (root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
  '';

  launchd.user.agents.amp-guard.serviceConfig = {
    ProgramArguments = [
      (getExe amp)
      "guard"
    ];
    EnvironmentVariables = {
      HOME = config.nc.user.homeDirectory;
      XDG_STATE_HOME = "${config.nc.user.homeDirectory}/.local/state";
    };
    ProcessType = "Background";
    RunAtLoad = true;
    StartInterval = 10;
  };
}
