let
  uzair = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVbh74Osri8TqrnMnwMIN4RWJhXSRpyZ5HJpEK5PTwX uzair@macbook";
in
{
  flake.keys = {
    macbook = uzair;
    inherit uzair;
  };

  flake.keys-admin = [ uzair ];
}
