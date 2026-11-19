# Maintenance guidance

- Keep the installation per-user and scoped to the Plasma 6 KRunner systemd user service; do not modify the live system configuration when developing.
- Preserve ordinary arrow keys and other applications. Alt+J/K must follow the physical key positions for English and Russian layouts, including key releases and auto-repeat.
- The Qt event filter is loaded with `LD_PRELOAD`; prevent that environment variable from leaking to applications launched by KRunner.
- Keep `install.sh` and `uninstall.sh` symmetric and document changes to requirements, usage, security, and limitations in README.md. Recompile the library against the installed Qt 6 when installing.
