# shellcheck shell=bash disable=SC1090,SC1091,SC2016
# tools/vitrum-setup: the installer's work in $HOME where vitrum is a package
# (NixOS). It runs from the checkout as it would from the package, with the
# programs it calls as stubs; nothing of it is root's.
_setup_world() {
  PATH="$STUBS:$(dirname "$BASH"):/usr/bin:/bin:/usr/sbin:/sbin"
  export CALLS="$HOME/calls"; : > "$CALLS"
  local c
  for c in vitrum-theme niri fc-list gsettings xdg-user-dirs-update fish kvantummanager vitrum-shell; do
    stub "$c" "echo \"$c \$*\" >> \"\$CALLS\"; exit 0"
  done
  # A real sudo would be a bug: the script must never reach one.
  stub sudo 'echo "sudo $*" >> "$CALLS"; exit 1'
  printf 'WANT_TMUX=0\nWANT_GAMES=1\nWANT_STEAM_THEME=0\nWANT_INPUT_METHOD=1\n' > "$HOME/setup.env"
  export VITRUM_SETUP_CHOICES="$HOME/setup.env"
}
_setup() { bash "$VITRUM_DIR/tools/vitrum-setup" "$@"; }

test_setup_makes_what_a_session_needs() {
  _setup_world
  _setup --login || { cat "$XDG_DATA_HOME/vitrum/setup.log"; return 1; }
  local n="$XDG_CONFIG_HOME/vitrum/niri"
  [[ -f "$n/config.kdl" && -f "$n/overrides.kdl" && -f "$XDG_CONFIG_HOME/vitrum/session.env" ]]
  assert_contains "$(cat "$n/generated/session.kdl")" 'spawn-at-startup "vitrum-startup"'
  assert_contains "$(cat "$n/generated/binds.kdl")" "Mod+"
  # NIRI_CONFIG, handed to what niri starts, is this user's file.
  assert_contains "$(cat "$n/config.kdl")" "NIRI_CONFIG \"$n/config.kdl\""
  assert_eq "$(cat "$XDG_CONFIG_HOME/vitrum/settings.json" | tr -d '[:space:]' | cut -c1)" "{"
  assert_eq "$(cat "$XDG_DATA_HOME/vitrum/version")" "$(tr -d '[:space:]' < "$VITRUM_DIR/VERSION")"
  [[ -f "$XDG_CONFIG_HOME/fontconfig/conf.d/50-vitrum.conf" && -f "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" ]]
  [[ -f "$XDG_DATA_HOME/vitrum/welcome" ]] || { echo "no welcome marker on the first setup"; return 1; }
  ! grep -q '^sudo ' "$CALLS" || { echo "sudo was called: $(grep '^sudo ' "$CALLS")"; return 1; }
}

test_setup_links_the_shell_and_the_apps_into_the_package() {
  _setup_world
  _setup --login
  assert_eq "$(readlink "$XDG_CONFIG_HOME/quickshell/vitrum")" "$VITRUM_DIR/shell"
  local a
  for a in settings disks about; do
    assert_eq "$(readlink "$XDG_CONFIG_HOME/quickshell/vitrum-$a")" "$VITRUM_DIR/apps/$a" || return 1
    # The apps reach the shell's code through the package's own links.
    [[ -f "$XDG_CONFIG_HOME/quickshell/vitrum-$a/theme/Colors.qml" ]] || { echo "vitrum-$a has no theme"; return 1; }
  done
  assert_eq "$(readlink "$XDG_DATA_HOME/vitrum/templates")" "$VITRUM_DIR/config"
}

test_setup_records_the_systems_choices() {
  _setup_world
  _setup --login
  local c; c="$(cat "$XDG_DATA_HOME/vitrum/components.json")"
  assert_contains "$c" '"tmux": false'
  assert_contains "$c" '"games": true'
  assert_contains "$c" '"steam_theme": false'
  assert_contains "$c" '"input_method": true'
  [[ ! -e "$HOME/.tmux.conf" ]] || { echo "tmux was set up though it is off"; return 1; }
}

