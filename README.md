# studio-brightness-linux

Brightness control for Apple displays on Linux: Cinema Displays, the Thunderbolt
Display, Studio Displays and the Pro Display XDR. A command-line tool (Python 3, no
dependencies) plus a small GTK4 window with a slider per display.

Apple displays have no DDC/CI, so brightness travels over the display's **USB cable**.
That cable must be plugged into the computer.

## Install

```sh
bash install.sh
```

This copies the tool to `~/.local/bin`, installs a udev rule so you don't need root,
and adds GNOME shortcuts: **Super+F2** brighter, **Super+F1** dimmer. To use other keys:

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
studio-brightness --notify up # also show a desktop notification
```

There's also a small GTK4 window with one slider per display: open **Display
Brightness** from the app menu, or run `studio-brightness-gui`. It needs GTK4 and
libadwaita for Python (`gir1.2-adw-1`, already present on GNOME desktops).

With several displays, every command applies to all of them unless you pick one with
`-d NAME` (the name shown by `list`).

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

## Credits

Inspired by [Studio Brightness ++](https://github.com/LitteRabbit-37/Studio-Brightness-PlusPlus)
by LitteRabbit-37, a Windows utility for Apple displays, itself built on
[studio-brightness](https://github.com/sfjohnson/studio-brightness) by Sam Johnson.
This is an independent Linux implementation; no code was copied from either project.

## License

MIT, see [LICENSE](LICENSE).
