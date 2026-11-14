# shellcheck shell=bash disable=SC1090,SC1091
# tools/vitrum-root refuses anything but a whole disk, by name.
R="$VITRUM_DIR/tools/vitrum-root"
test_smart_refuses_other_devices() {
  stub smartctl 'echo "smartctl $*"'
  for d in /dev/null /dev/watchdog "/dev/sda;id" "/dev/sda1" "../dev/sda" "/tmp/x"; do
    out="$("$R" smart "$d" 2>&1)" && { echo "accepted $d"; return 1; }
    assert_contains "$out" "not a disk"
  done
}
test_smart_refuses_a_symlink_named_like_a_disk() {
  # Only the exact /dev path qualifies; a link elsewhere never matches the name.
  ln -s /dev/null "$HOME/sda"
  ! "$R" smart "$HOME/sda" >/dev/null 2>&1
}
test_wg_refuses_paths() {
  for n in "../../etc/passwd" "a/b" "" "x;id"; do
    ! "$R" wg-up "$n" >/dev/null 2>&1 || { echo "accepted $n"; return 1; }
  done
}
test_unknown_command_refused() {
  ! "$R" rm -rf / >/dev/null 2>&1
}

# login-sync: the caller's login folder, checked and rebuilt, into a place the
# greeter can read without trusting the user's home.
_login_src() {
  L="$HOME/.local/share/vitrum/login"; mkdir -p "$L"
  printf '\xff\xd8\xff\xe0fakejpeg' > "$L/day"
  printf '\x89PNG\r\n\x1a\nfakepng' > "$L/night"
  printf '{"light":"07:12","dark":"18:40","font":"Inter","h24":true,"evil":"x"}' > "$L/login.json"
  printf '{"palette":{"dark":{"accent":"#8ab4f8","text":"red;}","bg":"#101112"},"light":{}}}' > "$L/palette.json"
  export VITRUM_LOGIN_ROOT="$HOME/varlib" VITRUM_LOGIN_HOME="$HOME"
  U="$(id -un)"
}
test_login_sync_copies_checked_files() {
  _login_src
  "$R" login-sync
  D="$VITRUM_LOGIN_ROOT/$U"
  assert_eq "$(head -c 3 "$D/day" | od -An -tx1 | tr -d ' \n')" "ffd8ff"
  [[ -f "$D/night" ]]
  # Only the known keys, only well-formed values.
  assert_eq "$(cat "$D/login.json")" '{"light": "07:12", "dark": "18:40", "font": "Inter", "h24": true}'
  assert_eq "$(cat "$D/palette.json")" '{"palette": {"dark": {"bg": "#101112", "accent": "#8ab4f8"}}}'
}
# How the desktop looks and moves (scheme, density, text size, motion) and the
# picture: only the words and ranges the shell itself can have set.
test_login_sync_takes_the_scheme_motion_and_picture() {
  _login_src
  printf '\xff\xd8\xff\xe0face' > "$L/face"
  printf '{"light":"07:12","scheme":"light","density":"regular","textScale":1.1,"speed":1.5,"still":true}' > "$L/login.json"
  printf '{"palette":{"dark":{"accent":"#8ab4f8","accent2":"#92ec8d"},"light":{"accent":"#1a5fb4","bg":"#f4f5f7","text":"url(x)"}}}' > "$L/palette.json"
  "$R" login-sync
  D="$VITRUM_LOGIN_ROOT/$U"
  assert_eq "$(head -c 3 "$D/face" | od -An -tx1 | tr -d ' \n')" "ffd8ff"
  assert_eq "$(cat "$D/login.json")" '{"light": "07:12", "scheme": "light", "density": "regular", "textScale": 1.1, "speed": 1.5, "still": true}'
  assert_eq "$(cat "$D/palette.json")" '{"palette": {"dark": {"accent": "#8ab4f8", "accent2": "#92ec8d"}, "light": {"bg": "#f4f5f7", "accent": "#1a5fb4"}}}'
}
test_login_sync_drops_odd_scheme_and_motion_values() {
  _login_src
  printf 'not a picture' > "$L/face"
  # A word it does not know, numbers out of range or not numbers at all, a
  # truthy string: none of it reaches the greeter.
  for bad in '"scheme":"dusk"' '"scheme":1' '"density":"huge"' '"textScale":9' '"textScale":true' \
             '"speed":0' '"speed":1000' '"speed":"2"' '"speed":NaN' '"speed":Infinity' '"speed":true' '"still":"yes"' '"still":1'; do
    printf '{"dark":"18:40",%s}' "$bad" > "$L/login.json"
    "$R" login-sync
    assert_eq "$(cat "$VITRUM_LOGIN_ROOT/$U/login.json")" '{"dark": "18:40"}'
  done
  [[ ! -e "$VITRUM_LOGIN_ROOT/$U/face" ]]
}
test_login_sync_refuses_fifos_links_and_fakes() {
  _login_src
  rm "$L/day" "$L/login.json" "$L/night"
  mkfifo "$L/day"
  ln -s /dev/zero "$L/login.json"
  printf 'not a picture' > "$L/night"
  "$R" login-sync   # must not block on the FIFO
  D="$VITRUM_LOGIN_ROOT/$U"
  [[ ! -e "$D/day" && ! -e "$D/login.json" && ! -e "$D/night" ]]
}
test_login_sync_drops_what_is_gone() {
  _login_src
  "$R" login-sync
  rm "$L/night"
  "$R" login-sync
  [[ ! -e "$VITRUM_LOGIN_ROOT/$U/night" && -e "$VITRUM_LOGIN_ROOT/$U/day" ]]
}
