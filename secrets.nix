let
  keys = import ./keys.nix;
in
{
  # Add encrypted secret files here, for example:
  # "hosts/macbook/example.age".publicKeys = keys.admins ++ [ keys.hosts.macbook ];
}
