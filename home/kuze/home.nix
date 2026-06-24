# Home Manager configuration for kuze
# Colors/style ported from caelestia-dots (Material Design 3 scheme)
{ pkgs, lib, inputs, osConfig, desktopEnvironment ? "hyprland", ... }:

{
  imports = [
    ../../modules/wm/${desktopEnvironment}/home.nix
  ];

  home.username      = "kuze";
  home.homeDirectory = "/home/kuze";
  home.stateVersion  = "25.11";

  programs.home-manager.enable = true;


  # ── Packages ─────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    fastfetch
    eza
    jq
    nerd-fonts.jetbrains-mono
    equibop
    inputs.zen-browser.packages.${pkgs.system}.default
    btop
  ];

  # ── Git ──────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {
      user.name  = "mydrift-user";
      user.email = "contact@mydrift.dev";
      init.defaultBranch   = "main";
      pull.rebase          = true;
      push.autoSetupRemote = true;
    };
  };

  # ── VS Code ─────────────────────────────────────────────────────────
  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        vscodevim.vim
        jnoortheen.nix-ide
        catppuccin.catppuccin-vsc
        catppuccin.catppuccin-vsc-icons
      ];
      userSettings = builtins.fromJSON (builtins.readFile "${inputs.caelestia-dots-repo}/vscode/settings.json");
      keybindings = builtins.fromJSON (builtins.readFile "${inputs.caelestia-dots-repo}/vscode/keybindings.json");
    };
  };

  # ── Zen Browser ──────────────────────────────────────────────────────
  home.file.".zen/chrome/userChrome.css".source = "${inputs.caelestia-dots-repo}/zen/userChrome.css";

  # ── Session variables ───────────────────────────────────────────────
  home.sessionVariables = {
    EDITOR   = "nano";
    TERMINAL = "foot";
  };
}
