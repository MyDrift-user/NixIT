{ pkgs, lib, inputs, osConfig, ... }:

# Caelestia color scheme (from hypr/scheme/default.conf)
let
  c = {
    background            = "131317";
    surface               = "131317";
    surfaceContainer      = "201f23";
    surfaceContainerHigh  = "2a292e";
    surfaceContainerHighest = "353438";
    onBackground          = "e5e1e7";
    onSurface             = "e5e1e7";
    onSurfaceVariant      = "c8c5d1";
    primary               = "c2c1ff";
    onPrimary             = "2a2a60";
    primaryContainer      = "7171ac";
    outline               = "918f9a";
    outlineVariant        = "47464f";
    tertiary              = "f5b2e0";
    error                 = "ffb4ab";
    # Terminal colors
    term0 = "353434"; term1 = "ac73ff"; term2 = "44def5"; term3  = "ffdcf2";
    term4 = "99aad8"; term5 = "b49fea"; term6 = "9dceff"; term7  = "e8d3de";
    term8 = "ac9fa9"; term9 = "c093ff"; term10 = "89ecff"; term11 = "fff0f6";
    term12 = "b5c1dd"; term13 = "c9b5f4"; term14 = "bae0ff"; term15 = "ffffff";
  };
in
{
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
    inputs.caelestia-shell.homeManagerModules.default
  ];

  # ── Hyprland ─────────────────────────────────────────────────────────
  wayland.windowManager.hyprland = {
    enable         = true;
    systemd.enable = true;

    extraConfig = ''
      monitor = , preferred, auto, 1

      # ── Environment ──────────────────────────────────────────────────
      env = XCURSOR_SIZE, 24
      env = XCURSOR_THEME, Bibata-Modern-Classic
      env = HYPRCURSOR_SIZE, 24
      env = QT_QPA_PLATFORMTHEME, qt6ct
      env = QT_QPA_PLATFORM, wayland;xcb
      env = QT_WAYLAND_DISABLE_WINDOWDECORATION, 1
      env = QT_AUTO_SCREEN_SCALE_FACTOR, 1
      env = GDK_BACKEND, wayland,x11
      env = SDL_VIDEODRIVER, wayland,x11
      env = CLUTTER_BACKEND, wayland
      env = ELECTRON_OZONE_PLATFORM_HINT, auto
      env = XDG_CURRENT_DESKTOP, Hyprland
      env = XDG_SESSION_TYPE, wayland
      env = XDG_SESSION_DESKTOP, Hyprland
      env = _JAVA_AWT_WM_NONREPARENTING, 1
      env = NIXOS_OZONE_WL, 1

      # ── General (from variables.conf) ────────────────────────────────
      general {
          layout = dwindle
          allow_tearing = false
          gaps_in = 10
          gaps_out = 40
          border_size = 3
          col.active_border   = rgba(${c.primary}e6)
          col.inactive_border = rgba(${c.outlineVariant}11)
          resize_on_border = true
      }

      dwindle {
          preserve_split = true
          smart_split = false
          smart_resizing = true
      }

      # ── Decoration (from variables.conf) ─────────────────────────────
      decoration {
          rounding = 10
          active_opacity   = 1.0
          inactive_opacity = 0.95

          blur {
              enabled = true
              size = 8
              passes = 2
              new_optimizations = true
              xray = false
              ignore_opacity = true
              popups = true
          }

          shadow {
              enabled = true
              range = 20
              render_power = 3
              color = rgba(${c.surface}d4)
          }
      }

      # ── Animations (from animations.conf) ────────────────────────────
      animations {
          enabled = true

          bezier = emphasizedDecel, 0.05, 0.7, 0.1, 1
          bezier = emphasizedAccel, 0.3, 0, 0.8, 0.15
          bezier = standard, 0.2, 0, 0, 1
          bezier = specialWorkSwitch, 0.05, 0.7, 0.1, 1

          animation = layersIn,  1, 5, emphasizedDecel, slide
          animation = layersOut, 1, 4, emphasizedAccel, slide
          animation = fadeLayers, 1, 5, standard
          animation = windowsIn,  1, 5, emphasizedDecel
          animation = windowsOut, 1, 3, emphasizedAccel
          animation = windowsMove, 1, 6, standard
          animation = workspaces, 1, 5, standard
          animation = specialWorkspace, 1, 4, specialWorkSwitch, slidefadevert 15%
          animation = fade, 1, 6, standard
          animation = border, 1, 6, standard
      }

      # ── Input (from input.conf + variables.conf) ──────────────────────
      input {
          kb_layout = ch
          kb_variant = de
          numlock_by_default = false
          repeat_delay = 250
          repeat_rate = 35
          follow_mouse = 1
          sensitivity = 0

          touchpad {
              natural_scroll = true
              disable_while_typing = true
              scroll_factor = 0.3
              tap_button_map = lrm
              clickfinger_behavior = 1
          }
      }

      # Touchpad gestures (v0.53+ syntax)
      gesture = 3, horizontal, workspace

      binds {
          scroll_event_delay = 0
      }

      cursor {
          hotspot_padding = 1
      }

      # ── Misc (from misc.conf) ─────────────────────────────────────────
      misc {
          vfr = true
          vrr = 1
          disable_hyprland_logo = true
          force_default_wallpaper = 0
          animate_manual_resizes = false
          animate_mouse_windowdragging = false
          allow_session_lock_restore = true
          middle_click_paste = false
          focus_on_activate = true
          mouse_move_enables_dpms = true
          key_press_enables_dpms = true
          background_color = 0x${c.surfaceContainer}
      }

      # ── Window rules (v0.53+ syntax: match:class / match:title) ─────
      windowrule = match:class pavucontrol, float on
      windowrule = match:class pavucontrol, size 60% 70%
      windowrule = match:class pavucontrol, center on
      windowrule = match:class blueman-manager, float on
      windowrule = match:class nm-connection-editor, float on
      windowrule = match:class org.gnome.FileRoller, float on
      windowrule = match:class file-roller, float on
      windowrule = match:title (Select|Open).*(File|Folder).*, float on
      windowrule = match:title File Operation Progress, float on
      windowrule = match:title .*Properties, float on
      windowrule = match:title Save As, float on
      windowrule = match:title Picture.in.Picture, float on
      windowrule = match:title Picture.in.Picture, keep_aspect_ratio on
      windowrule = match:title Picture.in.Picture, pin on

      windowrule = match:class Spotify|feishin, workspace special:music
      windowrule = match:class discord|vesktop|equibop, workspace special:communication

      # ── Layer rules (v0.53+ syntax) ───────────────────────────────────
      layerrule = animation popin 80%, match:namespace launcher
      layerrule = blur on, match:namespace launcher
      layerrule = animation fade, match:namespace selection

      # ── Workspace rules ──────────────────────────────────────────────
      workspace = w[tv1]s[false], gapsout:20
      workspace = f[1]s[false], gapsout:20

      # ── Autostart ────────────────────────────────────────────────────
      # caelestia (bar/notifs/launcher/OSD/dashboard/wallpaper) and hypridle BOTH
      # run as systemd user services (programs.caelestia.systemd.enable=true +
      # services.hypridle) — do NOT exec-once them here or they double-start.
      exec-once = wl-paste --type text --watch cliphist store
      exec-once = wl-paste --type image --watch cliphist store
      exec-once = gnome-keyring-daemon --start --components=secrets
      exec-once = hyprctl setcursor Bibata-Modern-Classic 24

      # ── Variables ────────────────────────────────────────────────────
      $terminal    = foot
      $browser     = zen-browser
      $editor      = code
      $fileManager = thunar

      # ── Keybinds ─────────────────────────────────────────────────────
      # Apps
      bind = Super, T,      exec, $terminal
      bind = Super, W,      exec, $browser
      bind = Super, C,      exec, $editor
      bind = Super, E,      exec, $fileManager
      bind = Ctrl+Alt, V,   exec, pavucontrol

      # Launcher: fuzzel (reliable fallback). Caelestia's own launcher/dashboard
      # are toggled via its IPC — verify the drawer names against caelestia docs.
      bind = Super, Space,  exec, fuzzel
      bind = Super, A,      exec, caelestia shell drawers toggle dashboard
      bind = Super, R,      exec, caelestia shell drawers toggle launcher
      bind = Super, V,      exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy

      # Session / lock
      bind = Super, L,          exec, hyprlock
      bind = Super+Shift, L,    exec, systemctl suspend-then-hibernate
      bind = Ctrl+Alt, Delete,  exec, wlogout

      # Screenshots
      bind = , Print,        exec, grim -g "$(slurp)" - | wl-copy
      bind = Super+Shift, S, exec, grim -g "$(slurp)" - | wl-copy
      bind = Super, Print,   exec, grim - | wl-copy

      # Special workspaces
      bind = Ctrl+Shift, Escape, exec, foot -T sysmon btop
      bind = Super, M,           togglespecialworkspace, music
      bind = Super, D,           togglespecialworkspace, communication

      # Window actions
      bind = Super, Q, killactive
      bind = Super, F, fullscreen, 0
      bind = Super+Alt, F, fullscreen, 1
      bind = Super+Alt, Space, togglefloating
      bind = Super, P, pin
      bind = Ctrl+Super, Backslash, centerwindow, 1

      # Focus
      bind = Super, left,  movefocus, l
      bind = Super, right, movefocus, r
      bind = Super, up,    movefocus, u
      bind = Super, down,  movefocus, d

      # Move windows
      bind = Super+Shift, left,  movewindow, l
      bind = Super+Shift, right, movewindow, r
      bind = Super+Shift, up,    movewindow, u
      bind = Super+Shift, down,  movewindow, d

      # Resize
      binde = Super, Minus, splitratio, -0.1
      binde = Super, Equal, splitratio, 0.1

      # Mouse
      bindm = Super, mouse:272, movewindow
      bindm = Super, mouse:273, resizewindow
      bind = Super, mouse_down, workspace, -1
      bind = Super, mouse_up,   workspace, +1

      # Workspaces (Super + number)
      bind = Super, 1, workspace, 1
      bind = Super, 2, workspace, 2
      bind = Super, 3, workspace, 3
      bind = Super, 4, workspace, 4
      bind = Super, 5, workspace, 5
      bind = Super, 6, workspace, 6
      bind = Super, 7, workspace, 7
      bind = Super, 8, workspace, 8
      bind = Super, 9, workspace, 9
      bind = Super, 0, workspace, 10

      # Move window to workspace (Super+Alt + number)
      bind = Super+Alt, 1, movetoworkspace, 1
      bind = Super+Alt, 2, movetoworkspace, 2
      bind = Super+Alt, 3, movetoworkspace, 3
      bind = Super+Alt, 4, movetoworkspace, 4
      bind = Super+Alt, 5, movetoworkspace, 5
      bind = Super+Alt, 6, movetoworkspace, 6
      bind = Super+Alt, 7, movetoworkspace, 7
      bind = Super+Alt, 8, movetoworkspace, 8
      bind = Super+Alt, 9, movetoworkspace, 9
      bind = Super+Alt, 0, movetoworkspace, 10

      # Navigate workspaces
      binde = Ctrl+Super, right, workspace, +1
      binde = Ctrl+Super, left,  workspace, -1

      # Scratchpad
      bind = Super, S, togglespecialworkspace, special
      bind = Super+Alt, S, movetoworkspace, special:special

      # Media / volume / brightness
      bindl  = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindl  = Super+Shift, M,         exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindle = , XF86AudioRaiseVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+
      bindle = , XF86AudioLowerVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-
      bindl  = , XF86AudioPlay,  exec, playerctl play-pause
      bindl  = Ctrl+Super, Space, exec, playerctl play-pause
      bindl  = , XF86AudioNext,  exec, playerctl next
      bindl  = Ctrl+Super, Equal, exec, playerctl next
      bindl  = , XF86AudioPrev,  exec, playerctl previous
      bindl  = Ctrl+Super, Minus, exec, playerctl previous
      bindle = , XF86MonBrightnessUp,   exec, brightnessctl s 5%+
      bindle = , XF86MonBrightnessDown, exec, brightnessctl s 5%-

      # Colour picker
      bind = Super+Shift, C, exec, hyprpicker -a
    '';
  };

  # ── Caelestia shell — QuickShell rice (bar, notifications, launcher, OSD,
  #    dashboard, wallpaper). Replaces waybar + mako + hyprpaper below.
  #    Set a wallpaper after first login:  caelestia wallpaper -f ~/Pictures/wall.png
  programs.caelestia = {
    enable     = true;
    cli.enable = true;          # `caelestia` CLI on PATH (IPC used by keybinds)
    # settings = { ... };       # full schema: github:caelestia-dots/shell
  };

  # ── Waybar (disabled — caelestia provides the bar) ──────────────────
  programs.waybar = {
    enable = false;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 36;
      modules-left   = [ "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right  = [ "pulseaudio" "network" "battery" "tray" ];

      "hyprland/workspaces" = {
        format = "{icon}";
        on-click = "activate";
      };
      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%A, %d %B %Y}";
        tooltip-format = "<tt>{calendar}</tt>";
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = " muted";
        format-icons.default = [ "" "" "" ];
        on-click = "pavucontrol";
      };
      network = {
        format-wifi = "  {essid}";
        format-ethernet = "  {ifname}";
        format-disconnected = "  disconnected";
      };
      battery = {
        format = "{icon} {capacity}%";
        format-icons = [ "" "" "" "" "" ];
      };
      tray = { spacing = 8; };
    };
    style = ''
      * {
        font-family: "CaskaydiaCove Nerd Font";
        font-size: 13px;
        min-height: 0;
      }
      window#waybar {
        background: rgba(32, 31, 35, 0.9);
        color: #${c.onBackground};
        border-bottom: 2px solid rgba(${c.outlineVariant}, 0.3);
      }
      #workspaces button {
        padding: 0 8px;
        color: #${c.onSurfaceVariant};
        border-bottom: 3px solid transparent;
      }
      #workspaces button.active {
        color: #${c.primary};
        border-bottom: 3px solid #${c.primary};
      }
      #clock, #pulseaudio, #network, #battery, #tray {
        padding: 0 12px;
        color: #${c.onSurfaceVariant};
      }
    '';
  };

  # ── Mako (disabled — caelestia provides notifications) ────────────
  services.mako = {
    enable = false;
    settings = {
      font = "CaskaydiaCove Nerd Font 11";
      background-color = "#${c.surfaceContainer}ee";
      text-color = "#${c.onSurface}";
      border-color = "#${c.outlineVariant}";
      border-size = 2;
      border-radius = 12;
      padding = "12";
      default-timeout = 5000;
      max-visible = 3;
      layer = "overlay";
    };
  };

  # ── Foot (terminal) ───────────────────────────────────────────────
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=11";
        pad  = "10x10";
        term = "xterm-256color";
      };
      colors = {
        alpha      = "0.85";
        foreground = c.onBackground;
        background = c.background;
        regular0  = c.term0;  regular1 = c.term1;  regular2  = c.term2;  regular3  = c.term3;
        regular4  = c.term4;  regular5 = c.term5;  regular6  = c.term6;  regular7  = c.term7;
        bright0   = c.term8;  bright1  = c.term9;  bright2   = c.term10; bright3   = c.term11;
        bright4   = c.term12; bright5  = c.term13; bright6   = c.term14; bright7   = c.term15;
      };
      mouse = { hide-when-typing = "yes"; };
    };
  };

  # ── Hyprlock ──────────────────────────────────────────────────────
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = false;
        hide_cursor         = true;
        grace               = 0;
      };
      background = [{
        monitor     = "";
        path        = "screenshot";
        blur_passes = 3;
        blur_size   = 8;
        brightness  = 0.6;
        contrast    = 1.0;
        vibrancy    = 0.2;
      }];
      label = [
        {
          monitor     = "";
          text        = ''cmd[update:1000] echo "$(date +"%H:%M")"'';
          color       = "rgba(${c.onBackground}ff)";
          font_size   = 96;
          font_family = "CaskaydiaCove Nerd Font Bold";
          position    = "0, 220";
          halign      = "center";
          valign      = "center";
        }
        {
          monitor     = "";
          text        = ''cmd[update:60000] echo "$(date +"%A, %d %B %Y")"'';
          color       = "rgba(${c.onSurfaceVariant}ff)";
          font_size   = 22;
          font_family = "CaskaydiaCove Nerd Font";
          position    = "0, 110";
          halign      = "center";
          valign      = "center";
        }
      ];
      input-field = [{
        monitor           = "";
        size              = "320, 55";
        outline_thickness = 2;
        dots_size         = 0.25;
        dots_spacing      = 0.35;
        dots_center       = true;
        dots_rounding     = -1;
        outer_color       = "rgba(${c.primary}cc)";
        inner_color       = "rgba(${c.surfaceContainerHigh}ee)";
        font_color        = "rgba(${c.onSurface}ff)";
        fade_on_empty     = false;
        placeholder_text  = ''<span foreground="##${c.outline}">Password...</span>'';
        check_color       = "rgba(${c.primary}ff)";
        fail_color        = "rgba(${c.error}ff)";
        fail_text         = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
        position          = "0, -80";
        halign            = "center";
        valign            = "center";
        rounding          = 12;
      }];
    };
  };

  # ── Hypridle ──────────────────────────────────────────────────────
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd         = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd  = "hyprctl dispatch dpms on";
      };
      listener = [
        { timeout = 300; on-timeout = "hyprlock"; }
      ]
      # DPMS-off freezes the virtio-GPU on the Sunshine streaming VM (the guest
      # hangs with "Display output is not active"), and a blanked display has
      # nothing to stream anyway — so skip it when this host streams via Sunshine.
      ++ lib.optionals (!(osConfig.services.sunshine.enable or false)) [
        { timeout = 600; on-timeout = "hyprctl dispatch dpms off"; on-resume = "hyprctl dispatch dpms on"; }
      ];
    };
  };

  # ── Hyprpaper (disabled — caelestia manages the wallpaper) ────────
  services.hyprpaper = {
    enable = false;
    settings = {
      preload   = [];
      wallpaper = [];
      splash    = false;
    };
  };

  # ── Starship (prompt) ─────────────────────────────────────────────
  programs.starship = {
    enable = true;
    settings = {
      format = lib.concatStrings [
        "[](fg:#${c.primaryContainer})"
        "$os$username"
        "[](bg:#${c.surfaceContainerHigh} fg:#${c.primaryContainer})"
        "$directory"
        "[](bg:#${c.surfaceContainer} fg:#${c.surfaceContainerHigh})"
        "$git_branch$git_status"
        "[](fg:#${c.surfaceContainer})"
        " "
      ];
      os = {
        disabled = false;
        style    = "bg:#${c.primaryContainer} fg:#${c.onPrimary}";
        symbols.NixOS = " ";
      };
      username = {
        show_always = true;
        style_user  = "bg:#${c.primaryContainer} fg:#${c.onPrimary}";
        format      = "[ $user ]($style)";
      };
      directory = {
        style             = "bg:#${c.surfaceContainerHigh} fg:#${c.onSurfaceVariant}";
        format            = "[ $path ]($style)";
        truncation_length = 3;
        substitutions     = { Documents = " "; Downloads = " "; Music = " "; Pictures = " "; };
      };
      git_branch = {
        symbol = "";
        style  = "bg:#${c.surfaceContainer} fg:#${c.onSurfaceVariant}";
        format = "[ $symbol $branch ]($style)";
      };
      git_status = {
        style  = "bg:#${c.surfaceContainer} fg:#${c.onSurfaceVariant}";
        format = "[$all_status$ahead_behind ]($style)";
      };
      nix_shell = {
        symbol = " ";
        style  = "bold fg:#${c.primary}";
        format = "[$symbol$state]($style) ";
      };
      cmd_duration = {
        min_time = 2000;
        style    = "fg:#${c.outline}";
        format   = "[󱎫 $duration]($style) ";
      };
      aws.disabled = true; gcloud.disabled = true; azure.disabled = true;
      docker_context.disabled = true;
    };
  };

  # ── Fuzzel (launcher) ─────────────────────────────────────────────
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font          = "CaskaydiaCove Nerd Font:size=12";
        prompt        = "  ";
        layer         = "overlay";
        terminal      = "foot";
        width         = 45;
        lines         = 12;
        horizontal-pad = 20;
        vertical-pad  = 12;
        inner-pad     = 8;
        icon-theme    = "Papirus-Dark";
        icons-enabled = true;
      };
      colors = {
        background      = "${c.surfaceContainer}ee";
        text            = "${c.onSurface}ff";
        match           = "${c.primary}ff";
        selection       = "${c.surfaceContainerHigh}ff";
        selection-text  = "${c.onSurface}ff";
        selection-match = "${c.primary}ff";
        border          = "${c.outlineVariant}cc";
      };
      border = { width = 1; radius = 14; };
    };
  };

  # ── Spicetify ─────────────────────────────────────────────────────
  programs.spicetify =
    let
      spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
    in
    {
      enable = true;
      enabledExtensions = with spicePkgs.extensions; [
        adblock
        hidePodcasts
        volumePercentage
      ];
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
    cliphist
    bibata-cursors
    papirus-icon-theme
    nerd-fonts.caskaydia-cove
    material-symbols
    brightnessctl
    hyprpicker
    wlogout
  ];
}
