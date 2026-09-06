# Hermes

Open <https://manara.tail4b71d2.ts.net:8443>. On first visit, choose
sign in as `ukg`,
Get the generated password on Manara:

```sh
sed -n 's/^HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=//p' ~/.hermes/dashboard.env
```

## Browser automation

Manara enables the optional `nc.nixos.hermes.browser-cdp.enable` service.
It runs headless Helium with the isolated profile
`~/.hermes/browser-automation-profile` and listens on loopback port 9333.
The interactive Helium launcher and its profile are independent.
Override `nc.nixos.hermes.browser-cdp.port` to change the port, and keep
`browser.cdp_url` in `~/.hermes/config.yaml` in sync (default:
`http://127.0.0.1:9333`).

Apply from this repository on Manara using the usual switch path:

```sh
git add modules/home/browser-cdp-service.mod.nix
nix run .#rebuild -- manara
systemctl --user daemon-reload
systemctl --user start browser-cdp
systemctl --user status browser-cdp
curl -s http://127.0.0.1:9333/json/version
```

The new module must be added to Git's index for Git-backed flake discovery;
no commit is required. This repo uses Hjem, so a NixOS switch owns the unit.
It starts with the user manager, including before login via Manara's existing
linger setting, and retries after five seconds if the browser exits.

To release the automation profile for a manual headed session, run
`systemctl --user stop browser-cdp` first, then start it again after closing
that session. To disable it declaratively, set
`nc.nixos.hermes.browser-cdp.enable = false;` and switch.
