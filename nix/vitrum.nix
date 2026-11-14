# The vitrum package: the shell, the apps, the tools, the templates, and the
# session that starts them on niri.
#
#   $out/share/vitrum/   the repository's own layout (shell, apps, tools, config,
#                        lib, assets): the apps' links into ../../shell hold,
#                        and vitrum-setup runs the installer's stages from lib
#   $out/bin/            every command, wrapped: the tools, the launchers
#                        (vitrum-shell, vitrum-ipc, vitrum-startup, the apps),
#                        vitrum-session and vitrum-setup
#   $out/libexec/vitrum/ vitrum-root (pkexec) and vitrum-portal (D-Bus)
#   $out/share/…         the login entry, the portal, the D-Bus service, the
#                        desktop entries, the polkit rules
#   $out/lib/systemd/user/niri.service
#
# The files the installer writes as text (the wrapper, the launchers, the
# rules) are written here by the same stage functions, into a throwaway root
# (nix/stage-env.sh), then pointed at the store.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  wrapGAppsNoGuiHook,
  gobject-introspection,
  python3,
  bash,
  rsync,
  jq,
  # the session
  niri,
  quickshell,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  # GStreamer for vitrum-thumbs and vitrum-portal (window pictures from PipeWire)
  gst_all_1,
  pipewire,
  # what vitrum-root runs, as root
  coreutils,
  util-linux,
  gawk,
  gnused,
  gnugrep,
  wireguard-tools,
  smartmontools,
  # everything the shell, the tools and vitrum-setup call by name
  pkgs,
  phosphor-fonts,
  bibata-cursor,
  src,
  version,
  # Who may run vitrum-root without a password, from a local, active session.
  # The installer names the one user who installed; a system's configuration
  # names a group.
  adminGroup ? "wheel",
  # The VT the login screen runs on (SDDM's MinimumVT): the session wrapper
  # switches back to it when the session ends.
  greeterVt ? 1,
}:
let
  pythonEnv = python3.withPackages (ps: [
    ps.dbus-python
    ps.pygobject3
    ps.pillow
  ]);

  # lib/packages.tsv's "required" rows, as nixpkgs names them. Libraries and
  # build tools are left out (the store has them where they are needed);
  # services (PipeWire, NetworkManager, BlueZ, UPower…) are the module's, here
  # are their command-line tools.
  required = with pkgs; [
    bash
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    util-linux
    procps
    gnutar
    gzip
    git
    pythonEnv
    fontconfig
    glib # gsettings, gdbus, gio
    dbus
    libsecret
    pipewire
    wireplumber
    pulseaudio # pactl
    networkmanager
    bluez
    upower
    power-profiles-daemon
    brightnessctl
    playerctl
    polkit
    xdg-user-dirs
    xdg-utils
    udisks2
    grim
    slurp
    wl-clipboard
    wl-mirror
    cliphist
    libnotify
    jq
    socat
    curl
    wget
    imagemagick
    librsvg
    ffmpeg
    ffmpegthumbnailer
    poppler-utils
    plocate
    fd
    ripgrep
    bc
    satty
    gpu-screen-recorder
    wf-recorder
    matugen
    awww
    xwayland-satellite
    kitty
    fish
    starship
    fastfetch
    kdePackages.qtstyleplugin-kvantum
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qt6ct
    libsForQt5.qt5ct
    adw-gtk3
    papirus-icon-theme
    sound-theme-freedesktop
    xkeyboard-config
    unzip
    xz
    _7zz
    bibata-cursor
  ];

  # The optional parts (lib/components.sh), by the module's option names.
  optional = with pkgs; {
    liveWallpaper = [
      mpvpaper
      mpv
    ];
    phone = [ kdePackages.kdeconnect-kde ];
    tmux = [
      tmux
      xsel
    ];
    games = [
      gamemode
      mangohud
    ];
    utilities = [
      rnnoise-plugin
      cava
      pavucontrol
      kdePackages.ark
      wireguard-tools
      smartmontools
      lm_sensors
    ];
    cliTools = [
      eza
      bat
      fzf
      zoxide
      delta
    ];
    fileManager = [ kdePackages.dolphin ];
    ocr = [ tesseract ];
  };

  # PATH for the wrapped commands, after the caller's own: the session's PATH
  # (the system profile, where the module puts the same packages) comes first,
  # and these are there when a command runs without one, as a D-Bus activated
  # vitrum-portal does.
  runtimePath = lib.makeBinPath required;

  # vitrum-root runs as root through pkexec: its PATH is fixed here, at build
  # time, and nothing of the caller's environment decides what it runs.
  rootPath = lib.makeBinPath [
    coreutils
    util-linux
    gawk
    gnused
    gnugrep
    wireguard-tools
    smartmontools
    python3
    bash
  ];

  # gsettings finds its schemas through XDG_DATA_DIRS; NixOS has no global
  # place for them, so the session carries these.
  schemaDirs = lib.concatMapStringsSep ":" (p: "${p}/share/gsettings-schemas/${p.name}") [
    gsettings-desktop-schemas
    gtk3
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "vitrum";
  inherit version src;

  nativeBuildInputs = [
    makeWrapper
    wrapGAppsNoGuiHook
    gobject-introspection
    pythonEnv
    rsync
    jq
  ];
  buildInputs = [
    bash
    pythonEnv
    glib
    gobject-introspection
    gsettings-desktop-schemas
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    pipewire
  ];

  # The wrappers are made by hand below, with the GObject paths the hook collects.
  dontWrapGApps = true;
  dontConfigure = true;

  # The installer's own check: a shell that cannot load is not packaged.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python3 lib/check-qml.py shell apps/settings apps/disks apps/about
    runHook postCheck
  '';

  buildPhase = ''
    runHook preBuild

    export VITRUM_DIR=$PWD VITRUM_NIX_ROOT=$TMPDIR/root
    (
      source nix/stage-env.sh
      INIT_BACKEND=systemd
      source lib/backend/init-systemd.sh
      source lib/stages/40-shell.sh
      source lib/stages/50-apps.sh
      source lib/stages/80-session.sh

      # Quickshell's command is qs; the launchers get its store path below.
      have() { [[ "$1" == qs ]] || command -v "$1" >/dev/null 2>&1; }

      # The login screen's VT, read by the wrapper's stage from SDDM's config.
      mkdir -p "$VITRUM_SYSROOT/etc"
      printf '[General]\nMinimumVT=%s\n' ${toString greeterVt} > "$VITRUM_SYSROOT/etc/sddm.conf"

      _session_wrapper          # vitrum-session, vitrum.desktop
      session_unit_install      # niri.service
      _session_startup_script   # vitrum-startup
      _session_screencast       # vitrum-portal, its portal and D-Bus service files
      _session_root_helper      # vitrum-root and its polkit rule
      # The NVIDIA profile is written only where the module is loaded; here it
      # is always made, and the NixOS module installs it where the driver is.
      ( grep() { [[ "$*" == *"/proc/modules"* ]] || command grep "$@"; }; _session_nvidia_profile )
      _shell_launchers          # vitrum-shell, vitrum-ipc
      for entry in "''${APPS[@]}"; do
        IFS='|' read -r name display icon cats <<<"$entry"
        _app_install "$name" "$display" "$icon" "$cats" qs
      done
      _apps_polkit              # Disk Utility's rule

      r="$VITRUM_SYSROOT" b="$HOME/.local/bin" o=$out
      need_file "$r/usr/local/bin/vitrum-session" "$r/usr/local/share/wayland-sessions/vitrum.desktop" \
        "$r/etc/systemd/user/niri.service" "$r/usr/local/libexec/vitrum/vitrum-root" \
        "$r/usr/local/libexec/vitrum/vitrum-portal" "$r/usr/share/xdg-desktop-portal/portals/vitrum.portal" \
        "$r/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.vitrum.service" \
        "$r/etc/polkit-1/rules.d/50-vitrum.rules" "$r/etc/polkit-1/rules.d/49-vitrum-disks.rules" \
        "$r/etc/nvidia/nvidia-application-profiles-rc.d/50-vitrum-compositor.json" \
        "$b/vitrum-shell" "$b/vitrum-ipc" "$b/vitrum-startup" "$b/vitrum-settings" "$b/vitrum-disks" "$b/vitrum-about"

      # ---- pointed at the store ----
      replace_in "$r/usr/local/share/wayland-sessions/vitrum.desktop" "Exec=/usr/local/bin/vitrum-session" "Exec=$o/bin/vitrum-session"
      replace_in "$r/etc/systemd/user/niri.service" "ExecStart=/usr/local/bin/niri --session" "ExecStart=${niri}/bin/niri --session"
      replace_in "$r/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.vitrum.service" \
        "Exec=/usr/local/libexec/vitrum/vitrum-portal" "Exec=$o/libexec/vitrum/vitrum-portal"
      # The installer lets the one user who ran it; a package cannot know a
      # name, so it is the administrators' group, and the helper's store path.
      replace_in "$r/etc/polkit-1/rules.d/50-vitrum.rules" 'action.lookup("program") == "/usr/local/libexec/vitrum/vitrum-root"' \
        "action.lookup(\"program\") == \"$o/libexec/vitrum/vitrum-root\""
      replace_in "$r/etc/polkit-1/rules.d/50-vitrum.rules" "subject.user == \"$USER\"" 'subject.isInGroup("${adminGroup}")'
      replace_in "$r/etc/polkit-1/rules.d/50-vitrum.rules" "// Written by the vitrum installer: $USER may run" \
        "// From the vitrum package: members of ${adminGroup} may run"

      # The wrapper: the package's commands first on PATH, and the setup of
      # this user's home before niri reads its config from there. Never fatal:
      # a failed step is in ~/.local/share/vitrum/setup.log, and niri still starts.
      replace_in "$r/usr/local/bin/vitrum-session" '# Machine-specific exports.' \
'# From the vitrum package: its commands, and what vitrum keeps in your home
# (the niri config among it), made or refreshed.
PATH="'"$o"'/bin:$PATH"
"'"$o"'/bin/vitrum-setup" --login || echo "vitrum-setup did not finish; see ~/.local/share/vitrum/setup.log" >&2
# Machine-specific exports.'
      replace_in "$r/usr/local/bin/vitrum-session" '# vitrum session wrapper — environment, then the compositor. Written by the installer.' \
        '# vitrum session wrapper — environment, then the compositor. From the vitrum package.'

      # The launchers: Quickshell and each other by store path.
      for f in vitrum-shell vitrum-ipc vitrum-settings vitrum-disks vitrum-about; do
        grep -q '\bqs -[cp] ' "$b/$f" || { echo "vitrum (nix): $f does not run qs" >&2; exit 1; }
        sed -i 's|\bqs -\([cp]\) |${quickshell}/bin/qs -\1 |g' "$b/$f"
      done
      replace_in "$b/vitrum-startup" '"$HOME/.local/bin/vitrum-shell"' "\"$o/bin/vitrum-shell\""
      for f in settings disks about; do
        replace_in "$HOME/.local/share/applications/vitrum-$f.desktop" "Exec=$HOME/.local/bin/vitrum-$f" "Exec=vitrum-$f"
      done

      # Quickshell is a wrapped program in nixpkgs: the process is named after
      # the wrapped file, so the NVIDIA profile names that one as well.
      jq '.rules += [ .rules[0] | .pattern.matches = ".quickshell-wrapped" ]' \
        "$r/etc/nvidia/nvidia-application-profiles-rc.d/50-vitrum-compositor.json" > nvidia-profile.json

      # vitrum-root: a fixed PATH from the store.
      grep -q '^PATH=.*# @VITRUM_ROOT_PATH@$' "$r/usr/local/libexec/vitrum/vitrum-root"
      sed -i 's|^PATH=.*# @VITRUM_ROOT_PATH@$|PATH=${rootPath}|' "$r/usr/local/libexec/vitrum/vitrum-root"

      mkdir -p "$VITRUM_DIR/.nix-out"
      cp -a "$r" "$VITRUM_DIR/.nix-out/root"
      cp -a "$b" "$VITRUM_DIR/.nix-out/bin"
      cp -a "$HOME/.local/share/applications" "$VITRUM_DIR/.nix-out/applications"
    )

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    share=$out/share/vitrum
    mkdir -p $share $out/bin $out/libexec/vitrum
    cp -a shell apps tools config lib assets KEYBINDS.md VERSION LICENSE install.sh $share/
    # The session's own files are not for the home: sddm and plymouth themes
    # are packages of their own.
    rm -rf $share/assets/sddm $share/assets/plymouth
    # Developer tools, and the helpers that live in libexec.
    rm -f $share/tools/build-shaders $share/tools/gen-symbols $share/tools/niri-binary

    r=.nix-out/root
    install -Dm755 $r/usr/local/libexec/vitrum/vitrum-root $out/libexec/vitrum/vitrum-root
    install -Dm755 $r/usr/local/libexec/vitrum/vitrum-portal $out/libexec/vitrum/.vitrum-portal-wrapped
    install -Dm644 $r/usr/local/libexec/vitrum/vitrum_portal.py $out/libexec/vitrum/vitrum_portal.py
    rm -f $share/tools/vitrum-root $share/tools/vitrum-portal $share/tools/vitrum_portal.py

    install -Dm755 $r/usr/local/bin/vitrum-session $out/bin/vitrum-session
    install -Dm644 $r/usr/local/share/wayland-sessions/vitrum.desktop $out/share/wayland-sessions/vitrum.desktop
    install -Dm644 $r/etc/systemd/user/niri.service $out/lib/systemd/user/niri.service
    install -Dm644 $r/usr/share/xdg-desktop-portal/portals/vitrum.portal $out/share/xdg-desktop-portal/portals/vitrum.portal
    install -Dm644 $r/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.vitrum.service -t $out/share/dbus-1/services
    install -Dm644 $r/etc/polkit-1/rules.d/50-vitrum.rules $r/etc/polkit-1/rules.d/49-vitrum-disks.rules -t $out/share/polkit-1/rules.d
    install -Dm644 nvidia-profile.json $share/system/nvidia-application-profile.json
    install -Dm644 .nix-out/applications/*.desktop -t $out/share/applications
    install -Dm755 .nix-out/bin/vitrum-{shell,ipc,startup,settings,disks,about} -t $share/launchers

    patchShebangs $share/tools $share/launchers $share/lib $share/install.sh $out/libexec/vitrum $out/bin/vitrum-session

    runHook postInstall
  '';

  # Every command in bin: the launchers and the tools, each with the programs
  # it calls by name, and the Python tools that use GLib or GStreamer
  # (vitrum-thumbs reads PipeWire through it) with the paths those need.
  postFixup = ''
    share=$out/share/vitrum
    wrap() {  # wrap <program> <name in bin or a full path> [more for the front of PATH]
      local to="$2" gi=(); [[ "$to" == /* ]] || to="$out/bin/$to"
      # Only what imports gi gets the GObject paths: the launchers' environment
      # is every application's, and those paths are not theirs to inherit.
      if grep -qE '^(import gi|from gi)' "$1"; then gi=("''${gappsWrapperArgs[@]}"); fi
      makeWrapper "$1" "$to" "''${gi[@]}" \
        --prefix PATH : "$out/bin''${3:+:$3}" \
        --suffix PATH : "${niri}/bin:${quickshell}/bin:${runtimePath}" \
        --prefix XDG_DATA_DIRS : "${schemaDirs}" \
        --set-default VITRUM_LIBEXEC "$out/libexec/vitrum" \
        --set-default VITRUM_MANAGED nix \
        --set-default VITRUM_VERSION "${version}" \
        --set-default VITRUM_IPC "$out/bin/vitrum-ipc"
    }
    for f in $share/launchers/*; do wrap "$f" "$(basename "$f")"; done
    for f in $share/tools/vitrum $share/tools/vitrum-*; do
      [[ -f "$f" && -x "$f" ]] || continue
      case "$(basename "$f")" in
        # Its python must be the one with Pillow (the fastfetch logo), whatever
        # python3 the profile has.
        vitrum-setup) wrap "$f" vitrum-setup "${pythonEnv}/bin" ;;
        *) wrap "$f" "$(basename "$f")" ;;
      esac
    done
    wrap $out/libexec/vitrum/.vitrum-portal-wrapped $out/libexec/vitrum/vitrum-portal
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    # No tool is left asking /usr/bin/env for an interpreter the store has.
    bad="$(find $out/share/vitrum/tools $out/share/vitrum/launchers $out/libexec $out/bin -maxdepth 2 -type f -perm -u+x \
      -exec grep -lE '^#! ?(/usr/bin/env|/bin/)' {} + || true)"
    [ -z "$bad" ] || { echo "not pointed at the store: $bad" >&2; exit 1; }
    grep -q '^PATH=/nix/store' $out/libexec/vitrum/vitrum-root
    for f in $out/bin/vitrum-session $out/share/vitrum/launchers/* $out/share/vitrum/tools/vitrum-setup $out/libexec/vitrum/vitrum-root; do
      bash -n "$f"
    done
    # The apps reach the shell's code through their links.
    for a in settings disks about; do test -f $out/share/vitrum/apps/$a/theme/Colors.qml; done
    $out/bin/vitrum-theme --help >/dev/null
    # GLib and GStreamer load through the paths the wrappers carry, and the
    # PipeWire source vitrum-thumbs reads windows from is among the plugins.
    printf '%s\n' 'import gi' 'gi.require_version("Gst", "1.0")' 'from gi.repository import GLib, Gst' 'Gst.init(None)' \
      'import dbus, dbus.mainloop.glib, PIL' \
      'missing = [e for e in ("pipewiresrc", "videoconvert", "videoscale", "appsink") if Gst.ElementFactory.find(e) is None]' \
      'assert not missing, missing' > $TMPDIR/gi-check.py
    makeWrapper ${pythonEnv}/bin/python3 $TMPDIR/gi-check "''${gappsWrapperArgs[@]}" --add-flags $TMPDIR/gi-check.py
    HOME=$TMPDIR GST_REGISTRY=$TMPDIR/gst-registry $TMPDIR/gi-check
    $out/bin/vitrum-setup --help >/dev/null
    runHook postInstallCheck
  '';

  passthru = {
    providedSessions = [ "vitrum" ];
    inherit
      niri
      quickshell
      pythonEnv
      phosphor-fonts
      bibata-cursor
      ;
    runtimePackages = {
      inherit required;
    }
    // optional;
  };

  meta = {
    description = "A glass desktop for niri: the vitrum shell, its apps and its session";
    homepage = "https://github.com/LanisOff/vitrum-shell";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "vitrum";
  };
})
