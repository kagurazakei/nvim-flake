{
  pkgs,
  lib ? pkgs.lib,
  mnw,
  dev ? false,
  sources ? import ./npins,
  ...
}:

# Just forward everything into default.nix
import ./default.nix {
  inherit
    pkgs
    lib
    mnw
    dev
    sources
    ;
}
