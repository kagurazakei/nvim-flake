{
  sources ? import ../npins,
  vimPlugins,
  vimUtils,
  lib,
  rustPlatform,
}:
let
  inherit (vimUtils) buildVimPlugin;
  inherit (lib) substring;
  toVersion = substring 0 8;

  # Build the Rust component
  blink-pairs = rustPlatform.buildRustPackage {
    pname = "blink.pairs";
    version = toVersion sources.blink-pairs.revision;
    src = sources.blink-pairs;
    cargoHash = "sha256-Cn9zRsQkBwaKbBD/JEpFMBOF6CBZTDx7fQa6Aoic4YU=";

    preBuild = ''
      rm build.rs
    '';

    doCheck = false;

    postInstall = ''
      cp -r lua "$out"
      mkdir -p "$out/target"
      mv "$out/lib" "$out/target/release"
    '';

    env.RUSTC_BOOTSTRAP = true;
    forceShare = [ ];
  };
in
vimPlugins.extend (
  _final: prev: {
    blink-pairs = prev.blink-pairs.overrideAttrs (old: {
      src = sources.blink-pairs;
      version = toVersion sources.blink-pairs.revision;

      # Add the built Rust binary and Lua files
      installPhase = (old.installPhase or "") + ''
        # Copy the built Rust binary and libraries from the Rust build
        cp -r ${blink-pairs}/lib/* $out/lib/
        cp -r ${blink-pairs}/lua $out/
      '';

      # Ensure dependencies are available
      buildInputs = (old.buildInputs or [ ]) ++ [ blink-pairs ];
    });
  }
)
