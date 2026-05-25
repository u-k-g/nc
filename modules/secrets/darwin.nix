{
  config,
  inputs,
  pkgs,
  ...
}:

{
  imports = [ inputs.agenix.darwinModules.age ];

  age.identityPaths = [ "${config.nc.user.homeDirectory}/.ssh/id_ed25519" ];

  environment.systemPackages = [ inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  home-manager.users.${config.nc.user.name}.home.packages = [ pkgs.rage ];
}
