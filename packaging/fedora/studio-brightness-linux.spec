Name:           studio-brightness-linux
Version:        %{?version}%{!?version:1.0.0}
Release:        1%{?dist}
Summary:        Brightness control for Apple displays
License:        MIT
URL:            https://github.com/mfat/studio-brightness-linux
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  make
# %%py3_shebang_fix, which turns the scripts' `/usr/bin/env python3` into /usr/bin/python3.
BuildRequires:  python3-devel
# %%{_udevrulesdir} and %%udev_rules_update.
BuildRequires:  systemd-rpm-macros
# Both validators run in %%check via `make check`.
BuildRequires:  desktop-file-utils
BuildRequires:  appstream

Requires:       python3-gobject
# Adw.ToolbarView in the window needs libadwaita 1.4.
Requires:       gtk4
Requires:       libadwaita >= 1.4
# The on-screen indicator is a GTK3 X11 popup with a cairo input shape.
Requires:       gtk3
Requires:       python3-cairo
Requires:       systemd-udev
# notify-send, for `studio-brightness --notify`.
Recommends:     libnotify

%description
Controls the brightness of Apple Cinema, Thunderbolt and Studio Displays and the
Pro Display XDR over their USB connection, since these displays have no DDC/CI.
Includes a command-line tool, a small GTK4 window with a slider per display and
an on-screen brightness indicator for keyboard shortcuts.

%prep
%autosetup -n %{name}-%{version}

%build
# Nothing to build: the scripts are installed as they are.

%install
%make_install PREFIX=%{_prefix} UDEVDIR=%{_udevrulesdir} MANDIR=%{_mandir}
%py3_shebang_fix %{buildroot}%{_bindir}/*

%check
make check

%post
%udev_rules_update
# Apply the rule to displays that are already plugged in, so they work without replugging.
if [ -d /run/udev ]; then
    udevadm trigger --action=add --subsystem-match=hidraw --subsystem-match=backlight || :
    udevadm trigger --action=add --subsystem-match=usb --property-match=DRIVER=usbhid || :
fi

%files
%license LICENSE
%doc README.md
%{_bindir}/studio-brightness
%{_bindir}/studio-brightness-gui
%{_bindir}/studio-brightness-osd
%{_datadir}/applications/io.github.mfat.StudioBrightness.desktop
%{_metainfodir}/io.github.mfat.StudioBrightness.metainfo.xml
%{_datadir}/icons/hicolor/scalable/apps/io.github.mfat.StudioBrightness.svg
%{_datadir}/icons/hicolor/symbolic/apps/io.github.mfat.StudioBrightness-symbolic.svg
%{_mandir}/man1/studio-brightness*.1*
%{_udevrulesdir}/70-studio-brightness.rules

%changelog
* Fri Oct 09 2026 Mehdi <mah.fat@gmail.com> - 1.0.0-1
- Initial release.
