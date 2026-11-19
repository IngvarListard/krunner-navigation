# KRunner Alt navigation

Navigate Plasma 6 KRunner results with **Alt+J** (down) and **Alt+K** (up). The shortcuts use the physical J and K key positions, so they work with English and Russian keyboard layouts. Normal arrow-key navigation remains available, and other applications are not modified.

## Requirements

- Linux with Plasma 6 KRunner managed by a systemd user service
- A working systemd user session
- A C++ compiler and Qt 6 development headers and libraries

## Install and uninstall

From this directory, run:

```sh
./install.sh
```

To remove the per-user installation, run:

```sh
./uninstall.sh
```

The installation and its KRunner service configuration apply only to the current user; they do not modify system-wide configuration or other users' sessions.

## How it works and limitations

The installer compiles a small Qt library and configures the KRunner user service to load it with `LD_PRELOAD`. The library installs an application-wide Qt event filter in KRunner, translating unmodified Alt+J/K key presses and releases into down/up arrow events. It clears `LD_PRELOAD` during startup so applications launched by KRunner do not inherit the library.

The mapping relies on native scan codes for the physical keys and is intended for standard Linux X11 and Wayland setups. Unusual keyboards, input stacks, or remappings may use different scan codes. Only Alt by itself is matched; combinations with additional modifiers are left unchanged. This affects KRunner's Qt key events, not global shortcuts or other applications.

`LD_PRELOAD` loads native code into KRunner with your user permissions. Install and run only code you trust, and keep the installed library and its parent directories protected from modification by other users. The library is built against your installed Qt 6; after a Qt upgrade, rerun `./install.sh` to recompile it, especially if Qt's binary compatibility changes. KRunner must be started through its systemd user service for the drop-in to take effect.
