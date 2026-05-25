let
  keys = import ../keys.nix;
in
{
  flake.keys = keys.hosts // keys.users;

  flake.keys-admin = keys.admins;
}
