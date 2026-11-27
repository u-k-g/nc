{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib.strings) concatMapStringsSep escapeShellArg;
  variables = config.launchd.user.envVariables;
in
{
  # nix-darwin applies launchd.user.envVariables with `launchctl setenv` during
  # activation only, and a new login session starts without them. Finder
  # launched apps then get launchd's default PATH, so tools installed through
  # the nix profile, such as gh, are missing until the next rebuild. Re-apply
  # the variables inside the user's GUI domain at every login.
  # nix-darwin prefixes the label with org.nixos.
  launchd.user.agents."launchd-env".serviceConfig = {
    ProgramArguments = [
      (toString (
        pkgs.writeShellScript "launchd-env" (
          concatMapStringsSep "\n" (
            name: "/bin/launchctl setenv ${escapeShellArg name} ${escapeShellArg variables.${name}}"
          ) (builtins.attrNames variables)
        )
      ))
    ];
    RunAtLoad = true;
  };
}
