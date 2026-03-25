{
  sources ? import ../npins,
  vimPlugins,
  vimUtils,
  lib,
  pkgs,
}:
let
  inherit (vimUtils) buildVimPlugin;
  inherit (lib) substring;
  toVersion = substring 0 8;

  # Use the package from nixpkgs if available
  blink-cmp-plugin =
    pkgs.vimPlugins.blink-cmp or (buildVimPlugin {
      pname = "blink.cmp";
      version = toVersion sources.blink-cmp.revision;
      src = sources.blink-cmp;

      # Just copy the files, don't build Rust
      installPhase = ''
        runHook preInstall
        cp -r lua plugin doc $out/
        runHook postInstall
      '';
    });
in
vimPlugins.extend (
  _final: prev: {
    blink-cmp = blink-cmp-plugin.overrideAttrs (old: {
      src = sources.blink-cmp;
      version = toVersion sources.blink-cmp.revision;
    });
  }
)
