{ config, ... }:

{
  system.defaults.screencapture = {
    location = "${config.nc.user.homeDirectory}/Downloads";
    type = "png";
  };
}
