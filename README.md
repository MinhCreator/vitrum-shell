<p align="center">
  <img src="assets/vitrum-mark.svg" width="96" alt="vitrum">
</p>

<h1 align="center">vitrum</h1>

<p align="center">
  A glass desktop for <a href="https://github.com/YaLTeR/niri">niri</a>, coloured by your wallpaper and lit from within.
</p>

<p align="center">
  <a href="https://github.com/LanisOff/vitrum-shell/stargazers"><img src="https://img.shields.io/github/stars/LanisOff/vitrum-shell?style=flat-square&color=8b7cf6" alt="Stars"></a>
  <a href="https://github.com/LanisOff/vitrum-shell/commits/main"><img src="https://img.shields.io/github/last-commit/LanisOff/vitrum-shell?style=flat-square&color=8b7cf6" alt="Last commit"></a>
  <a href="https://github.com/LanisOff/vitrum-shell/commits/main"><img src="https://img.shields.io/github/commit-activity/m/LanisOff/vitrum-shell?style=flat-square&color=8b7cf6" alt="Commit activity"></a>
  <a href="https://github.com/LanisOff/vitrum-shell/issues"><img src="https://img.shields.io/github/issues/LanisOff/vitrum-shell?style=flat-square&color=8b7cf6" alt="Issues"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/LanisOff/vitrum-shell?style=flat-square&color=8b7cf6" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/YaLTeR/niri"><img src="https://img.shields.io/badge/compositor-niri-4f6fd6?style=flat-square" alt="niri"></a>
  <a href="https://quickshell.org"><img src="https://img.shields.io/badge/shell-Quickshell-4f6fd6?style=flat-square" alt="Quickshell"></a>
  <img src="https://img.shields.io/badge/Arch-systemd-1793d1?style=flat-square&logo=archlinux&logoColor=white" alt="Arch">
  <img src="https://img.shields.io/badge/Gentoo-OpenRC%20%7C%20systemd-54487a?style=flat-square&logo=gentoo&logoColor=white" alt="Gentoo">
  <img src="https://img.shields.io/badge/Fedora-systemd-51a2da?style=flat-square&logo=fedora&logoColor=white" alt="Fedora">
  <img src="https://img.shields.io/badge/Void-runit-478061?style=flat-square&logo=voidlinux&logoColor=white" alt="Void">
  <img src="https://img.shields.io/badge/NixOS-flake-5277c3?style=flat-square&logo=nixos&logoColor=white" alt="NixOS">
  <img src="https://img.shields.io/badge/NVIDIA-works-76b900?style=flat-square&logo=nvidia&logoColor=white" alt="NVIDIA works">
</p>

<p align="center">
  <img src="assets/screenshots/desktop.jpg" alt="The vitrum desktop on a purple wallpaper: air quality, moon phase, top processes and weather on the left, the glass clock in the middle, system rings and the player with synced lyrics on the right">
</p>

