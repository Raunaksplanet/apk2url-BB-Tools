#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
cyan='\033[0;36m'
reset='\033[0m'

JOBS=$(nproc)

show_help() {
cat <<EOF
Usage: apk2url [OPTIONS] <APK | DIRECTORY>

Options:
  -h, --help    Show help and exit

Examples:
  apk2url app.apk
  apk2url apks/
EOF
}

# -------- ARG PARSING --------
[[ $# -eq 0 ]] && { show_help; exit 0; }

case "$1" in
    -h|--help) show_help; exit 0 ;;
esac

command -v apktool >/dev/null || { echo "apktool missing"; exit 1; }
command -v jadx >/dev/null || { echo "jadx missing"; exit 1; }
command -v parallel >/dev/null || { echo "gnu parallel missing"; exit 1; }

# -------- BANNER --------
printf "$green
 █████╗ ██████╗ ██╗  ██╗██████╗ ██╗   ██╗██████╗ ██╗
██╔══██╗██╔══██╗██║ ██╔╝╚════██╗██║   ██║██╔══██╗██║ v1.2
███████║██████╔╝█████╔╝  █████╔╝██║   ██║██████╔╝██║
██╔══██║██╔═══╝ ██╔═██╗ ██╔═══╝ ██║   ██║██╔══██╗██║
██║  ██║██║     ██║  ██╗███████╗╚██████╔╝██║  ██║███████╗
╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
$reset"

# -------- FUNCTIONS --------
process_apk() {
    APKPATH="$1"
    APKDIR="$(dirname "$APKPATH")"
    BASENAME="$(basename "$APKPATH" .apk)"

    DECOMPILEDIR="$APKDIR/decompiled/$BASENAME"
    APKTOOLDIR="$DECOMPILEDIR/apktool"
    JADXDIR="$DECOMPILEDIR/jadx"
    ENDPOINTDIR="$APKDIR/endpoints"

    mkdir -p "$APKTOOLDIR" "$JADXDIR" "$ENDPOINTDIR"
    rm -rf "$APKTOOLDIR" "$JADXDIR"

    printf "$yellow[~] SHA256: $(shasum -a 256 "$APKPATH" | awk '{print $1}')\n$reset"

    printf "$cyan[+] Apktool: $BASENAME\n$reset"
    apktool d "$APKPATH" -o "$APKTOOLDIR" >/dev/null 2>&1

    printf "$cyan[+] Jadx: $BASENAME\n$reset"
    jadx "$APKPATH" -d "$JADXDIR" >/dev/null 2>&1

    grep -rIoE '(\b(https?)://|www\.)[^"'\'' ]+' "$DECOMPILEDIR" \
        | awk -F':' '{sub(/^[^:]+:/,"");print}' | sort -u \
        > "$ENDPOINTDIR/${BASENAME}_endpoints.txt"

    grep -oE '((http|https)://[^/]+)' "$ENDPOINTDIR/${BASENAME}_endpoints.txt" \
        | awk -F/ '{print $1 "//" $3}' | sort -u \
        > "$ENDPOINTDIR/${BASENAME}_uniqurls.txt"
}

export -f process_apk
export red green yellow cyan reset

# -------- EXECUTION --------
if [ -d "$1" ]; then
    printf "$green[+] Parallel processing directory: $1 ($JOBS jobs)\n$reset"
    find "$1" -maxdepth 1 -name "*.apk" | parallel -j "$JOBS" process_apk {}
else
    process_apk "$1"
fi
