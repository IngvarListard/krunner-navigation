#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
[[ ${HOME:-} == /* && $HOME != *$'\n'* && $HOME != *$'\r'* ]] || fail 'HOME must be an absolute path without newlines.'
command -v c++ >/dev/null || fail 'A C++ compiler (c++) is required.'
command -v systemctl >/dev/null || fail 'systemctl is required.'

source_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
data_dir=$HOME/.local/share/krunner-alt-navigation
service_dir=$HOME/.config/systemd/user/plasma-krunner.service.d
library=$data_dir/navigation.so
marker=$data_dir/.installed-by-krunner-alt-navigation
dropin=$service_dir/alt-navigation.conf
marker_text='krunner-alt-navigation managed installation'
legacy=$'[Service]\nEnvironment=LD_PRELOAD=%h/.local/share/krunner-alt-navigation/navigation.so'

# The dynamic loader splits LD_PRELOAD on spaces even inside a quoted
# systemd environment assignment. Use a runtime symlink with a space-free
# path instead, and escape the installed library path for ExecStartPre.
escaped_library=${library//\\/\\\\}
escaped_library=${escaped_library//\"/\\\"}
escaped_library=${escaped_library//%/%%}
escaped_library=${escaped_library//\$/\$\$}
escaped_library=${escaped_library//$'\t'/\\t}
config=$(printf '# Managed by krunner-alt-navigation; do not edit.\n[Service]\nRuntimeDirectory=krunner-alt-navigation\nExecStartPre=ln -sfn -- "%s" "%%t/krunner-alt-navigation/navigation.so"\nEnvironment="LD_PRELOAD=%%t/krunner-alt-navigation/navigation.so"' "$escaped_library")

owned_marker=false
if [[ -f $marker && ! -L $marker && $(<"$marker") == "$marker_text" ]]; then
    owned_marker=true
elif [[ -e $marker || -L $marker ]]; then
    fail "Refusing to replace an unrecognized file: $marker"
fi
legacy_dropin=false
if [[ -e $dropin || -L $dropin ]]; then
    [[ -f $dropin && ! -L $dropin ]] || fail "Refusing to replace an unrecognized file: $dropin"
    existing=$(<"$dropin")
    if [[ $existing == "$legacy" ]]; then
        legacy_dropin=true
    elif [[ $existing != "$config" ]]; then
        fail "Refusing to replace a modified or unrelated file: $dropin"
    fi
fi
if [[ -e $library || -L $library ]]; then
    [[ $owned_marker == true || $legacy_dropin == true ]] || fail "Refusing to replace an unrecognized file: $library"
    [[ -f $library && ! -L $library ]] || fail "Refusing to replace a non-regular file: $library"
fi

# Prefer pkg-config/pkgconf, but support Qt installations exposing only qmake6.
qt_flags=()
qt_found=false
for pc in pkg-config pkgconf; do
    if command -v "$pc" >/dev/null && "$pc" --exists Qt6Core Qt6Gui; then
        flags=$($pc --cflags --libs Qt6Core Qt6Gui) || fail "Could not query Qt 6 using $pc."
        # pkg-config emits shell-escaped flags, including paths containing spaces.
        eval "qt_flags=($flags)"
        qt_found=true
        break
    fi
done
if [[ $qt_found == false ]]; then
    command -v qmake6 >/dev/null || fail 'Qt 6 development files are required (pkg-config/pkgconf or qmake6).'
    qt_headers=$(qmake6 -query QT_INSTALL_HEADERS) || fail 'Could not query Qt 6 headers with qmake6.'
    qt_libs=$(qmake6 -query QT_INSTALL_LIBS) || fail 'Could not query Qt 6 libraries with qmake6.'
    [[ -f $qt_headers/QtCore/QCoreApplication && -d $qt_libs ]] || fail 'qmake6 did not report usable Qt 6 development paths.'
    qt_flags=("-I$qt_headers" "-I$qt_headers/QtCore" "-I$qt_headers/QtGui" "-L$qt_libs" -lQt6Gui -lQt6Core)
fi

umask 077
mkdir -p -- "$data_dir" "$service_dir"
lib_tmp= config_tmp= marker_tmp=
cleanup() { rm -f -- ${lib_tmp:+"$lib_tmp"} ${config_tmp:+"$config_tmp"} ${marker_tmp:+"$marker_tmp"}; }
trap cleanup EXIT
lib_tmp=$(mktemp "$data_dir/.navigation.so.XXXXXXXX")
config_tmp=$(mktemp "$service_dir/.alt-navigation.conf.XXXXXXXX")
marker_tmp=$(mktemp "$data_dir/.installed.XXXXXXXX")
if ! c++ -std=c++17 -fPIC -shared -o "$lib_tmp" "$source_dir/navigation.cpp" "${qt_flags[@]}"; then
    fail 'Compilation failed; check that the Qt 6 development packages are installed.'
fi
printf '%s\n' "$config" > "$config_tmp"
printf '%s\n' "$marker_text" > "$marker_tmp"
mv -f -- "$marker_tmp" "$marker"
marker_tmp=
mv -f -- "$lib_tmp" "$library"
lib_tmp=
mv -f -- "$config_tmp" "$dropin"
config_tmp=
systemctl --user daemon-reload || fail 'Installation completed, but the systemd user daemon could not be reloaded.'
systemctl --user restart plasma-krunner.service || fail 'Installation completed, but KRunner could not be restarted.'
printf 'Installed KRunner Alt+J/K navigation for the current user.\n'
