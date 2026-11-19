#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
[[ ${HOME:-} == /* && $HOME != *$'\n'* && $HOME != *$'\r'* ]] || fail 'HOME must be an absolute path without newlines.'
command -v systemctl >/dev/null || fail 'systemctl is required.'

data_dir=$HOME/.local/share/krunner-alt-navigation
service_dir=$HOME/.config/systemd/user/plasma-krunner.service.d
library=$data_dir/navigation.so
marker=$data_dir/.installed-by-krunner-alt-navigation
dropin=$service_dir/alt-navigation.conf
marker_text='krunner-alt-navigation managed installation'
legacy=$'[Service]\nEnvironment=LD_PRELOAD=%h/.local/share/krunner-alt-navigation/navigation.so'
escaped_library=${library//\\/\\\\}
escaped_library=${escaped_library//\"/\\\"}
escaped_library=${escaped_library//%/%%}
escaped_library=${escaped_library//\$/\$\$}
escaped_library=${escaped_library//$'\t'/\\t}
config=$(printf '# Managed by krunner-alt-navigation; do not edit.\n[Service]\nRuntimeDirectory=krunner-alt-navigation\nExecStartPre=ln -sfn -- "%s" "%%t/krunner-alt-navigation/navigation.so"\nEnvironment="LD_PRELOAD=%%t/krunner-alt-navigation/navigation.so"' "$escaped_library")

owned_marker=false
if [[ -f $marker && ! -L $marker && $(<"$marker") == "$marker_text" ]]; then
    owned_marker=true
fi
owned_dropin=false
legacy_dropin=false
if [[ -e $dropin || -L $dropin ]]; then
    if [[ -f $dropin && ! -L $dropin ]]; then
        existing=$(<"$dropin")
        if [[ $existing == "$config" ]]; then
            owned_dropin=true
        elif [[ $existing == "$legacy" ]]; then
            owned_dropin=true
            legacy_dropin=true
        fi
    fi
    if [[ $owned_dropin == false ]]; then
        fail "The drop-in has been modified or is unrelated; leaving it and the library untouched: $dropin"
    fi
fi

if [[ $owned_dropin == true ]]; then
    rm -- "$dropin"
fi
if [[ $owned_marker == true || $legacy_dropin == true ]]; then
    if [[ -f $library && ! -L $library ]]; then
        rm -- "$library"
    elif [[ -e $library || -L $library ]]; then
        printf 'Warning: leaving non-regular library path untouched: %s\n' "$library" >&2
    fi
fi
if [[ $owned_marker == true ]]; then
    rm -- "$marker"
fi
# Remove only empty directories; unrelated files and configuration are retained.
rmdir -- "$data_dir" 2>/dev/null || :
rmdir -- "$service_dir" 2>/dev/null || :
systemctl --user daemon-reload || fail 'Files were removed, but the systemd user daemon could not be reloaded.'
systemctl --user restart plasma-krunner.service || fail 'Files were removed, but KRunner could not be restarted.'
printf 'Uninstalled KRunner Alt+J/K navigation for the current user.\n'
