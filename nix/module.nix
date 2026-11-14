# The NixOS module: what the installer's stages do to the system, as
# configuration. programs.vitrum.enable brings the session, the login screen,
# the services the shell talks to, the fonts and the rules; each user's own
# files (settings, the niri config, the themes of the terminal and the
# toolkits) stay ordinary files in their home, made at login by vitrum-setup.
{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optionals
    types
    ;

  cfg = config.programs.vitrum;
  system = pkgs.stdenv.hostPlatform.system;
  flakePackages = self.packages.${system};
  # The same expressions over this system's nixpkgs: what depends on its
  # configuration (the greeter's layouts) or on its say (an unfree font).
  local = import ./packages.nix {
    inherit pkgs;
    niriFlake = self.inputs.niri;
    root = ../.;
  };

  # The package with this system's choices in it.
  vitrum = cfg.package.override { inherit (cfg) adminGroup; };
  rt = vitrum.runtimePackages;

  # An optional part of the installer (lib/components.sh), on unless said otherwise.
  part =
    default: what:
    mkOption {
      type = types.bool;
      inherit default;
      description = "Whether to install ${what}.";
    };

  onOff = b: if b then "1" else "0";

  xkb = config.services.xserver.xkb;
  nvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
{
  options.programs.vitrum = {
    enable = mkEnableOption "the vitrum desktop: its shell on niri with vitrum's glass, as a session of its own";

    package = mkOption {
      type = types.package;
      default = flakePackages.vitrum;
      defaultText = lib.literalExpression "inputs.vitrum.packages.\${system}.vitrum";
      description = ''
        The vitrum package. niri and Quickshell come with it
        (`package.niri`, `package.quickshell`); to build them from your own
        nixpkgs instead of the flake's, let the flake's nixpkgs follow yours.
      '';
    };

    adminGroup = mkOption {
      type = types.str;
      default = "wheel";
      description = ''
        The group whose members may run vitrum's root helper without a
        password from a local, active session (WireGuard up and down, disk
        health, the login screen's copy of your wallpaper), and mount and
        eject drives in Disk Utility.
      '';
    };

    sddm.enable = part true "the login screen (SDDM with vitrum's theme, on niri)";
    plymouth.enable = part false "the boot splash (Plymouth with vitrum's theme)";
    inputMethod.enable = part false "Japanese, Korean and Chinese input (fcitx5 with Mozc, Hangul and Pinyin)";
    liveWallpaper.enable = part true "video wallpapers (mpvpaper)";
    phone.enable = part false "KDE Connect";
    tmux.enable = part true "tmux, themed";
    games.enable = part true "game mode and the HUD (gamemode, MangoHud)";
    utilities.enable = part true "the mic noise filter, VPN tools, sensors, a mixer and archives";
    cliTools.enable = part true "eza, bat, fzf, zoxide and delta";
    fileManager.enable = part true "Dolphin";
    ocr.enable = part true "text from screenshots (tesseract)";
    vesktopTheme.enable = part true "vitrum's look for Vesktop (applied with `vitrum-vesktop-theme install`)";

    appleEmoji.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to install Apple Color Emoji, which the installer fetches on
        other distributions. The font is Apple's and is not free to
        redistribute, so it is off here and Noto Color Emoji is used. Turning
        it on needs `nixpkgs.config.allowUnfree` (or a predicate that allows
        `vitrum-apple-color-emoji`).
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # ------------------------------------------------------- packages -----

      environment.systemPackages =
        [
          vitrum
          vitrum.niri
          vitrum.quickshell
        ]
        ++ rt.required
        ++ optionals cfg.liveWallpaper.enable rt.liveWallpaper
        ++ optionals cfg.tmux.enable rt.tmux
        ++ optionals cfg.games.enable rt.games
        ++ optionals cfg.utilities.enable rt.utilities
        ++ optionals cfg.cliTools.enable rt.cliTools
        ++ optionals cfg.fileManager.enable rt.fileManager
        ++ optionals cfg.ocr.enable rt.ocr;

      # What the shell and the tools look up through XDG_DATA_DIRS: keyboard
      # layouts, sounds, themes, icons, Kvantum themes.
      environment.pathsToLink = [
        "/share/X11/xkb"
        "/share/sounds"
        "/share/themes"
        "/share/icons"
        "/share/Kvantum"
      ];

      # Where the code looks for its own helpers, and how it knows it is not a
      # git checkout (no `vitrum update`: the flake input is the update).
      environment.sessionVariables = {
        VITRUM_LIBEXEC = "${vitrum}/libexec/vitrum";
        VITRUM_MANAGED = "nix";
        VITRUM_VERSION = vitrum.version;
      }
      // lib.optionalAttrs cfg.utilities.enable {
        # The mic noise filter (rnnoise), for PipeWire's filter chain.
        LADSPA_PATH = "${pkgs.rnnoise-plugin}/lib/ladspa";
      };

      # The optional parts as vitrum-setup records them in each user's
      # components.json, which vitrum-theme and vitrum-im go by. The Steam
      # theme needs Millennium, which patches Steam's own files: not on NixOS.
      environment.etc."vitrum/setup.env".text = ''
        WANT_SDDM=${onOff cfg.sddm.enable}
        WANT_PLYMOUTH=${onOff cfg.plymouth.enable}
        WANT_LIVE_WALLPAPER=${onOff cfg.liveWallpaper.enable}
        WANT_PHONE=${onOff cfg.phone.enable}
        WANT_INPUT_METHOD=${onOff cfg.inputMethod.enable}
        WANT_TMUX=${onOff cfg.tmux.enable}
        WANT_GAMES=${onOff cfg.games.enable}
        WANT_STEAM_THEME=0
        WANT_VESKTOP_THEME=${onOff cfg.vesktopTheme.enable}
        WANT_UTILITIES=${onOff cfg.utilities.enable}
        WANT_CLI_TOOLS=${onOff cfg.cliTools.enable}
        WANT_FILE_MANAGER=${onOff cfg.fileManager.enable}
        WANT_OCR=${onOff cfg.ocr.enable}
      '';

      # -------------------------------------------------------- session -----

      # The login entry (vitrum.desktop → vitrum-session), niri as the user
      # unit the wrapper starts, the screen-sharing backend on the session bus.
      services.displayManager.sessionPackages = [ vitrum ];
      services.displayManager.defaultSession = mkDefault "vitrum";
      systemd.packages = [ vitrum ];
      services.dbus.packages = [ vitrum ];

      # niri-portals.conf, as the session stage writes it: GTK for everything,
      # vitrum's own backend (the shell's picker) for screen sharing.
      xdg.portal = {
        enable = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-gtk
          vitrum
        ];
        config.niri = {
          default = [ "gtk" ];
          "org.freedesktop.impl.portal.ScreenCast" = [ "vitrum" ];
        };
      };

      # The root helper (keyed on its store path) and Disk Utility.
      security.polkit.enable = true;
      environment.etc."polkit-1/rules.d/50-vitrum.rules".source =
        "${vitrum}/share/polkit-1/rules.d/50-vitrum.rules";
      environment.etc."polkit-1/rules.d/49-vitrum-disks.rules".source =
        "${vitrum}/share/polkit-1/rules.d/49-vitrum-disks.rules";

      # Each user's picture and palette for the login screen, copied there by
      # the root helper (vitrum-root login-sync).
      systemd.tmpfiles.rules = [
        "d /var/lib/vitrum 0755 root root -"
        "d /var/lib/vitrum/login 0755 root root -"
      ];

      # ------------------------------------------------------- services -----
      #
      # What the shell talks to. Defaults, so a system that already decides
      # these (another audio setup, TLP in place of power-profiles-daemon)
      # keeps its own.

      hardware.graphics.enable = mkDefault true;
      security.rtkit.enable = mkDefault true;
      services.pipewire = {
        enable = mkDefault true;
        alsa.enable = mkDefault true;
        pulse.enable = mkDefault true;
        wireplumber.enable = mkDefault true;
      };
      hardware.bluetooth.enable = mkDefault true;
      networking.networkmanager.enable = mkDefault true;
      services.upower.enable = mkDefault true;
      services.power-profiles-daemon.enable = mkDefault true;
      services.udisks2.enable = mkDefault true;
      programs.dconf.enable = mkDefault true;
      # QT_PLUGIN_PATH over the profiles: Qt applications find qt6ct (the
      # session's platform theme) and Kvantum (its style) there.
      qt.enable = mkDefault true;
      programs.fish.enable = mkDefault true;
      # The launcher's file search.
      services.locate = {
        enable = mkDefault true;
        package = mkDefault pkgs.plocate;
      };

      # The password store, opened with the login password.
      services.gnome.gnome-keyring.enable = mkDefault true;
      security.pam.services.login.enableGnomeKeyring = mkDefault true;

      # ---------------------------------------------------------- fonts -----

      fonts.packages =
        [
          pkgs.inter
          pkgs.jetbrains-mono
          pkgs.nerd-fonts.jetbrains-mono
          pkgs.nerd-fonts.symbols-only
          pkgs.noto-fonts
          pkgs.noto-fonts-cjk-sans
          pkgs.noto-fonts-color-emoji
          vitrum.phosphor-fonts
        ]
        ++ optionals cfg.appleEmoji.enable [ local.apple-emoji ];
    }

    # ---------------------------------------------------- login screen -----

    (mkIf cfg.sddm.enable {
      services.displayManager.sddm = {
        enable = true;
        # The greeter on niri (Wayland), as the boot stage sets it up: SDDM's X
        # server, restarted after a Wayland session on NVIDIA, can hang.
        wayland.enable = true;
        theme = "vitrum";
        # The theme's pictures: your wallpaper may be a WebP, the mark an SVG.
        extraPackages = [
          pkgs.kdePackages.qtimageformats
          pkgs.kdePackages.qtsvg
        ];
        settings = {
          # QML_XHR_ALLOW_FILE_READ: the theme reads the picked user's folder
          # in /var/lib/vitrum/login (wallpaper times, palette).
          General.GreeterEnvironment = "QT_WAYLAND_DISABLE_WINDOWDECORATION=1,QML_XHR_ALLOW_FILE_READ=1";
          Wayland.CompositorCommand = "${vitrum.niri}/bin/niri -c ${
            local.lib.mkGreeterConfig {
              inherit (xkb) layout variant options;
            }
          }";
        };
      };
      environment.systemPackages = [ flakePackages.vitrum-sddm-theme ];
      security.pam.services.sddm.enableGnomeKeyring = mkDefault true;
    })

    # ----------------------------------------------------- boot splash -----

    (mkIf cfg.plymouth.enable {
      boot.plymouth = {
        enable = true;
        theme = "vitrum";
        themePackages = [ flakePackages.vitrum-plymouth-theme ];
      };
      # The splash needs a quiet kernel.
      boot.kernelParams = [ "quiet" ];
    })

    # ---------------------------------------------------- input method -----

    (mkIf cfg.inputMethod.enable {
      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5 = {
          waylandFrontend = true;
          addons = [
            pkgs.fcitx5-mozc
            pkgs.fcitx5-hangul
            pkgs.qt6Packages.fcitx5-chinese-addons
            pkgs.fcitx5-gtk
          ];
        };
      };
    })

    # ------------------------------------------------------------ parts -----

    (mkIf cfg.games.enable {
      programs.gamemode.enable = mkDefault true;
    })

    (mkIf cfg.phone.enable {
      programs.kdeconnect.enable = mkDefault true;
    })

    # ----------------------------------------------------------- NVIDIA -----

    # The driver keeps freed video memory for reuse, and a compositor frees a
    # lot: the free buffer pool is limited for niri and the shell (the fix
    # niri's wiki gives), as the session stage does where the module is loaded.
    (mkIf nvidia {
      environment.etc."nvidia/nvidia-application-profiles-rc.d/50-vitrum-compositor.json".source =
        "${vitrum}/share/vitrum/system/nvidia-application-profile.json";
      hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];
    })
  ]);
}
