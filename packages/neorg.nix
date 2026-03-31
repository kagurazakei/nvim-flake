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
  neorg-plugin =
    pkgs.vimPlugins.blink-pairs or (buildVimPlugin {
      pname = "neorg";
      version = toVersion sources.blink-pairs.revision;
      src = sources.neorg;

      # Just copy the files, don't build Rust
      installPhase = ''
        runHook preInstall
        cp -r lua plugin doc $out/
        runHook postInstall
      '';

      env.RUSTC_BOOTSTRAP = true;
    });
in
vimPlugins.extend (
  _final: prev: {
    blink-pairs = neorg-plugin.overrideAttrs (old: {
      src = sources.neorg;
      version = toVersion sources.neorg.revision;
    });
  }
)
