{ ... }:

let
  # T3 Code reads both: the first turns off product telemetry, the second
  # stops the OpenTelemetry exporter.
  variables = {
    T3CODE_TELEMETRY_ENABLED = "false";
    T3CODE_OTEL_SDK_DISABLED = "true";
  };

  ingestHost = "ingest.t3.codes";
in
{
  commonModules.t3-telemetry =
    { config, ... }:
    {
      environment.variables = variables;

      # Nushell starts as the login shell without sourcing the system
      # environment, so it only sees the per-user session variables.
      home.users.${config.nc.user.name}.environment.sessionVariables = variables;
    };

  flake.nixosModules.t3-telemetry =
    { config, lib, ... }:
    let
      inherit (lib.lists) singleton;
      inherit (lib.modules) mkIf;
    in
    {
      networking.hosts = {
        "0.0.0.0" = singleton ingestHost;
        "::" = singleton ingestHost;
      };

      # systemd services do not inherit environment.variables.
      systemd.services.t3code.environment = mkIf config.nc.nixos.t3-server.enable variables;
    };

  flake.darwinModules.t3-telemetry =
    { ... }:
    {
      # The desktop app starts from launchd, not from a shell.
      launchd.user.envVariables = variables;

      # nix-darwin restores /etc/hosts.before-nix-darwin on every switch, so
      # environment.etc.hosts would be undone. Edit the file in place after
      # the networking activation instead, keeping only lines tagged by this
      # module.
      system.activationScripts.postActivation.text = /* bash */ ''
        hosts_new="$(/usr/bin/mktemp)"
        /usr/bin/grep --invert-match ' # nc:t3-telemetry$' /etc/hosts > "$hosts_new" || true
        printf '0.0.0.0 ${ingestHost} # nc:t3-telemetry\n:: ${ingestHost} # nc:t3-telemetry\n' >> "$hosts_new"
        if ! /usr/bin/cmp -s "$hosts_new" /etc/hosts; then
          echo "blocking ${ingestHost} in /etc/hosts..." >&2
          /bin/cat "$hosts_new" > /etc/hosts
          /usr/bin/dscacheutil -flushcache
          /usr/bin/killall -HUP mDNSResponder || true
        fi
        /bin/rm -f "$hosts_new"
      '';
    };
}
