{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mnw.url = "github:Gerg-L/mnw";
    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
  };

  nixConfig = {
    commit-lockfile-summary = "chore(deps): update flake";
    extra-experimental-features = [ "pipe-operators" ];
    extra-substituters = [ "https://heitor.cachix.org" ];
    extra-trusted-public-keys = [ "heitor.cachix.org-1:IZ1ydLh73kFtdv+KfcsR4WGPkn+/I926nTGhk9O9AxI=" ];
  };

  outputs =
    {
      self,
      nixpkgs,
      mnw,
      neovim-nightly,
    }@inputs:
    let
      lib = nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems =
        function: lib.genAttrs supportedSystems (system: function nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {

        default = import ./default.nix {
          inherit mnw pkgs neovim-nightly;
          lib = pkgs.lib;
        };
        small = import ./default.nix {
          inherit pkgs mnw;
          small = true;
        };
      });
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [
            pkgs.bat
            pkgs.lolcat
            (pkgs.writeShellScriptBin "opt" ''
              npins --lock-file opt-plugins.json "$@"
            '')
            (pkgs.writeShellScriptBin "start" ''
              npins --lock-file start-plugins.json "$@"
            '')
          ];
        };
      });
    };
}
