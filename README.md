# studio-brightness-linux

Brightness control for Apple displays on Linux: Cinema Displays, the Thunderbolt
Display, Studio Displays and the Pro Display XDR. A command-line tool (Python 3, no
dependencies) plus a small GTK4 window with a slider per display.

Apple displays have no DDC/CI, so brightness travels over the display's **USB cable**.
That cable must be plugged into the computer.

## Install

### Packages

Download the `.deb` (Debian, Ubuntu) or `.rpm` (Fedora) from the
[latest release](https://github.com/mfat/studio-brightness-linux/releases/latest) and
install it:

```sh
sudo apt install ./studio-brightness-linux_*_all.deb
sudo dnf install ./studio-brightness-linux-*.noarch.rpm
```

On Arch, build `packaging/ArchLinux/PKGBUILD` with `makepkg -si`.

Packages can't change your personal settings, so add the keyboard shortcuts yourself in
Settings > Keyboard > Custom Shortcuts, with the commands `studio-brightness up --osd`
and `studio-brightness down --osd`.

### From source

```sh
bash install.sh
```

This installs to `~/.local/bin` and `/etc/udev/rules.d`, and adds GNOME shortcuts:
**Super+F2** brighter, **Super+F1** dimmer. To use other keys:

```sh
bash install.sh --up '<Super>Page_Up' --down '<Super>Page_Down'
```

You can also edit them later in Settings > Keyboard > Custom Shortcuts. If the display
isn't found right after install, unplug and replug its USB cable once.

## Usage

```sh
studio-brightness list        # show detected displays and which backend each uses
studio-brightness get         # 0-100
studio-brightness set 60      # also accepts 60%, +10, -10
studio-brightness up          # +10%, or: up 5
studio-brightness down
studio-brightness --osd up    # also show the on-screen brightness indicator
studio-brightness --notify up # or a desktop notification instead
```

There's also a small GTK4 window with one slider per display: open **Display
Brightness** from the app menu, or run `studio-brightness-gui`. It needs GTK4 and
libadwaita for Python (`gir1.2-adw-1`, already present on GNOME desktops).

With several displays, every command applies to all of them unless you pick one with
`-d NAME` (the name shown by `list`).

The keyboard shortcuts show an on-screen indicator, a small bar at the bottom of the
screen like GNOME's own. GNOME won't let other programs use its built-in one, so this is
a separate popup drawn through XWayland, which takes no keyboard focus and lets clicks
pass through. It needs GTK3 for Python, which GNOME desktops already have.

## Supported displays

| Display | USB ID | How |
|---|---|---|
| Apple Cinema Displays (LED, aluminium) | 05ac:9218, 9219, 921c, 921d, 9221, 9222, 9226, 9236 | kernel `appledisplay` driver |
| Thunderbolt Display | 05ac:9227 | HID |
| Studio Display | 05ac:1114 | HID |
| Studio Display (Gen 2) | 05ac:1118 | HID |
| Studio Display XDR | 05ac:1116 | HID |
| Pro Display XDR | 05ac:9243 | HID |
| Other Apple displays | 05ac:* | HID, if the display has the brightness control |

Tested on the LED Cinema Display (9226). The HID models follow the protocol documented by
Studio Brightness ++ (32-bit brightness, range 400-60000) but haven't been tried on Linux yet;
reports are welcome. On a Studio Display, brightness only changes in the default
"Apple Display" reference mode, as calibrated modes lock it. A display whose ID isn't in
`70-studio-brightness.rules` is detected but needs its ID added there for permission.

## How it works

- Cinema Displays known to the kernel's `appledisplay` driver (including the LED
  Cinema Display, `05ac:9226`) get `/sys/class/backlight/appledisplay*`, and the tool
  writes there. `usbhid` tends to grab these displays first without exposing anything
  usable, so the udev rule hands them over to `appledisplay`.
- Everything else is reached through `/dev/hidraw*`. The tool reads the display's HID report
  descriptor, finds the Monitor brightness control (usage page 0x82, usage 0x10), and
  sends feature reports.

## Troubleshooting

- `No Apple display found`: check `lsusb | grep -i 05ac` lists the display. If not,
  the USB cable isn't connected.
- `no permission`: rerun `bash install.sh`, replug the USB cable, and log out and back
  in if it added you to the `video` group.

Uninstall with `bash install.sh --uninstall`.

## Releasing

Run the **Release** workflow from the Actions tab with the new version. It updates the
version everywhere (`scripts/bump-version.sh`), tags, creates the GitHub release, builds
the `.deb` and `.rpm` and attaches them, then points the Arch `PKGBUILD` at the new tag.
`make check` runs the tests and validators locally.

## Credits

Inspired by [Studio Brightness ++](https://github.com/LitteRabbit-37/Studio-Brightness-PlusPlus)
by LitteRabbit-37, a Windows utility for Apple displays, itself built on
[studio-brightness](https://github.com/sfjohnson/studio-brightness) by Sam Johnson.
This is an independent Linux implementation; no code was copied from either project.

## License

MIT, see [LICENSE](LICENSE).