test_setup_never_writes_over_your_files() {
  _setup_world
  _setup --login
  echo '{"mine": true}' > "$XDG_CONFIG_HOME/vitrum/settings.json"
  echo '// mine' > "$XDG_CONFIG_HOME/vitrum/niri/overrides.kdl"
  echo '# mine' > "$XDG_CONFIG_HOME/vitrum/session.env"
  mkdir -p "$XDG_CONFIG_HOME/vitrum/widgets/own"; echo mine > "$XDG_CONFIG_HOME/vitrum/widgets/own/Own.qml"
  _setup --force >/dev/null
  assert_contains "$(cat "$XDG_CONFIG_HOME/vitrum/settings.json")" '"mine": true'
  assert_eq "$(cat "$XDG_CONFIG_HOME/vitrum/niri/overrides.kdl")" "// mine"
  assert_eq "$(cat "$XDG_CONFIG_HOME/vitrum/session.env")" "# mine"
  assert_eq "$(cat "$XDG_CONFIG_HOME/vitrum/widgets/own/Own.qml")" "mine"
}

test_setup_at_login_does_nothing_the_second_time() {
  _setup_world
  _setup --login
  : > "$CALLS"
  echo "// edited by hand" >> "$XDG_CONFIG_HOME/vitrum/niri/generated/session.kdl"
  _setup --login
  assert_eq "$(cat "$CALLS")" ""
  assert_contains "$(cat "$XDG_CONFIG_HOME/vitrum/niri/generated/session.kdl")" "edited by hand"
}

test_setup_runs_again_when_the_choices_change() {
  _setup_world
  _setup --login
  printf 'WANT_TMUX=0\nWANT_GAMES=0\n' > "$HOME/setup.env"
  _setup --login
  assert_contains "$(cat "$XDG_DATA_HOME/vitrum/components.json")" '"games": false'
}

test_setup_makes_the_niri_config_again_when_it_is_gone() {
  _setup_world
  _setup --login
  rm "$XDG_CONFIG_HOME/vitrum/niri/config.kdl"
  _setup --login
  [[ -f "$XDG_CONFIG_HOME/vitrum/niri/config.kdl" ]]
}

# An install.sh's own copy of the shell, from before the system took vitrum
# over: moved aside, not removed, and the link takes its place.
test_setup_moves_a_folder_of_the_installers_aside() {
  _setup_world
  mkdir -p "$XDG_CONFIG_HOME/quickshell/vitrum"; echo old > "$XDG_CONFIG_HOME/quickshell/vitrum/shell.qml"
  _setup --login
  assert_eq "$(readlink "$XDG_CONFIG_HOME/quickshell/vitrum")" "$VITRUM_DIR/shell"
  local aside; aside="$(find "$XDG_CONFIG_HOME/quickshell" -maxdepth 1 -name 'vitrum.before-package.*')"
  assert_eq "$(cat "$aside/shell.qml")" "old"
}

# A step that dies must not take the login with it: the rest still happens,
# the exit says so, and the next login tries again.
test_setup_survives_a_failing_step() {
  _setup_world
  stub vitrum-theme 'echo "vitrum-theme $*" >> "$CALLS"; exit 1'
  # KEYBINDS.md that cannot be parsed makes _session_keybinds die.
  echo "not a keymap" > "$HOME/KEYBINDS.md"
  local rc=0
  VITRUM_KEYBINDS_MD="$HOME/KEYBINDS.md" _setup --login || rc=$?
  [[ -f "$XDG_CONFIG_HOME/vitrum/niri/config.kdl" && -f "$XDG_CONFIG_HOME/vitrum/niri/generated/binds.kdl" ]] \
    || { echo "no niri config after a failed step"; return 1; }
  [[ -f "$XDG_CONFIG_HOME/gtk-3.0/settings.ini" ]] || { echo "the steps after the failed one did not run"; return 1; }
  if [[ "$rc" != 0 ]]; then
    [[ ! -e "$XDG_DATA_HOME/vitrum/setup.stamp" ]] || { echo "stamped although a step failed"; return 1; }
  fi
}

test_setup_dry_run_changes_nothing() {
  _setup_world
  _setup --dry-run >/dev/null
  local left; left="$(find "$HOME" -mindepth 1 -not -name calls -not -name setup.env 2>/dev/null)"
  [[ -z "$left" ]] || { echo "dry-run left:"; echo "$left"; return 1; }
}

test_setup_rejects_an_unknown_option() {
  _setup_world
  local rc=0; _setup --nonsense 2>/dev/null || rc=$?
  assert_eq "$rc" 2
}
