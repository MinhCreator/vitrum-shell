# The flake's checks (nix flake check):
#
#   module       a small NixOS with programs.vitrum.enable evaluates whole, so
#                every option the module sets exists in this nixpkgs
#   niri-glass   the niri built here accepts vitrum's glass: the installer's own
#                probe (niri_binary_check, lib/stages/30-niri.sh)
#   setup        vitrum-setup, in an empty home, leaves a niri config that
#                this niri accepts and the links the shell starts from
#   packages     the shell package (its build checks the QML) and the themes
{
  pkgs,
  vitrum,
  nixos,
}:
let
  inherit (vitrum.lib) src;
in
{
  inherit (vitrum) vitrum-sddm-theme vitrum-plymouth-theme;
  package = vitrum.vitrum;

  # Evaluated, not built: the derivation's path is taken as plain text.
  module = pkgs.runCommand "vitrum-module-eval" { } ''
    echo ${builtins.unsafeDiscardStringContext nixos.config.system.build.toplevel.drvPath} > $out
  '';

  niri-glass =
    pkgs.runCommand "vitrum-niri-glass"
      {
        # ldd: the probe reads a missing library from its output.
        nativeBuildInputs = [
          pkgs.gawk
          pkgs.stdenv.cc.libc.bin
        ];
      }
      ''
    export VITRUM_DIR=${src} VITRUM_NIX_ROOT=$TMPDIR/root XDG_RUNTIME_DIR=$TMPDIR
    source ${src}/nix/stage-env.sh
    source ${src}/lib/stages/30-niri.sh
    niri_binary_check ${vitrum.niri-vitrum}/bin/niri $TMPDIR/probe.kdl \
      || { echo "niri: $_NIRI_WHY" >&2; exit 1; }
    ${vitrum.niri-vitrum}/bin/niri --version > $out
  '';

  setup =
    pkgs.runCommand "vitrum-setup-check"
      {
        nativeBuildInputs = [
          vitrum.vitrum
          vitrum.niri-vitrum
        ];
      }
      ''
        export HOME=$TMPDIR/home XDG_RUNTIME_DIR=$TMPDIR/run
        mkdir -p $HOME $XDG_RUNTIME_DIR
        unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
        printf 'WANT_TMUX=0\nWANT_STEAM_THEME=0\n' > $TMPDIR/setup.env
        export VITRUM_SETUP_CHOICES=$TMPDIR/setup.env

        vitrum-setup --login || { cat $HOME/.local/share/vitrum/setup.log; exit 1; }
        cat $HOME/.local/share/vitrum/setup.log

        c=$HOME/.config
        test -f $c/vitrum/settings.json
        test -f $c/vitrum/session.env
        test -f $c/vitrum/niri/overrides.kdl
        test -f $c/quickshell/vitrum/shell.qml
        test -f $c/quickshell/vitrum-settings/theme/Colors.qml
        test -f $HOME/.local/share/vitrum/palette.json
        test -f $HOME/.local/share/vitrum/components.json
        grep -q 'spawn-at-startup "vitrum-startup"' $c/vitrum/niri/generated/session.kdl
        grep -q 'Mod+' $c/vitrum/niri/generated/binds.kdl
        niri validate -c $c/vitrum/niri/config.kdl

        # Again: nothing to do, and your files are as they were.
        echo '{"mine": true}' > $c/vitrum/settings.json
        echo '// mine' > $c/vitrum/niri/overrides.kdl
        vitrum-setup --login
        vitrum-setup --force
        grep -q mine $c/vitrum/settings.json
        grep -q mine $c/vitrum/niri/overrides.kdl
        niri validate -c $c/vitrum/niri/config.kdl
        touch $out
      '';
}
