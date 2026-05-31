rec {
  hosts = {
    darwinbook = "age16h0a9z2kxg5ursdqwgl5h8fqy2lapvz3n770wj9e0xau2xa3ya2sd0esp0";
  };

  users = {
    uzair = hosts.darwinbook;
  };

  admins = [ users.uzair ];
}
