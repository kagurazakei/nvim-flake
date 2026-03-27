{
  pkgs,
  mnw,
  lib,
  dev ? false,
  sources ? import ./npins,
}:
let
  appName = "nvim-zakei";
  initLua = ./nvim/init.lua;
  vimPlugins-cmp = pkgs.callPackage ./packages/blink-pair.nix { inherit sources; };
  vimPlugins-pairs = pkgs.callPackage ./packages/blink-cmp.nix { inherit sources; };
  externalTools = {
    inherit (pkgs) curl ripgrep imagemagick;
  }
  // lib.optionalAttrs (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.wayland) {
    inherit (pkgs) wl-clipboard;
  };

  formatters = {
    gdscript = pkgs.gdtoolkit_4;
    lua = pkgs.stylua;
    nix = pkgs.nixfmt;
    toml = pkgs.taplo;
    kdl = pkgs.kdlfmt;
    hyprls = pkgs.hyprls;
  };

  languageServers = {
    lua = pkgs.lua-language-server;
    nix = pkgs.nixd;
    toml = pkgs.taplo;
    hyprls = pkgs.hyprls;
  };

  pluginDependencies = {
    fzf-lua = pkgs.fzf;
    cat = pkgs.bat;
  };

  extraBinPath =
    [
      formatters
      languageServers
      pluginDependencies
      externalTools
    ]
    |> builtins.concatMap builtins.attrValues
    |> lib.flatten
    |> lib.unique;

in

mnw.lib.wrap pkgs {
  inherit appName;
  neovim = pkgs.neovim.unwrapped.overrideAttrs (old: {
    version = "nightly";
    src = sources.neovim;
    doInstallCheck = false;
  });
  luaFiles = [
    initLua
  ];
  plugins = {
    dev.config = {
      impure = "~/Projects/nvim-flake";
      pure = lib.fileset.toSource {
        root = ./nvim;
        fileset = lib.fileset.unions [
          ./nvim/after
          ./nvim/lua
          ./nvim/lsp
          initLua
        ];
      };
    };

    optAttrs = mnw.lib.npinsToPluginsAttrs pkgs ./opt-plugins.json // {
      # "blink.nix" = pkgs.vimPlugins.blink-cmp-nixpkgs-maintainers;
      "cord.nvim" = pkgs.vimPlugins.cord-nvim;
      "hyprlang" = pkgs.vimPlugins.nvim-treesitter-parsers.hyprlang;
      "blink.cmp" = vimPlugins-cmp.blink-cmp;
      "blink.pairs" = vimPlugins-pairs.blink-pairs;
      "catppuccin-nvim" = pkgs.vimPlugins.catppuccin-nvim;
      "base16-nvim" = pkgs.vimPlugins.base16-nvim;
    };
    startAttrs = mnw.lib.npinsToPluginsAttrs pkgs ./start-plugins.json // {
      inherit (pkgs.vimPlugins) nvim-treesitter;
    };

    start =
      let
        langs = [
          "bash"
          "comment"
          "diff"
          "json"
          "just"
          "markdown"
          "nix"
          "query"
          "regex"
          "toml"
          "yaml"
          "zsh"
          "kdl"
        ]
        ++ [
          "git_config"
          "git_rebase"
          "gitattributes"
          "gitcommit"
          "gitignore"
          "gdscript"
          "gdshader"
          "godot_resource"
          "lua"
          "luadoc"
          "luap"
          "vim"
          "vimdoc"
        ];
      in
      langs
      |> builtins.concatMap (lang: [
        pkgs.vimPlugins.nvim-treesitter.parsers.${lang}
        pkgs.vimPlugins.nvim-treesitter.queries.${lang}
      ]);
  };

  providers = {
    nodeJs.enable = false;
    perl.enable = false;
    python3.enable = false;
    ruby.enable = false;
  };

  extraBinPath =
    extraBinPath
    ++ (with pkgs; [
      fzf
      git
      bat
      lolcat
      fish-lsp
      fd
      shfmt
      hyprls
    ]);

  wrapperArgs = [
    "--set"
    "NEOVIM_CONFIG"
    (
      if dev then
        "~/Projects/nvim-flake"
      else
        (lib.fileset.toSource {
          root = ./nvim;
          fileset = lib.fileset.unions [
            ./nvim/after
            ./nvim/lua
            initLua
          ];
        }).outPath
    )
  ];

  extraBuilderArgs = {
    doInstallCheck = !dev;

    installCheckPhase = ''
      runHook preInstallCheck

      mkdir -p .cache/${appName}
      output=$(HOME=$(realpath .) $out/bin/nvim -mn --headless "+q" 2>&1 >/dev/null)
      if [[ -n $output ]]; then
        echo "ERROR: $output"
        exit 1
      fi

      runHook postInstallCheck
    '';

  };
}
