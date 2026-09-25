let
  darwinbook = "age16h0a9z2kxg5ursdqwgl5h8fqy2lapvz3n770wj9e0xau2xa3ya2sd0esp0";
  desktop = "age1g085gq3e08p72jh8tt7g9ratyg94u72ygt5arfmm7gg6dj5klgqs6gtsn2";
  manara = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBWDp7YNDrwcgGv+PM0kCw3R+pSUS9hJkDw46lpQk48M";
  manaraUser = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOrYlDEvoop3Ih9/Un7dZEkb7uvXRCTIvdlRw7F4Q7YK";
  uzair = "age1y8dyavkxetpefenu3zdrjxjutwz3xr4gyc72sh58xxs745f76f3qctm9ag";
in
{
  hosts = {
    inherit darwinbook desktop;
    manara = [
      manara
      manaraUser
    ];
  };

  users = {
    inherit uzair;
  };

  admins = [
    darwinbook
    uzair
  ];
}
