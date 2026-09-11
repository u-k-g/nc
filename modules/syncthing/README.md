# Vault synchronization

`../syncthing.mod.nix` configures Manara and Darwinbook. Both hosts enable it in
their `default.nix`. The default vault is `~/Documents/vault`; override
`nc.syncthing.vaultPath` on each host to use an existing directory. Vault contents
are ordinary writable files and are never managed by Nix.

Manara runs Syncthing at boot as `ukg`. Darwinbook runs it through launchd when
`uzair` logs in. Do not also run Syncthing.app or a Homebrew Syncthing service:
only one daemon should own the state and listen ports.

The private identity and database live in `~/.local/state/syncthing` on both
computers. This is beneath Manara's persisted `/home`. Do not synchronize this
directory, put it in Git, or copy one device's identity onto another device.

## First setup

1. Set `nc.syncthing.vaultPath` to the existing vault path if needed. Keep a backup
   of existing notes before the initial merge. Start with the existing vault on
   one device and empty destination directories on the others.
2. Include the new module in Git's tracked files before rebuilding this Git
   flake. Apply the configuration on each computer through the normal nc rebuild.
3. Open `http://127.0.0.1:8384` on each computer and use Actions / Show ID.
   For Manara from Darwinbook, use
   `ssh -N -L 8385:127.0.0.1:8384 ukg@manara`, then open
   `http://127.0.0.1:8385`.
4. Install BasicSync or Syncthing-Fork on Android. Allow background operation,
   startup after reboot, and access to the vault directory. Obtain its device ID.
5. Add the three public IDs alongside the addresses in
   `config.nc.syncthing.devices` in `../syncthing.mod.nix`, for example
   `manara.id = "THE-FULL-DEVICE-ID";`, and rebuild both computers.
6. On Android, add both computers using those IDs and accept their shared folder.
   Use folder ID `notes`, Send & Receive, and a directory such as
   `/storage/emulated/0/Documents/vault`. Open that same directory in the notes
   editor. Enable Ignore Permissions on the phone too.
7. On Android, set Manara's addresses to `tcp://100.96.29.81:22000, dynamic`
   and Darwinbook's to `tcp://100.93.128.84:22000, dynamic`. Disable Global
   Discovery, Enable Relaying, and NAT Traversal; leave Local Discovery enabled.
   Set Sync Protocol Listen Addresses to `tcp://:22000` (not `default`).
8. Wait for Up to Date on all devices. Verify a disposable note can be created,
   edited, and deleted from each device and that changes reach both peers.

IDs initially default to null: no peers are invented or automatically trusted.
The `notes` folder's peer list is declarative, so GUI changes to that list are
replaced on service restart. Unrelated folders and devices are preserved.
When retiring a device, remove its ID from Nix and remove the device itself from
each GUI; preserving unrelated devices means removing a registry entry does not
delete the global device record automatically.

## Networking and recovery

The default combines explicit tailnet addresses with local discovery. Public
discovery, Syncthing relays and NAT traversal are disabled. The `dynamic` peer
address allows locally discovered addresses; it does not enable global discovery.
Remote syncing requires Tailscale, while devices on the same LAN can sync without
it if the LAN permits communication between them. Syncthing authenticates peers
and encrypts sync traffic independently of Tailscale.

An explicit TCP listener replaces `default`, avoiding public relay-pool and QUIC
STUN endpoints. The GUI stays on loopback. Manara opens TCP 22000 for sync and UDP
21027 for local discovery; allow Syncthing's incoming connections on macOS too.
LAN discovery exposes device IDs to others on that LAN. Disabling Syncthing's
public services does not change Tailscale's own coordination or relay behavior.

For private tailnet-only operation, set `nc.syncthing.tailnetOnly = true` on both
computers. On Android, disable global/local discovery, relays and NAT traversal,
remove `dynamic` from peer addresses, and set its listen address to
`tcp://100.78.224.36:22000`. The computers bind only their configured tailnet
addresses, so syncing then requires Tailscale. Update the declared addresses if
a device is removed and reenrolled in the tailnet with a different IP.

Manara retains staggered incoming versions for up to one year in `.stversions`.
This does not capture edits made locally on Manara and is not an independent
backup. Back up the vault and its version history separately. Conflicting offline
edits can produce `sync-conflict` files; resolve their contents manually.

No editor-specific ignores are imposed. Add those only after choosing the notes
editor; attachments should remain part of the vault. Do not run another sync
engine over this same folder.

Reference: RGBCube/ncc's `modules/syncthing.mod.nix` at
`1e43f2f396806a789bc528e57314b9386d9aca4f` installs the macOS app and disables
its update checks. Its NixOS service is commented out. Here the Nix package and
launchd agent also declare the vault and peers, with updates controlled by nc.
