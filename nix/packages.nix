# vitrum's packages for one nixpkgs: niri with the glass patches, Quickshell
# with the Qt modules the shell uses, the shell itself, the login and boot
# themes, and the few assets nixpkgs has no package for.
#
#   pkgs       a nixpkgs for Linux
#   niriFlake  the niri flake, at the revision lib/stages/30-niri.sh pins
#   root       the repository (the flake's own source)
{
  pkgs,
  niriFlake,
  root,
}:
let
  inherit (pkgs) lib;

  version = lib.trim (builtins.readFile (root + "/VERSION"));

  # ---------------------------------------------------------------- source ---

  # What the packages are built from, and nothing else of the repository: a
  # change to the README or the tests rebuilds none of them.
  src = lib.fileset.toSource {
    inherit root;
    fileset = lib.fileset.intersection (lib.fileset.fileFilter (
      f: !(lib.hasSuffix ".pyc" f.name) && f.name != ".DS_Store" && !(lib.hasPrefix "._" f.name)
    ) root) (
      lib.fileset.unions [
        (root + "/shell")
        (root + "/apps")
        (root + "/tools")
        (root + "/config")
        (root + "/lib")
        (root + "/nix/stage-env.sh")
        (root + "/assets/sddm")
        (root + "/assets/plymouth")
        (root + "/assets/vesktop")
        (root + "/assets/steam")
        (root + "/assets/wallpapers")
        (root + "/assets/vitrum-mark.svg")
        (root + "/KEYBINDS.md")
        (root + "/VERSION")
        (root + "/LICENSE")
        (root + "/install.sh")
      ]
    );
  };

  # ---------------------------------------------------------------- assets ---

  # lib/assets.tsv: the pinned URL and checksum of each upstream asset, read
  # here so the installer and the flake fetch the same files.
  assets =
    let
      rows = lib.filter (l: l != "" && !(lib.hasPrefix "#" l)) (
        lib.splitString "\n" (builtins.readFile (root + "/lib/assets.tsv"))
      );
      row =
        l:
        let
          c = lib.splitString "\t" l;
        in
        lib.nameValuePair (builtins.elemAt c 0) (
          pkgs.fetchurl {
            url = builtins.elemAt c 1;
            hash = builtins.convertHash {
              hash = builtins.elemAt c 2;
              hashAlgo = "sha256";
              toHashFormat = "sri";
            };
          }
        );
    in
    lib.listToAttrs (map row rows);

  # The line icons (Light for the UI, Fill for the player).
  phosphor-fonts = pkgs.runCommand "vitrum-phosphor-fonts" {
    meta = {
      description = "Phosphor Light and Fill icon fonts, as vitrum pins them";
      homepage = "https://phosphoricons.com";
      license = lib.licenses.mit;
    };
  } ''
    install -Dm644 ${assets.phosphor-light} $out/share/fonts/truetype/Phosphor-Light.ttf
    install -Dm644 ${assets.phosphor-fill} $out/share/fonts/truetype/Phosphor-Fill.ttf
  '';

  bibata-cursor = pkgs.runCommand "vitrum-bibata-modern-classic" {
    meta = {
      description = "Bibata Modern Classic cursor theme, as vitrum pins it";
      homepage = "https://github.com/ful1e5/Bibata_Cursor";
      license = lib.licenses.gpl3Only;
    };
  } ''
    mkdir -p $out/share/icons
    tar -xf ${assets.bibata} -C $out/share/icons
    test -d $out/share/icons/Bibata-Modern-Classic/cursors
  '';

  # Apple's colour emoji, converted for Linux by samuelngs/apple-emoji-ttf.
  # Apple's font is not free to redistribute: it is here for the module's
  # appleEmoji option, which is off unless you turn it on, and is not among
  # the flake's packages (nixpkgs refuses to evaluate it without allowUnfree).
  apple-emoji = pkgs.runCommand "vitrum-apple-color-emoji" {
    meta = {
      description = "Apple Color Emoji for Linux (unfree)";
      homepage = "https://github.com/samuelngs/apple-emoji-ttf";
      license = lib.licenses.unfree;
    };
  } ''
    install -Dm644 ${assets.apple-emoji} $out/share/fonts/truetype/AppleColorEmoji.ttf
  '';

  # ------------------------------------------------------------------ niri ---

  niriRev =
    let
      m = builtins.match ''.*NIRI_REV="([0-9a-f]{40})".*'' (
        builtins.readFile (root + "/lib/stages/30-niri.sh")
      );
    in
    if m == null then throw "vitrum: lib/stages/30-niri.sh has no NIRI_REV" else builtins.head m;

  niriPatches =
    let
      dir = root + "/patches/niri";
      names = lib.sort lib.lessThan (
        lib.attrNames (lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".patch" n) (builtins.readDir dir))
      );
    in
    map (n: dir + "/${n}") names;

  # niri at the installer's pin with patches/niri on top, built the way niri's
  # own flake builds it. The patches leave Cargo.toml and Cargo.lock alone, so
  # its vendored crates are used as they are. No -C target-cpu=native here:
  # the result has to run on whatever machine pulls it from a cache.
  niri-vitrum =
    assert lib.assertMsg ((niriFlake.rev or niriRev) == niriRev) ''
      vitrum: flake.nix pins niri at ${niriFlake.rev or "?"}, lib/stages/30-niri.sh at ${niriRev}.
      Change inputs.niri.url in flake.nix to the same revision and run: nix flake update niri
    '';
    (niriFlake.overlays.default pkgs pkgs).niri.overrideAttrs (old: {
      pname = "niri-vitrum";
      patches = (old.patches or [ ]) ++ niriPatches;
      # Upstream's tests cover upstream's niri; the glass is checked by this
      # flake's own probe (checks.niri-glass), as the installer checks it.
      doCheck = false;
      meta = old.meta // {
        description = "niri with vitrum's glass (patches/niri)";
      };
    });

  # ------------------------------------------------------------ quickshell ---

  # Quickshell with the Qt modules the shell and its apps import beyond
  # Quickshell's own: found through the paths nixpkgs' Qt reads.
  quickshell =
    let
      qt = pkgs.kdePackages;
      modules = [
        qt.qtdeclarative
        qt.qtsvg
        qt.qtimageformats
        qt.qtmultimedia
        qt.qt5compat
        qt.qtwayland
        # The session's platform theme and style (QT_QPA_PLATFORMTHEME=qt6ct, Kvantum).
        qt.qt6ct
        qt.qtstyleplugin-kvantum
      ];
    in
    assert lib.assertMsg (lib.versionAtLeast pkgs.quickshell.version "0.3.1")
      "vitrum needs Quickshell 0.3.1 or newer; this nixpkgs has ${pkgs.quickshell.version}";
    pkgs.symlinkJoin {
      name = "quickshell-vitrum-${pkgs.quickshell.version}";
      inherit (pkgs.quickshell) version;
      paths = [ pkgs.quickshell ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for b in qs quickshell; do
          [ -e "$out/bin/$b" ] || continue
          wrapProgram "$out/bin/$b" \
            --prefix NIXPKGS_QT6_QML_IMPORT_PATH : ${lib.makeSearchPath "lib/qt-6/qml" modules} \
            --prefix QT_PLUGIN_PATH : ${lib.makeSearchPath "lib/qt-6/plugins" modules}
        done
        test -x "$out/bin/qs"
      '';
      meta = pkgs.quickshell.meta // {
        mainProgram = "qs";
      };
    };

  # ---------------------------------------------------------------- vitrum ---

  vitrum = pkgs.callPackage ./vitrum.nix {
    inherit
      src
      version
      quickshell
      phosphor-fonts
      bibata-cursor
      ;
    niri = niri-vitrum;
  };

  # ----------------------------------------------------------------- themes ---

  # The login screen: what the boot stage installs into
  # /usr/share/sddm/themes/vitrum, made by that stage's own function. The
  # background is the first bundled wallpaper; the theme itself shows each
  # user's own once they have logged in (/var/lib/vitrum/login).
  vitrum-sddm-theme = pkgs.runCommand "vitrum-sddm-theme-${version}" {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.python3
      pkgs.gawk
    ];
    meta = {
      description = "vitrum's login screen for SDDM (Qt 6)";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  } ''
    export VITRUM_DIR=${src} VITRUM_NIX_ROOT=$TMPDIR/root
    source ${src}/nix/stage-env.sh
    source ${src}/lib/dm.sh
    source ${src}/lib/stages/70-boot.sh

    # The stage takes the icon font from the fonts stage's place, the
    # background from the wallpaper Settings names, and the font from there.
    install -Dm644 ${assets.phosphor-light} "$HOME/.local/share/fonts/vitrum/Phosphor-Light.ttf"
    wall="$(find ${src}/assets/wallpapers -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' \) | LC_ALL=C sort | head -n 1)"
    mkdir -p "$HOME/.config/vitrum"
    printf '{"wallpaper": {"path": "%s"}}\n' "$wall" > "$HOME/.config/vitrum/settings.json"

    have() { [[ "$1" == sddm ]] || command -v "$1" >/dev/null 2>&1; }
    # Which login screen runs is the NixOS module's to say.
    dm_use_sddm() { :; }
    WANT_SDDM=1
    SDDM_THEME=$out/share/sddm/themes/vitrum
    SDDM_DROPIN=$VITRUM_NIX_ROOT/etc/sddm.conf.d/zz-vitrum.conf
    SDDM_GREETER_KDL=$VITRUM_NIX_ROOT/etc/sddm/vitrum-greeter.kdl
    mkdir -p $out/share/sddm/themes
    _boot_sddm

    need_file $SDDM_THEME/Main.qml $SDDM_THEME/metadata.desktop $SDDM_THEME/theme.conf \
      $SDDM_THEME/Glass.qml $SDDM_THEME/glass.frag.qsb
    grep -q '^background=background\.' $SDDM_THEME/theme.conf
  '';

  # The boot splash, by the boot stage's own function as well. The .plymouth
  # file names the theme's folder, which here is in the store.
  vitrum-plymouth-theme = pkgs.runCommand "vitrum-plymouth-theme-${version}" {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.gawk
      pkgs.librsvg
      pkgs.imagemagick
    ];
    meta = {
      description = "vitrum's boot splash for Plymouth";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  } ''
    export VITRUM_DIR=${src} VITRUM_NIX_ROOT=$TMPDIR/root
    source ${src}/nix/stage-env.sh
    source ${src}/lib/dm.sh
    source ${src}/lib/stages/70-boot.sh

    have() { [[ "$1" == plymouth-set-default-theme ]] || command -v "$1" >/dev/null 2>&1; }
    # The theme is chosen, the initramfs built and the kernel command line set
    # by NixOS (boot.plymouth); the stage's own attempts find nothing to do.
    plymouth-set-default-theme() { :; }
    WANT_PLYMOUTH=1
    PLY_THEME=$out/share/plymouth/themes/vitrum
    mkdir -p $out/share/plymouth/themes
    _boot_plymouth

    need_file $PLY_THEME/vitrum.plymouth $PLY_THEME/vitrum.script $PLY_THEME/logo.png $PLY_THEME/fill.png
    replace_in $PLY_THEME/vitrum.plymouth "ImageDir=/usr/share/plymouth/themes/vitrum" "ImageDir=$PLY_THEME"
    replace_in $PLY_THEME/vitrum.plymouth "ScriptFile=/usr/share/plymouth/themes/vitrum/vitrum.script" "ScriptFile=$PLY_THEME/vitrum.script"
  '';

  # niri for the SDDM greeter (/etc/sddm/vitrum-greeter.kdl), from the boot
  # stage's own text, with the layouts the system's configuration names.
  mkGreeterConfig =
    {
      layout ? "us",
      variant ? "",
      options ? "",
    }:
    pkgs.runCommand "vitrum-greeter.kdl" {
      nativeBuildInputs = [
        pkgs.bash
        pkgs.gawk
      ];
      inherit layout variant options;
    } ''
      export VITRUM_DIR=${src} VITRUM_NIX_ROOT=$TMPDIR/root
      source ${src}/nix/stage-env.sh
      source ${src}/lib/dm.sh
      source ${src}/lib/stages/70-boot.sh
      # The stage reads the layouts from the user's niri config.
      mkdir -p "$HOME/.config/vitrum/niri"
      {
        printf 'layout "%s"\n' "$layout"
        [ -z "$variant" ] || printf 'variant "%s"\n' "$variant"
        printf 'options "%s"\n' "$options"
      } > "$HOME/.config/vitrum/niri/config.kdl"
      _boot_greeter_kdl > $out
      grep -q 'open-fullscreen true' $out
    '';
in
{
  inherit
    niri-vitrum
    quickshell
    vitrum
    vitrum-sddm-theme
    vitrum-plymouth-theme
    phosphor-fonts
    bibata-cursor
    apple-emoji
    ;
  # Not packages: what the module and the checks build from.
  lib = {
    inherit
      mkGreeterConfig
      niriRev
      assets
      src
      version
      ;
  };
}
