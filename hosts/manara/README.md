# SSD-backed development scratch

Manara deliberately keeps `/` on a tmpfs limited to 25% of RAM. `/tmp` stays
on that ephemeral root for ordinary runtime files. `/var/tmp` is a bcachefs
subvolume declared through `persist.mountpoints`, on the same SSD filesystem
as `/nix`. Systemd tmpfiles gives both `/tmp` and `/var/tmp` root ownership,
mode `1777`, and 21-day age-based cleanup. `/tmp` also disappears at reboot;
`/var/tmp` survives reboots but is not permanent storage.

The shell configuration sets `TMPDIR`, `TMP`, and `TEMP` to `/var/tmp`, including
the generated Nushell `$env` assignments. Nix daemon builds, T3, Hermes, and the
automation browser receive these settings explicitly. Other system services
keep their existing environments. Hermes Web retains `PrivateTmp`; its Deno
cache uses the private `/var/tmp` backed by this mount.

pnpm's configured home and the browser automation profile already live under
persistent `/home`. No repo-owned development shell or review script forces
`/tmp`. The shared `~/.agents/AGENTS.md`, symlinked by nc at
`~/.codex/AGENTS.md` and `~/.config/opencode/AGENTS.md`, requires `/var/tmp` for review
worktrees and other development scratch. Tools launched from these shells
inherit the variables; a project shell that overrides them must preserve an
SSD-backed location. Nix builders retain their own isolated `$TMPDIR`; the
daemon environment moves the backing build directory onto the SSD.

## Existing installation: create the subvolume before switching

Disko creates subvolumes during installation, not during an ordinary rebuild.
On Manara, run these Nushell commands once before switching this configuration.
They temporarily expose the existing filesystem root to create `var/tmp`;
the persistent mount itself remains owned by Disko. Do not reformat the disk.

```nu
let scratch_device = (nix eval --raw '.#nixosConfigurations.manara.config.fileSystems."/var/tmp".device')
sudo mkdir --parents /run/nc-persist
sudo mount --types bcachefs $scratch_device /run/nc-persist
sudo mkdir --parents /run/nc-persist/var
if not ("/run/nc-persist/var/tmp" | path exists) {
  sudo bcachefs subvolume create /run/nc-persist/var/tmp
}
sudo chmod 1777 /run/nc-persist/var/tmp
sudo chown root:root /run/nc-persist/var/tmp
sudo umount /run/nc-persist
sudo rmdir /run/nc-persist
nix run .#rebuild -- manara
```

After switching, start a new shell and restart existing development sessions.
Check `findmnt --target /var/tmp` for `bcachefs`, `findmnt --target /` for
`tmpfs`, and `stat --format '%a %U:%G' /var/tmp` for `1777 root:root`.
Existing files under `/tmp` are not moved; remove obsolete review worktrees
through Git and clean up only known disposable artifacts.

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
