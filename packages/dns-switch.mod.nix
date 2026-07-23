{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.dns-switch = pkgs.callPackage (
        {
          gnugrep,
          lib,
          openresolv,
          stdenv,
          systemd,
          writeShellApplication,
        }:
        let
          inherit (lib.meta) getExe getExe';
          grepCommand = if stdenv.hostPlatform.isDarwin then "/usr/bin/grep" else getExe gnugrep;
          resolvconfCommand = getExe' openresolv "resolvconf";
          sudoCommand = if stdenv.hostPlatform.isDarwin then "/usr/bin/sudo" else "/run/wrappers/bin/sudo";
          systemctlCommand = getExe' systemd "systemctl";
          platformText =
            if stdenv.hostPlatform.isDarwin then
              ''
                service="Wi-Fi"
                networksetup="/usr/sbin/networksetup"
                launchctl="/bin/launchctl"
                plist="/Library/LaunchDaemons/org.nixos.dnscrypt-proxy.plist"
                label="system/org.nixos.dnscrypt-proxy"

                current_profile() {
                  local dns_servers
                  dns_servers="$("$networksetup" -getdnsservers "$service")"

                  if printf '%s\n' "$dns_servers" | ${grepCommand} -Fxq "127.0.0.1"; then
                    echo "mullvad"
                  elif printf '%s\n' "$dns_servers" | ${grepCommand} -Fxq "1.1.1.1"; then
                    echo "cloudflare"
                  elif printf '%s\n' "$dns_servers" | ${grepCommand} -Fq "There aren't any DNS Servers set"; then
                    echo "automatic"
                  else
                    echo "custom"
                  fi
                }

                start_proxy() {
                  if ! "$launchctl" print "$label" >/dev/null 2>&1; then
                    ${sudoCommand} "$launchctl" bootstrap system "$plist"
                  fi
                }

                stop_proxy() {
                  if "$launchctl" print "$label" >/dev/null 2>&1; then
                    ${sudoCommand} "$launchctl" bootout "$label"
                  fi
                }

                set_mullvad() {
                  start_proxy
                  ${sudoCommand} "$networksetup" -setdnsservers "$service" 127.0.0.1
                }

                set_cloudflare() {
                  ${sudoCommand} "$networksetup" -setdnsservers "$service" 1.1.1.1
                  stop_proxy
                }

                set_automatic() {
                  ${sudoCommand} "$networksetup" -setdnsservers "$service" empty
                  stop_proxy
                }

                flush_cache() {
                  ${sudoCommand} /usr/bin/killall -HUP mDNSResponder || true
                }
              ''
            else
              ''
                current_profile() {
                  if ${resolvconfCommand} -l static 2>/dev/null | ${grepCommand} -Fxq "nameserver 127.0.0.1"; then
                    echo "mullvad"
                  elif ${resolvconfCommand} -l static 2>/dev/null | ${grepCommand} -Fxq "nameserver 1.1.1.1"; then
                    echo "cloudflare"
                  elif ${resolvconfCommand} -i static 2>/dev/null | ${grepCommand} -Fxq "static"; then
                    echo "custom"
                  else
                    echo "automatic"
                  fi
                }

                set_mullvad() {
                  ${sudoCommand} ${systemctlCommand} start dnscrypt-proxy.service
                  printf '%s\n' "nameserver 127.0.0.1" | ${sudoCommand} ${resolvconfCommand} -m 1 -a static
                }

                set_cloudflare() {
                  printf '%s\n' "nameserver 1.1.1.1" | ${sudoCommand} ${resolvconfCommand} -m 1 -a static
                  ${sudoCommand} ${systemctlCommand} stop dnscrypt-proxy.service
                }

                set_automatic() {
                  ${sudoCommand} ${resolvconfCommand} -f -d static
                  ${sudoCommand} ${systemctlCommand} stop dnscrypt-proxy.service
                }

                flush_cache() {
                  :
                }
              '';
        in
        writeShellApplication {
          name = "dns";
          text = platformText + ''

            show_status() {
              case "$(current_profile)" in
                mullvad)
                  echo "mullvad (base.dns.mullvad.net via encrypted DNS)"
                  ;;
                cloudflare)
                  echo "cloudflare (1.1.1.1)"
                  ;;
                automatic)
                  echo "automatic (network-provided DNS)"
                  ;;
                custom)
                  echo "custom (unrecognized DNS override)"
                  ;;
              esac
            }

            set_profile() {
              case "$1" in
                mv|mullvad|base)
                  set_mullvad
                  flush_cache
                  echo "DNS: mullvad (base.dns.mullvad.net via encrypted DNS)"
                  ;;
                cf|cloudflare|1.1.1.1)
                  set_cloudflare
                  flush_cache
                  echo "DNS: cloudflare (1.1.1.1)"
                  ;;
                no|automatic|auto|none|off)
                  set_automatic
                  flush_cache
                  echo "DNS: automatic (network-provided DNS)"
                  ;;
                *)
                  echo "usage: dns [mv|cf|no|cycle|status]" >&2
                  exit 2
                  ;;
              esac
            }

            action="''${1:-cycle}"
            case "$action" in
              mv|mullvad|base|cf|cloudflare|1.1.1.1|no|automatic|auto|none|off)
                set_profile "$action"
                ;;
              cycle)
                case "$(current_profile)" in
                  mullvad)
                    set_profile cloudflare
                    ;;
                  cloudflare)
                    set_profile automatic
                    ;;
                  automatic|custom)
                    set_profile mullvad
                    ;;
                esac
                ;;
              status)
                show_status
                ;;
              *)
                echo "usage: dns [mv|cf|no|cycle|status]" >&2
                exit 2
                ;;
            esac
          '';
        }
      ) { };
    };
}