vitrum is the whole desktop you see after logging in. A bar of floating
islands, a dock, search, a control centre, widgets, a lock screen and a
settings app, all on real refracting glass. It started as my own setup. It's still young, so
please [open an issue](https://github.com/LanisOff/vitrum-shell/issues)
when something breaks.

<p align="center">
  <a href="#previews">Previews</a> ·
  <a href="#whats-inside">What's inside</a> ·
  <a href="#install">Install</a> ·
  <a href="#update">Update</a> ·
  <a href="#remove">Remove</a>
</p>

---

## Previews

<table>
  <tr>
    <td width="50%"><img src="assets/screenshots/desktop-moon.jpg" alt="Dark scheme on a moon wallpaper: glass clock, world clocks, moon phase, NASA headlines and a quote"></td>
    <td width="50%"><img src="assets/screenshots/desktop-train.jpg" alt="Light scheme on a train wallpaper: to-do list, habits, notes, an agenda for today and tomorrow, and a running stopwatch with laps"></td>
  </tr>
  <tr>
    <td align="center"><sub>Dark and calm, on a moon wallpaper</sub></td>
    <td align="center"><sub>Light, for the day: agenda, habits, stopwatch</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="assets/screenshots/control.jpg" alt="The control centre in glass tiles: network, Bluetooth, VPN, phone, do not disturb, appearance, power mode, stay awake, game mode, screen recording, volume and the player; the tiles that are on are lit from inside"></td>
    <td width="50%"><img src="assets/screenshots/notifications.jpg" alt="The notification centre: a screenshot, two calendar reminders and a finished download, grouped by app"></td>
  </tr>
  <tr>
    <td align="center"><sub>Control centre, what is on lit inside the glass</sub></td>
    <td align="center"><sub>Notifications, grouped by app</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="assets/screenshots/lock.jpg" alt="The lock screen: a large clock with the date and weather over the blurred wallpaper, the password field and the player with synced lyrics"></td>
    <td width="50%"><img src="assets/screenshots/windows.jpg" alt="Two kitty windows on the moon wallpaper: fastfetch with the vitrum mark, and btop"></td>
  </tr>
  <tr>
    <td align="center"><sub>Lock screen, with the player and lyrics</sub></td>
    <td align="center"><sub>kitty, fastfetch and btop in the same colours</sub></td>
  </tr>
</table>

<table>
  <tr>
    <td width="50%"><img src="assets/screenshots/settings.jpg" alt="The Settings app, Appearance page: scheme, colours, tint and density"></td>
    <td width="50%"><img src="assets/screenshots/about.jpg" alt="About this computer: processor, graphics, memory, storage, uptime, displays and board as glass tiles"></td>
  </tr>
  <tr>
    <td align="center"><sub>Settings, Appearance page</sub></td>
    <td align="center"><sub>About this computer, as spec tiles</sub></td>
  </tr>
</table>

---

## What's inside

> [!NOTE]
> **New in 0.7.0:** a full-screen player with the cover, synced lyrics you can click to seek and a spectrum along the bottom (`Mod+Alt+M`). Volume, brightness and keyboard layout now flow out of the bar's centre island as part of its glass. The login screen matches the lock screen, down to the clock and the wrong-password shake. And vitrum installs on NixOS, as a flake.

### Desktop

- A bar of floating islands, a dock, Spotlight-style search, a control centre and notifications.
- 40 desktop widgets: clocks, weather, system graphs, a to-do list, an agenda, habits, a stopwatch, the moon, air quality, headlines and top processes. Add your own in QML or as a script, and arrange them right on the desktop.
- A bar editor in Settings. Drag modules between islands and sides on a live bar, pick from a palette of named modules, set each one's options, give each screen its own layout, or reset.
- Type Japanese, Korean and Chinese with an optional input method: fcitx5 with Mozc, Hangul and Pinyin takes over your layouts, and Alt+Shift still switches them.
- A lock screen whose field lights up as you type. Caps Lock gets a hint, your avatar sits in a rim of lit glass, and it goes quiet when idle.
- Volume, microphone, brightness and keyboard layout show as a drop of glass under the bar's centre island, with every layout in a row and the current one lit.
- A player with the cover behind it, synced lyrics and a spectrum, in the bar, on the desktop and on the lock screen. `Mod+Alt+M` opens it full screen: click a line of the lyrics to jump there. With two screens, pin it to one and keep working on the other.
- Game mode turns on by itself when a game goes fullscreen. Video wallpapers pause under windows.
- Lite mode for older hardware: blur, glass, animations, shadows, the live wallpaper and more, off one by one or all at once, by hand or on battery.

### Apps

- Settings for everyday changes, so config files stay optional.
- About this computer, as spec tiles.
- A welcome tour on first login, with a live preview of each part of the desktop.
- Clipboard history, screenshots and recording, hot corners and a polkit prompt.
- A login screen (SDDM) that is the lock screen's twin: the same clock, field and icons, in your scheme and colours.

### Theming

- One look, dichroic glass. Anything that's on turns to frosted, lit glass with a soft glow in your accent. No pill shapes, thin Phosphor line icons, and calm motion with no bounce.
- Colours from your wallpaper for the shell, kitty, GTK, Qt/KDE, tmux and Neovim, light or dark by sunrise and sunset.
- A second colour drawn from the accent for rings, graphs and the window focus ring. Shift it in Settings → Appearance.
- Optional Steam (via Millennium) and Vesktop (Discord) themes that follow your colours. Both are installer choices with a section in Settings.
- fastfetch fits narrow terminals and tmux splits.

### Under the hood

- niri, with our own glass patched in: it bends what's behind it, takes its colour and catches the light, in the shape of each surface. Choose solid, frosted or glass per surface if your GPU prefers.
- A [Quickshell](https://quickshell.org) shell, one installer for four distributions, a flake for NixOS, and `vitrum doctor` when something's off.
- GPU load and temperature on NVIDIA and AMD.
- If the shell crashes, it comes back and tells you why. `vitrum doctor` lists recent crashes.

---

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/LanisOff/vitrum-shell/main/get.sh | bash
```

This installs git if needed, clones vitrum to `~/.local/share/vitrum-src`
and starts the installer. Or by hand:

```sh
git clone https://github.com/LanisOff/vitrum-shell
cd vitrum-shell
./install.sh
```

> [!IMPORTANT]
> Runs on Arch with systemd (CachyOS and other Arch-based systems too),
> Gentoo with OpenRC or systemd, Fedora 43 or newer with systemd (tested on
> 44), and Void (glibc, not musl) with runit and elogind. NVIDIA works.
> NixOS has its own way in, as a flake: see [NixOS](#nixos) below.

> [!NOTE]
> The installer backs up every file it replaces, and asks before it makes
> fish your login shell or replaces another login screen. NetworkManager
> takes over the network. On Fedora it enables RPM Fusion and a few COPRs,
> and tells you which. On Void the login screen and network switch over at
> the next boot. On Arch and Arch-based systems you can take a prebuilt niri,
> which downloads in about a minute. Everywhere else niri builds from source,
> which takes 20 to 40 minutes on the first run. On Gentoo some Qt pieces
> build too.

> [!TIP]
> A minimal Void may lack bash, curl and sudo. Run
> `xbps-install -Sy bash curl sudo` as root, then add yourself to `wheel`
> (`usermod -aG wheel <you>`, with the `%wheel` line enabled in `visudo`).

You pick the parts on one screen. Desktop has the login screen, boot
splash, video wallpapers and KDE Connect. Tools has tmux, game mode, the
Steam theme (needs game mode), the Vesktop theme, the mic filter, VPN, CLI
tools, Dolphin and OCR. Extras holds my own Neovim and tmux setup, off by
default. If a stage fails, you can retry it, skip it, read its log, or
carry on later with `./install.sh --from <stage>`. Logs go to
`~/.local/share/vitrum/`.

On Arch and Arch-based systems the same screen asks how niri gets here:
prebuilt, the default, or compiled on your machine. The binary is built by
[GitHub Actions](.github/workflows/niri-binary.yml) against current Arch, so
it needs an up-to-date system. It's verified and tried before it replaces
anything, and if it can't run on your system, the installer says why and
compiles instead. `--with-prebuilt-niri` and `--no-prebuilt-niri` choose
without the screen. Each release carries the matching source, the pinned
upstream niri with [`patches/niri`](patches/README.md) applied and its crates
vendored.

```sh
./install.sh --dry-run   # show what it would do, change nothing
./install.sh --update    # update: ask only about parts new or still unticked
./install.sh --choose    # the choice screen again, with your choices
./install.sh --fresh     # the first-run screens again; everything is redone
./install.sh --doctor    # check an existing install
./install.sh --yes       # no screens: earlier answers, defaults for new parts
./install.sh --help      # every flag, one per part (--with-games, --no-ocr...)
```

Every part has its own flags, such as `--with-steam-theme` and
`--with-vesktop-theme`. They also pass through the one-liner:

```sh
curl -fsSL https://raw.githubusercontent.com/LanisOff/vitrum-shell/main/get.sh | bash -s -- --dry-run
```

Once you're in:

| Key | Opens |
|---|---|
| `Mod+Space` | Search |
| `Mod+Alt+C` | Control centre |
| `Mod+Comma` | Settings |
| `Mod+Alt+W` | Widget editor |
| `Mod+/` | Every shortcut |

The rest is in [KEYBINDS.md](KEYBINDS.md). Settings are also plain text in
`~/.config/vitrum/settings.json`.

### NixOS

On NixOS vitrum is a flake, not the installer. It brings niri with the glass
patches, the shell and a module for the system. Add it to your system's
`flake.nix`:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.vitrum.url = "github:LanisOff/vitrum-shell";
  inputs.vitrum.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, vitrum, ... }@inputs: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [ ./configuration.nix ];
    };
  };
}
```

and turn it on in the machine's configuration:

```nix
{ inputs, ... }:
{
  imports = [ inputs.vitrum.nixosModules.default ];
  programs.vitrum.enable = true;
}
```

Then `sudo nixos-rebuild switch --flake .#my-machine`, log out and pick
**vitrum** on the login screen.

> [!IMPORTANT]
> vitrum needs a recent nixpkgs (Quickshell 0.3.1 or newer), so `nixos-unstable`
> today. niri builds from source on the first switch, which takes 20 to 40
> minutes, unless you have a cache that holds it.

The module sets up what the installer does to a system: the session, SDDM with
vitrum's login screen, PipeWire, NetworkManager, Bluetooth, the portals, the
keyring, the fonts and the polkit rules. The services are defaults, so yours
win where you already chose one. The parts you tick on the installer's choice
screen are options here:

| Option, under `programs.vitrum` | Default | What it adds |
|---|---|---|
| `sddm.enable` | on | The login screen |
| `plymouth.enable` | off | The boot splash |
| `inputMethod.enable` | off | Japanese, Korean and Chinese input (fcitx5) |
| `liveWallpaper.enable` | on | Video wallpapers |
| `phone.enable` | off | KDE Connect |
| `tmux.enable` | on | tmux, themed |
| `games.enable` | on | Game mode and MangoHud |
| `utilities.enable` | on | Mic noise filter, VPN tools, sensors, mixer |
| `cliTools.enable` | on | eza, bat, fzf, zoxide, delta |
| `fileManager.enable` | on | Dolphin |
| `ocr.enable` | on | Text from screenshots |
| `vesktopTheme.enable` | on | The Vesktop theme, applied with `vitrum-vesktop-theme install` |
| `appleEmoji.enable` | off | Apple Color Emoji (unfree, needs `allowUnfree`) |
| `adminGroup` | `wheel` | Who uses VPN, disk health and Disk Utility without a password |

Your own files stay ordinary files, as on every other distribution. At each
login `vitrum-setup` makes what's missing in `~/.config` and
`~/.local/share/vitrum` (the niri config, `settings.json`, the terminal's and
the toolkits' themes) and points the shell's folders at the new package after
an update. It never writes over your settings, `overrides.kdl` or widgets, and
the Settings app works as usual. Run `vitrum-setup` by hand to do it without
logging out (it also fetches the tmux plugins, which a login doesn't wait
for); its last run is in `~/.local/share/vitrum/setup.log`.

What's different from the other distributions:

- **Updating** is `nix flake update vitrum` and a `nixos-rebuild switch`, then
  a new login. `vitrum update` only says so, since there's no checkout to pull.
  `vitrum snapshot` and `vitrum rollback` still save and restore your configs,
  and the system itself rolls back the NixOS way.
- **The Steam theme** isn't there: Millennium patches Steam's own files, which
  NixOS doesn't allow.
- **fish as your login shell** is yours to set (`users.users.<you>.shell =
  pkgs.fish;`). kitty starts fish either way.
- **Apple Color Emoji** is off unless you turn it on, and Noto Color Emoji
  stands in.

To look before you switch, the flake has a small system for a virtual machine:
`nixos-rebuild build-vm --flake github:LanisOff/vitrum-shell#vm`, then
`./result/bin/run-vitrum-vm` and log in as `vitrum` (password `vitrum`).

---

## Update

```sh
vitrum update           # pull and reinstall only what changed
vitrum update --choose  # the same, with the choice screen to change your parts
vitrum rollback         # undo the last update (your configs are snapshotted first)
vitrum doctor           # find out what is broken and how to fix it
```

Your choices are kept. You're only asked about parts that are new or still
unticked. A small island in the bar tells you when a new version is out or
enough commits have piled up. An update that changes niri downloads the
prebuilt binary if that's your choice, or compiles it, which takes 20 to 40
minutes. Either way the new niri applies after you log in again. The first
update on Arch asks once which one you want, and `vitrum doctor` shows which
one you have.

---

## Remove

```sh
./uninstall.sh
```

This undoes what the installer added and restores the files it backed up.
Packages, `~/.config/vitrum` and `~/.local/share/vitrum` stay. `--purge`
removes the last two. The clone in `~/.local/share/vitrum-src` is yours to
delete. NetworkManager stays in charge of the network.

---

## Credits

- [niri](https://github.com/YaLTeR/niri) by YaLTeR, the compositor underneath.
- [Quickshell](https://quickshell.org), which the shell is written in.
- [matugen](https://github.com/InioX/matugen), which turns the wallpaper into a palette.
- [Phosphor Icons](https://phosphoricons.com), the line icons.
- [Bibata](https://github.com/ful1e5/Bibata_Cursor), the cursor.
- Default wallpapers from [Wallhaven](https://wallhaven.cc/).

<a href="https://star-history.com/#LanisOff/vitrum-shell&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=LanisOff/vitrum-shell&type=Date&theme=dark">
    <img src="https://api.star-history.com/svg?repos=LanisOff/vitrum-shell&type=Date" alt="Star history" width="100%">
  </picture>
</a>

---

## License

[GPL-3.0](LICENSE)
