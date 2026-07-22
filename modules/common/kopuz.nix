{
  inputs,
  pkgs,
  self,
  ...
}:

{
  nix.settings = {
    extra-substituters = [ "https://kopuz.cachix.org" ];
    extra-trusted-public-keys = [
      "kopuz.cachix.org-1:J2X3AnAYhKTJW5S3aCLoA1ckonQXVNZMQvhZA0YAufw="
    ];
  };

  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.kopuz
  ];
}
