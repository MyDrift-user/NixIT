# GNOME home-manager configuration - dconf settings + theming
{ pkgs, lib, inputs, ... }:
{
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];

  # ── dconf (declarative GNOME settings) ────────────────────────────────
  dconf.enable = true;
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "catppuccin-mocha-mauve-standard+default";
      icon-theme = "Papirus-Dark";
      cursor-theme = "Bibata-Modern-Classic";
      font-name = "CaskaydiaCove Nerd Font 11";
      monospace-font-name = "JetBrainsMono Nerd Font 11";
    };
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
    };
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
      ];
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      natural-scroll = true;
      tap-to-click = true;
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Terminal";
      command = "foot";
      binding = "<Super>t";
    };
  };

  # ── GTK theming via home-manager ──────────────────────────────────────
  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-mauve-standard+default";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
  };

  # ── Foot (terminal) ───────────────────────────────────────────────────
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=11";
        pad  = "10x10";
        term = "xterm-256color";
      };
      colors = {
        alpha      = "0.90";
        foreground = "cdd6f4";
        background = "1e1e2e";
        regular0 = "45475a"; regular1 = "f38ba8"; regular2 = "a6e3a1"; regular3 = "f9e2af";
        regular4 = "89b4fa"; regular5 = "f5c2e7"; regular6 = "94e2d5"; regular7 = "bac2de";
        bright0  = "585b70"; bright1  = "f38ba8"; bright2  = "a6e3a1"; bright3  = "f9e2af";
        bright4  = "89b4fa"; bright5  = "f5c2e7"; bright6  = "94e2d5"; bright7  = "a6adc8";
      };
      mouse = { hide-when-typing = "yes"; };
    };
  };

  # ── Starship ──────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    settings = {
      format = lib.concatStrings [
        "[](fg:#7171ac)"
        "$os$username"
        "[](bg:#2a292e fg:#7171ac)"
        "$directory"
        "[](bg:#201f23 fg:#2a292e)"
        "$git_branch$git_status"
        "[](fg:#201f23)"
        " "
      ];
      os = {
        disabled = false;
        style    = "bg:#7171ac fg:#2a2a60";
        symbols.NixOS = " ";
      };
      username = {
        show_always = true;
        style_user  = "bg:#7171ac fg:#2a2a60";
        format      = "[ $user ]($style)";
      };
      directory = {
        style             = "bg:#2a292e fg:#c8c5d1";
        format            = "[ $path ]($style)";
        truncation_length = 3;
      };
      git_branch = {
        symbol = "";
        style  = "bg:#201f23 fg:#c8c5d1";
        format = "[ $symbol $branch ]($style)";
      };
      git_status = {
        style  = "bg:#201f23 fg:#c8c5d1";
        format = "[$all_status$ahead_behind ]($style)";
      };
      aws.disabled = true; gcloud.disabled = true; azure.disabled = true;
      docker_context.disabled = true;
    };
  };

  # ── Spicetify ─────────────────────────────────────────────────────────
  programs.spicetify =
    let spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system}; in
    {
      enable = true;
      enabledExtensions = with spicePkgs.extensions; [ adblock hidePodcasts volumePercentage ];
      theme = {
        name = "caelestia";
        src  = "${inputs.caelestia-dots-repo}/spicetify/Themes/caelestia";
        injectCss = true;
        replaceColors = true;
        overwriteAssets = true;
        sidebarConfig = true;
      };
    };

  home.packages = with pkgs; [
    bibata-cursors
    papirus-icon-theme
    nerd-fonts.caskaydia-cove
    gnome-extension-manager
  ];
}
