rec {
  hosts = {
    macbook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVbh74Osri8TqrnMnwMIN4RWJhXSRpyZ5HJpEK5PTwX uzair@macbook";
  };

  users = {
    uzair = hosts.macbook;
  };

  admins = [ users.uzair ];
}
