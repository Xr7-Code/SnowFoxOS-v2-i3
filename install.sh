#!/bin/bash
# ============================================================
#  SnowFoxOS v2.1 — Installer
#  Basis: Debian 12 (Bookworm) minimal
#  Ausführen: sudo bash install.sh
# ============================================================

# KEIN globales set -e — wir behandeln Fehler manuell
GREEN='\033[0;32m'; RED='\033[0;31m'; PURPLE='\033[0;35m'; ORANGE='\033[0;33m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Root-Check ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${BOLD}Bitte mit sudo ausführen: sudo bash install.sh${RESET}"
    exit 1
fi

# ── Log ─────────────────────────────────────────────────────
LOG="/tmp/snowfox_install.log"
touch "$LOG"
chmod 644 "$LOG"
echo "=== SnowFoxOS Installer gestartet: $(date) ===" > "$LOG"

run() {
    echo ">>> $*" >> "$LOG"
    "$@" >> "$LOG" 2>&1
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "!!! FEHLER (exit $rc): $*" >> "$LOG"
    fi
    return $rc
}

try() {
    # Wie run(), aber bricht bei Fehler NICHT ab
    echo ">>> [optional] $*" >> "$LOG"
    "$@" >> "$LOG" 2>&1 || echo "!!! WARNUNG (exit $?): $*" >> "$LOG"
}

die() {
    clear
    echo -e "${RED}${BOLD}FEHLER: $1${RESET}"
    echo -e "Siehe Log: $LOG"
    exit 1
}

# ── whiptail ────────────────────────────────────────────────
if ! command -v whiptail &>/dev/null; then
    apt-get install -y whiptail >> "$LOG" 2>&1 || die "whiptail konnte nicht installiert werden"
fi

export TERM=xterm-256color
export NEWT_COLORS='
root=,black
window=white,black
border=purple,black
title=purple,black
button=black,purple
actbutton=white,purple
checkbox=white,black
actcheckbox=black,purple
entry=white,black
label=white,black
listbox=white,black
actlistbox=black,purple
textbox=white,black
acttextbox=black,purple
helpline=black,purple
roottext=purple,black
'

# ── Benutzer ────────────────────────────────────────────────
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    TARGET_USER=$(whiptail --title "SnowFoxOS Installer" \
        --inputbox "Für welchen Benutzer soll SnowFoxOS installiert werden?" \
        8 60 "" 3>&1 1>&2 2>&3) || exit 1
fi
TARGET_HOME="/home/$TARGET_USER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ ! -d "$TARGET_HOME" ]] && die "Home-Verzeichnis $TARGET_HOME nicht gefunden."
echo ">>> Benutzer: $TARGET_USER, Home: $TARGET_HOME" >> "$LOG"

# ============================================================
# TUI — Alle Eingaben sammeln BEVOR die Installation startet
# ============================================================

# SCREEN 0 — Willkommen
whiptail --title "SnowFoxOS v2.1 Installer" --msgbox \
"
 ███████╗███╗  ██╗ ██████╗ ██╗    ██╗███████╗ ██████╗ ██╗  ██╗
 ██╔════╝████╗ ██║██╔═══██╗██║    ██║██╔════╝██╔═══██╗ ╚██╗██╔╝
 ███████╗██╔██╗██║██║   ██║██║ █╗ ██║█████╗  ██║   ██║  ╚███╔╝
 ╚════██║██║╚████║██║   ██║██║███╗██║██╔══╝  ██║   ██║  ██╔██╗
 ███████║██║ ╚███║╚██████╔╝╚███╔███╔╝██║     ╚██████╔╝ ██╔╝╚██╗
 ╚══════╝╚═╝  ╚══╝ ╚═════╝  ╚══╝╚══╝ ╚═╝     ╚═════╝  ╚═╝  ╚═╝

  Willkommen beim SnowFoxOS v2.1 Installer.

  Ein schlankes, privacy-orientiertes i3-System
  auf Basis von Debian 12.

  Benutzer: $TARGET_USER
  Log wird geschrieben nach: $LOG

  Drücke ENTER um fortzufahren." \
22 72

# SCREEN 1 — Lizenz
whiptail --title "SnowFox Public License v1.1" --scrolltext --msgbox \
"SnowFox Public License (SFL) v1.1
Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)

────────────────────────────────────────
1. ERLAUBTE NUTZUNG
────────────────────────────────────────
Du darfst:
- Diese Software fuer persoenliche, bildungsbezogene oder
  kommerzielle Zwecke nutzen
- Den Quellcode studieren
- Die Software fuer eigene Zwecke anpassen
- Originale oder modifizierte Versionen verteilen, sofern
  alle Bedingungen dieser Lizenz erfuellt sind

────────────────────────────────────────
2. VERTEILUNGSBEDINGUNGEN
────────────────────────────────────────
Bei der Weitergabe musst du:
- Diese Lizenz vollstaendig beifuegen
- Alle Urheberrechtshinweise beibehalten
- Alle Aenderungen klar kennzeichnen
- Ableitungen unter derselben Lizenz (SFL v1.1) verteilen

────────────────────────────────────────
3. MARKEN- UND NAMENSNUTZUNG
────────────────────────────────────────
- Der Name 'SnowFoxOS' darf nur fuer Distributionen verwendet
  werden die dem urspruenglichen Projektziel treu bleiben.
- Abgeleitete Werke duerfen sich nicht als das originale
  SnowFoxOS ausgeben.

────────────────────────────────────────
4. PRIVACY UND NUTZERRESPEKT
────────────────────────────────────────
- Keine unautorisierten Telemetrie- oder Tracking-Funktionen
- Jede Datensammlung muss transparent sein und Zustimmung
  erfordern
- Die Software darf Nutzer nicht absichtlich schaedigen

────────────────────────────────────────
5. EINSCHRAENKUNGEN
────────────────────────────────────────
Du darfst nicht:
- Diese Lizenz entfernen oder veraendern
- Die Software ohne Beibehaltung der Zuschreibung weitergeben
- Den Ursprung der Software falsch darstellen

────────────────────────────────────────
6. KEINE GEWAEHRLEISTUNG
────────────────────────────────────────
Diese Software wird 'so wie sie ist' bereitgestellt.
Der Autor haftet nicht fuer Schaeden aus der Nutzung.

────────────────────────────────────────
7. ABSCHLUSSERKLARUNG
────────────────────────────────────────
'Dein Computer gehoert dir.'
-- Alexander Valentin Ludwig" \
36 72

if ! whiptail --title "Lizenz akzeptieren" --yesno \
"Hast du die SnowFox Public License v1.1 gelesen
und akzeptierst du die Bedingungen?

Ohne Zustimmung kann die Installation nicht
fortgesetzt werden." 12 60; then
    clear
    echo -e "${RED}${BOLD}Abgebrochen — Lizenz nicht akzeptiert.${RESET}"
    exit 1
fi

# SCREEN 2 — Optionale Pakete
OPTIONAL_CHOICES=$(whiptail --title "Optionale Pakete" \
    --checklist \
"Waehle die Komponenten die installiert werden sollen.
Leertaste = auswaehlen/abwaehlen  |  Tab = OK/Abbrechen" \
    20 68 8 \
    "THUNAR"     "Dateimanager (grafisch, empfohlen)"  ON  \
    "VSCODE"     "VSCodium (Code-Editor)"              OFF \
    "ONLYOFFICE" "OnlyOffice (Office-Suite)"           OFF \
    "VLC"        "VLC Media Player"                    OFF \
    "GIMP"       "GIMP (Bildbearbeitung)"              OFF \
    "STEAM"      "Steam + GameMode + Proton GE"        OFF \
    3>&1 1>&2 2>&3) || { clear; echo "Abgebrochen."; exit 1; }

# SCREEN 3 — Browser
BROWSER_CHOICE=$(whiptail --title "Browser waehlen" --menu \
"Waehle deinen Standard-Browser:" \
    16 68 5 \
    "1" "Zen Browser   (Firefox-Basis, Privacy — empfohlen)" \
    "2" "LibreWolf     (gehaerteter Firefox, max. Privacy)" \
    "3" "Brave         (Chromium-Basis, Privacy)" \
    "4" "Firefox-ESR   (Standard, stabil)" \
    "5" "Chromium      (leicht, schnell)" \
    3>&1 1>&2 2>&3) || { clear; echo "Abgebrochen."; exit 1; }

# SCREEN 4 — Editor
EDITOR_CHOICE=$(whiptail --title "Standard-Texteditor" --menu \
"Welcher Editor soll als Standard gesetzt werden?" \
    12 68 2 \
    "1" "Mousepad  (leicht, GTK)" \
    "2" "VSCodium  (nur wenn oben gewaehlt)" \
    3>&1 1>&2 2>&3) || EDITOR_CHOICE="1"

# SCREEN 5 — Zusammenfassung
case "$BROWSER_CHOICE" in
    1) BROWSER_NAME="Zen Browser" ;;
    2) BROWSER_NAME="LibreWolf" ;;
    3) BROWSER_NAME="Brave" ;;
    4) BROWSER_NAME="Firefox-ESR" ;;
    5) BROWSER_NAME="Chromium" ;;
    *) BROWSER_NAME="Keiner" ;;
esac
[[ "$EDITOR_CHOICE" == "2" ]] && EDITOR_NAME="VSCodium" || EDITOR_NAME="Mousepad"

OPT_LIST=""
for pkg in THUNAR VSCODE ONLYOFFICE VLC GIMP STEAM; do
    echo "$OPTIONAL_CHOICES" | grep -q "$pkg" && OPT_LIST+="  + $pkg\n"
done
[[ -z "$OPT_LIST" ]] && OPT_LIST="  (keine)\n"

if ! whiptail --title "Zusammenfassung" --yesno \
"Folgendes wird installiert:

  Benutzer : $TARGET_USER
  Browser  : $BROWSER_NAME
  Editor   : $EDITOR_NAME

  Optionale Pakete:
$(echo -e "$OPT_LIST")
  Immer enthalten:
  + i3 + Polybar + Rofi + Dunst + Picom
  + XanMod LTS Kernel (x64v3)
  + PipeWire Audio + GPU-Treiber
  + ufw + MAC-Rand. + DNS-over-TLS
  + zram + earlyoom + tlp + snowfox CLI

Installation jetzt starten?" \
28 68; then
    clear; echo "Abgebrochen."; exit 0
fi

# ============================================================
# INSTALLATIONS-SCHRITT-ANZEIGE
# Läuft direkt in der Hauptshell — keine Subshell, keine
# Variablen-Probleme. whiptail zeigt Schritt-Info, dann
# läuft apt im Vordergrund (sichtbar im Terminal dahinter).
# ============================================================

STEP=0
TOTAL_STEPS=11

step_start() {
    STEP=$((STEP+1))
    local title="$1"
    local desc="$2"
    echo "" >> "$LOG"
    echo "=== SCHRITT $STEP/$TOTAL_STEPS: $title ===" >> "$LOG"
    echo "" >> "$LOG"
    # Kurz whiptail zeigen, dann verschwindet es — apt läuft im Terminal
    whiptail --title "SnowFoxOS — Schritt $STEP von $TOTAL_STEPS" \
        --infobox \
"  $title

  $desc

  Ausgabe laeuft im Terminal.
  Log: $LOG" \
        10 60
    echo -e "\n${PURPLE}${BOLD}━━━  [$STEP/$TOTAL_STEPS] $title  ━━━${RESET}"
    echo -e "${ORANGE}$desc${RESET}\n"
}

step_ok() {
    echo -e "${GREEN}${BOLD}✓ $1${RESET}"
    echo "=== OK: $1 ===" >> "$LOG"
}

# ============================================================
# SCHRITT 1 — System & Repos
# ============================================================
step_start "System & Repos" "Paketquellen einrichten & System aktualisieren..."

DKMS_HOOKS=(/etc/kernel/postinst.d/dkms /etc/kernel/prerm.d/dkms /usr/lib/kernel/install.d/50-dkms.install)
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "$hook" ]] && mv "$hook" "${hook}.snowfox-bak" && echo "DKMS hook deaktiviert: $hook" >> "$LOG"
done

cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
EOF

run dpkg --add-architecture i386
run apt-get update -qq
try dpkg --configure -a
try apt-get -f install -y
run apt-get upgrade -y
run apt-get install -y \
    curl wget git unzip build-essential ca-certificates gnupg \
    pciutils usbutils htop btop neofetch bash-completion \
    xdg-utils xdg-user-dirs rfkill imagemagick bc \
    xorg xinit x11-utils x11-xserver-utils xclip xdotool dbus-x11
try sudo -u "$TARGET_USER" xdg-user-dirs-update
step_ok "System & Repos"

# ============================================================
# SCHRITT 2 — XanMod Kernel
# ============================================================
step_start "XanMod Kernel" "XanMod LTS Kernel installieren (kann einige Minuten dauern)..."

curl -fSL https://dl.xanmod.org/archive.key \
    | gpg --dearmor --yes -o /usr/share/keyrings/xanmod-archive-keyring.gpg >> "$LOG" 2>&1 \
    || echo "WARNUNG: XanMod GPG Key fehlgeschlagen" >> "$LOG"

echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' \
    > /etc/apt/sources.list.d/xanmod-kernel.list

run apt-get update -qq

echo ">>> Installiere linux-xanmod-lts-x64v3..." >> "$LOG"
DEBIAN_FRONTEND=noninteractive apt-get install -y linux-xanmod-lts-x64v3 >> "$LOG" 2>&1
XANMOD_RC=$?
if [[ $XANMOD_RC -ne 0 ]]; then
    echo "WARNUNG: XanMod fehlgeschlagen (exit $XANMOD_RC) — fahre fort" >> "$LOG"
    echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} XanMod Kernel fehlgeschlagen — Installation wird fortgesetzt"
else
    # Alte Kernel aufräumen
    CURRENT_KERNEL=$(uname -r)
    for pkg in $(dpkg --list 2>/dev/null | awk '/^ii.*linux-image-[0-9]/{print $2}' | grep -v "$CURRENT_KERNEL" | grep -v "xanmod"); do
        try apt-get purge -y "$pkg"
    done
    try apt-get autoremove -y
    try update-grub
fi
step_ok "XanMod Kernel"

# ============================================================
# SCHRITT 3 — Hardware & GPU
# ============================================================
step_start "Hardware & GPU" "GPU erkennen und passende Treiber installieren..."

IS_LAPTOP=false
[[ "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" =~ ^(8|9|10|14)$ ]] && IS_LAPTOP=true
echo "IS_LAPTOP=$IS_LAPTOP" >> "$LOG"

if grep -m1 "vendor_id" /proc/cpuinfo | grep -qi "AuthenticAMD"; then
    try apt-get install -y amd64-microcode
else
    try apt-get install -y intel-microcode
fi

GPU_INFO=$(lspci | grep -iE 'vga|3d|display')
HAS_NVIDIA=false; HAS_AMD=false
echo "$GPU_INFO" | grep -qi "nvidia" && HAS_NVIDIA=true
echo "$GPU_INFO" | grep -qi "amd"    && HAS_AMD=true
echo "GPU: NVIDIA=$HAS_NVIDIA AMD=$HAS_AMD" >> "$LOG"

if $HAS_NVIDIA; then
    try apt-get install -y clang-19 lld-19
    try update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-19  100
    try update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-19 100
    try update-alternatives --install /usr/bin/lld     lld     /usr/bin/lld-19    100
    try update-alternatives --set clang  /usr/bin/clang-19
    try update-alternatives --set lld    /usr/bin/lld-19

    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub \
        | gpg --dearmor | tee /usr/share/keyrings/nvidia-cuda-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /" \
        > /etc/apt/sources.list.d/nvidia-cuda.list
    cat > /etc/apt/preferences.d/nvidia-cuda << 'EOF'
Package: cuda-drivers* nvidia-* libcuda* libnvidia-*
Pin: origin "developer.download.nvidia.com"
Pin-Priority: 900
Package: *
Pin: release o=Debian
Pin-Priority: 500
EOF
    run apt-get update -qq
    try apt-get purge -y nvidia-driver nvidia-kernel-dkms
    run apt-get install -y cuda-drivers-580 libvulkan1 libvulkan1:i386 nvidia-vulkan-icd nvidia-vulkan-icd:i386
    $HAS_AMD && try pip3 install envycontrol --break-system-packages

    XANMOD_KERNEL=$(ls /lib/modules 2>/dev/null | grep xanmod | sort -V | tail -1)
    NVIDIA_VER=$(ls /var/lib/dkms/nvidia/ 2>/dev/null | sort -V | tail -1)
    [[ -n "$XANMOD_KERNEL" && -n "$NVIDIA_VER" ]] && try dkms install nvidia/"$NVIDIA_VER" -k "$XANMOD_KERNEL"

elif $HAS_AMD; then
    run apt-get install -y firmware-amd-graphics mesa-vulkan-drivers mesa-va-drivers
else
    try apt-get install -y intel-media-va-driver-non-free i965-va-driver
fi

if $IS_LAPTOP; then
    run apt-get install -y tlp tlp-rdw thermald xserver-xorg-input-libinput
    try systemctl enable tlp thermald
fi
step_ok "Hardware & GPU"

# ============================================================
# SCHRITT 4 — i3 Desktop
# ============================================================
step_start "i3 Desktop" "i3, Polybar, Rofi, Dunst, Picom und weitere Tools..."

run apt-get install -y \
    i3 i3status i3lock polybar rofi dunst libnotify-bin feh redshift \
    scrot brightnessctl playerctl network-manager network-manager-gnome \
    bluez blueman fonts-inter fonts-noto fonts-noto-color-emoji \
    fonts-font-awesome papirus-icon-theme arc-theme xsettingsd lxpolkit \
    lxappearance picom xss-lock xserver-xorg-input-libinput clipit \
    cups cups-bsd cups-client printer-driver-splix

try systemctl enable bluetooth

# Touchpad
mkdir -p /etc/X11/xorg.conf.d
if [[ -f "$SCRIPT_DIR/configs/xorg/30-touchpad.conf" ]]; then
    cp "$SCRIPT_DIR/configs/xorg/30-touchpad.conf" /etc/X11/xorg.conf.d/30-touchpad.conf
else
    cat > /etc/X11/xorg.conf.d/30-touchpad.conf << 'EOF'
Section "InputClass"
    Identifier "devname"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "ClickMethod" "clickfinger"
    Option "NaturalScrolling" "true"
EndSection
EOF
fi

# i3 Autostart von TTY1
BASH_PROFILE="$TARGET_HOME/.bash_profile"
if ! grep -q "startx" "$BASH_PROFILE" 2>/dev/null; then
    printf '\n# SnowFoxOS — i3 automatisch starten\n[ "$(tty)" = "/dev/tty1" ] && exec startx\n' >> "$BASH_PROFILE"
fi

cat > "$TARGET_HOME/.xinitrc" << 'EOF'
#!/bin/sh
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games
[ -f /usr/bin/dbus-launch ] && eval $(/usr/bin/dbus-launch --sh-syntax --exit-with-session)
exec i3
EOF
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.xinitrc"
chmod +x "$TARGET_HOME/.xinitrc"
step_ok "i3 Desktop"

# ============================================================
# SCHRITT 5 — Audio
# ============================================================
step_start "Audio" "PipeWire Audio-Stack installieren..."

run apt-get install -y pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol pulseaudio-utils
try apt-get remove --purge -y pulseaudio
try sudo -u "$TARGET_USER" systemctl --user enable pipewire pipewire-pulse wireplumber
step_ok "Audio"

# ============================================================
# SCHRITT 6 — Apps
# ============================================================
step_start "Apps" "Terminal & optionale Apps installieren..."

run apt-get install -y kitty mc mousepad ristretto file-roller mpv ffmpeg

echo "$OPTIONAL_CHOICES" | grep -q "THUNAR" && \
    run apt-get install -y thunar thunar-archive-plugin thunar-volman gvfs gvfs-backends
echo "$OPTIONAL_CHOICES" | grep -q "VLC"    && run apt-get install -y vlc
echo "$OPTIONAL_CHOICES" | grep -q "GIMP"   && run apt-get install -y gimp

if echo "$OPTIONAL_CHOICES" | grep -q "VSCODE"; then
    curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor | tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main" \
        > /etc/apt/sources.list.d/vscodium.list
    run apt-get update -qq
    try apt-get install -y codium
fi

if echo "$OPTIONAL_CHOICES" | grep -q "ONLYOFFICE"; then
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE \
        | gpg --dearmor -o /etc/apt/keyrings/onlyoffice.gpg
    echo "deb [signed-by=/etc/apt/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" \
        > /etc/apt/sources.list.d/onlyoffice.list
    run apt-get update -qq
    try apt-get install -y onlyoffice-desktopeditors
fi

curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp >> "$LOG" 2>&1 && chmod +x /usr/local/bin/yt-dlp

step_ok "Apps"

# ============================================================
# SCHRITT 7 — Browser
# ============================================================
step_start "Browser" "Browser installieren: $BROWSER_NAME..."

DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop"

case "$BROWSER_CHOICE" in
    1)
        ZEN_URL=$(curl -s https://api.github.com/repos/zen-browser/desktop/releases/latest \
            | grep "browser_download_url.*x86_64.AppImage\"" | head -1 | cut -d '"' -f 4)
        if [[ -n "$ZEN_URL" ]]; then
            curl -L "$ZEN_URL" -o /opt/zen-browser.AppImage >> "$LOG" 2>&1 && chmod +x /opt/zen-browser.AppImage
            try apt-get install -y libfuse2
            cat > /usr/share/applications/zen-browser.desktop << 'EOF'
[Desktop Entry]
Name=Zen Browser
Comment=Privacy-focused web browser
Exec=/opt/zen-browser.AppImage %u
Icon=firefox
Type=Application
Categories=Network;WebBrowser;
MimeType=x-scheme-handler/http;x-scheme-handler/https;text/html;
StartupNotify=true
EOF
            DEFAULT_BROWSER_DESKTOP="zen-browser.desktop"
        else
            echo "WARNUNG: Zen Download fehlgeschlagen, Fallback Firefox-ESR" >> "$LOG"
            run apt-get install -y firefox-esr
        fi ;;
    2)
        curl -fsSL https://deb.librewolf.net/keyring.gpg \
            | gpg --dearmor | tee /usr/share/keyrings/librewolf.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/librewolf.gpg arch=amd64] https://deb.librewolf.net bookworm main" \
            > /etc/apt/sources.list.d/librewolf.list
        run apt-get update -qq
        try apt-get install -y librewolf
        DEFAULT_BROWSER_DESKTOP="librewolf.desktop" ;;
    3)
        curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
            | tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
            > /etc/apt/sources.list.d/brave-browser.list
        run apt-get update -qq
        run apt-get install -y brave-browser
        DEFAULT_BROWSER_DESKTOP="brave-browser.desktop" ;;
    4)
        run apt-get install -y firefox-esr
        DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop" ;;
    5)
        run apt-get install -y chromium
        DEFAULT_BROWSER_DESKTOP="chromium.desktop" ;;
esac
step_ok "Browser"

# ============================================================
# SCHRITT 8 — Steam & Gaming
# ============================================================
step_start "Gaming" "Steam & GameMode..."

if echo "$OPTIONAL_CHOICES" | grep -q "STEAM"; then
    run apt-get install -y steam steam-devices libvulkan1 libvulkan1:i386 \
        vulkan-tools libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386 gamemode
    try systemctl enable gamemoded
    PROTON_GE_URL=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest \
        | grep "browser_download_url.*tar.gz" | cut -d '"' -f 4)
    if [[ -n "$PROTON_GE_URL" ]]; then
        curl -L "$PROTON_GE_URL" -o /tmp/proton-ge.tar.gz >> "$LOG" 2>&1
        mkdir -p "$TARGET_HOME/.steam/root/compatibilitytools.d"
        tar -xzf /tmp/proton-ge.tar.gz -C "$TARGET_HOME/.steam/root/compatibilitytools.d/"
        rm -f /tmp/proton-ge.tar.gz
        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.steam/root/compatibilitytools.d/"
    fi
    step_ok "Steam & GameMode"
else
    echo "Steam übersprungen (nicht ausgewählt)" >> "$LOG"
    step_ok "Gaming (übersprungen)"
fi

# ============================================================
# SCHRITT 9 — Performance & Sicherheit
# ============================================================
step_start "Performance & Sicherheit" "Firewall, zram, DNS-over-TLS, sysctl..."

run apt-get install -y zram-tools earlyoom ufw
command -v tlp &>/dev/null || run apt-get install -y tlp tlp-rdw

cat > /etc/default/zramswap << 'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF

try systemctl enable zramswap earlyoom tlp

cat > /etc/sysctl.d/99-snowfox.conf << 'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.use_tempaddr=2
net.ipv6.conf.default.use_tempaddr=2
EOF

grep -q "tmpfs /tmp" /etc/fstab || \
    echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab

ufw default deny incoming  >> "$LOG" 2>&1
ufw default allow outgoing >> "$LOG" 2>&1
ufw --force enable         >> "$LOG" 2>&1

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/99-snowfox-privacy.conf << 'EOF'
[device]
wifi.scan-rand-mac-address=yes
[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
connection.stable-id=${CONNECTION}/${BOOT}
EOF

mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/snowfox.conf << 'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
FallbackDNS=8.8.8.8
DNSSEC=yes
DNSOverTLS=yes
EOF
try systemctl enable systemd-resolved

for svc in avahi-daemon cups-browsed ModemManager colord; do
    try systemctl disable "$svc"
done
sed -i 's/#HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf
step_ok "Performance & Sicherheit"

# ============================================================
# SCHRITT 10 — Plymouth & Branding
# ============================================================
step_start "Branding" "Boot-Screen & OS-Identität..."

try apt-get install -y plymouth plymouth-themes
PLYMOUTH_DIR="/usr/share/plymouth/themes/snowfox"
mkdir -p "$PLYMOUTH_DIR"

cat > "$PLYMOUTH_DIR/snowfox.plymouth" << 'EOF'
[Plymouth Theme]
Name=SnowFox
Description=SnowFoxOS Boot Theme
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/snowfox
ScriptFile=/usr/share/plymouth/themes/snowfox/snowfox.script
EOF

cat > "$PLYMOUTH_DIR/snowfox.script" << 'EOF'
wallpaper_image = Image("background.png");
screen_width = Window.GetWidth(); screen_height = Window.GetHeight();
wallpaper_sprite = Sprite(wallpaper_image);
wallpaper_sprite.SetX(screen_width / 2 - wallpaper_image.GetWidth() / 2);
wallpaper_sprite.SetY(screen_height / 2 - wallpaper_image.GetHeight() / 2);
logo_image = Image("logo.png");
logo_sprite = Sprite(logo_image);
logo_sprite.SetX(screen_width / 2 - logo_image.GetWidth() / 2);
logo_sprite.SetY(screen_height / 2 - logo_image.GetHeight() / 2);
EOF

[[ -f "$SCRIPT_DIR/assets/fuchs.png" ]] && \
    try convert "$SCRIPT_DIR/assets/fuchs.png" -resize 200x200 "$PLYMOUTH_DIR/logo.png"
try convert -size 1920x1080 xc:#0f0f0f "$PLYMOUTH_DIR/background.png"
try plymouth-set-default-theme snowfox
try update-initramfs -u

cat > /etc/os-release << 'EOF'
PRETTY_NAME="SnowFoxOS 2.1"
NAME="SnowFoxOS"
ID=debian
ID_LIKE=debian
ANSI_COLOR="0;35"
EOF
echo "snowfox"       > /etc/hostname
echo "SnowFoxOS 2.1" > /etc/issue
step_ok "Branding"

# ============================================================
# SCHRITT 11 — Konfiguration & Finishing
# ============================================================
step_start "Konfiguration" "Configs kopieren, MIME-Typen setzen, CLI installieren..."

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR/neofetch" "$TARGET_HOME/Pictures/wallpapers"

# Picom minimal Config
cat > "$CONFIG_DIR/picom.conf" << 'EOF'
backend = "xrender";
vsync = false;
shadow = false;
fading = false;
corner-radius = 8;
rounded-corners-exclude = [
    "class_g = 'Polybar'",
    "window_type = 'dock'",
    "window_type = 'desktop'"
];
opacity-rule = [
    "95:class_g = 'kitty' && !focused",
    "100:class_g = 'kitty' && focused"
];
wintypes: {
    dock          = { shadow = false; };
    popup_menu    = { shadow = false; opacity = 1.0; };
    dropdown_menu = { shadow = false; opacity = 1.0; };
    tooltip       = { shadow = false; opacity = 1.0; };
};
EOF

# Neofetch
cat > "$CONFIG_DIR/neofetch/config.conf" << NEOF
print_info() {
    info title; info underline
    info "OS" distro; info "Kernel" kernel; info "Uptime" uptime
    info "Packages" packages; info "Shell" shell
    info "Resolution" resolution; info "WM" wm
    info "CPU" cpu; info "GPU" gpu; info "Memory" memory
}
image_backend="ascii"
image_source="$CONFIG_DIR/neofetch/snowfox.txt"
ascii_colors=(5 7)
NEOF

cat > "$CONFIG_DIR/neofetch/snowfox.txt" << 'ASCIIEOF'
                .... .....-
   ..       ... ..- ........
   :@..........@-:...........=
   ::-...........: :...........
   ............... -::: ........
   :..........::::: - :.:........
   :..::@:...@...::     .........
    ::.... .:.: ................:-
  :.   : :.@. ::...............::
  .:......::::..............:.::-
   ..:......................::::
    :...::................::::-
      ::.............::::::::
        :::::::::::::::--:
              ----------
ASCIIEOF

# Repo-Configs kopieren (picom.conf aus dem Repo überspringen — oben schon gesetzt)
if [[ -d "$SCRIPT_DIR/configs" ]]; then
    for item in "$SCRIPT_DIR/configs/"*; do
        name=$(basename "$item")
        [[ "$name" == "picom.conf" ]] && continue
        cp -r "$item" "$CONFIG_DIR/$name" >> "$LOG" 2>&1
    done
    echo "Configs aus Repo kopiert" >> "$LOG"
else
    echo "WARNUNG: configs/-Verzeichnis nicht gefunden" >> "$LOG"
fi

[[ -d "$SCRIPT_DIR/wallpapers" ]] && cp -r "$SCRIPT_DIR/wallpapers/"* "$TARGET_HOME/Pictures/wallpapers/"

# modprobe
if [[ -d "$SCRIPT_DIR/configs/modprobe" ]]; then
    try cp "$SCRIPT_DIR/configs/modprobe/amdgpu.conf" /etc/modprobe.d/
    try cp "$SCRIPT_DIR/configs/modprobe/nvidia.conf"  /etc/modprobe.d/
    try update-initramfs -u
fi

# MIME-Typen
[[ "$EDITOR_CHOICE" == "2" ]] && DEFAULT_EDITOR_DESKTOP="codium.desktop" || DEFAULT_EDITOR_DESKTOP="mousepad.desktop"
cat > "$CONFIG_DIR/mimeapps.list" << MEOF
[Default Applications]
inode/directory=thunar.desktop
text/plain=$DEFAULT_EDITOR_DESKTOP
text/x-python=$DEFAULT_EDITOR_DESKTOP
text/x-shellscript=$DEFAULT_EDITOR_DESKTOP
x-scheme-handler/http=$DEFAULT_BROWSER_DESKTOP
x-scheme-handler/https=$DEFAULT_BROWSER_DESKTOP
text/html=$DEFAULT_BROWSER_DESKTOP
application/pdf=$DEFAULT_BROWSER_DESKTOP
image/png=ristretto.desktop
image/jpeg=ristretto.desktop
video/mp4=mpv.desktop
audio/mpeg=mpv.desktop
application/zip=org.gnome.FileRoller.desktop
application/x-tar=org.gnome.FileRoller.desktop
MEOF

# snowfox CLI
[[ -f "$SCRIPT_DIR/snowfox" ]] && \
    cp "$SCRIPT_DIR/snowfox" /usr/local/bin/snowfox && chmod +x /usr/local/bin/snowfox
[[ -f "$SCRIPT_DIR/snowfox-greeting.sh" ]] && \
    cp "$SCRIPT_DIR/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting && chmod +x /usr/local/bin/snowfox-greeting
[[ -f "$SCRIPT_DIR/configs/powermenu.sh" ]] && \
    cp "$SCRIPT_DIR/configs/powermenu.sh" /usr/local/bin/snowfox-powermenu && chmod +x /usr/local/bin/snowfox-powermenu

grep -q "snowfox-greeting" "$TARGET_HOME/.bashrc" 2>/dev/null || \
    printf '\n# SnowFoxOS Greeting\n[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting\n' >> "$TARGET_HOME/.bashrc"

# Fritz USB
try apt-get install -y firmware-misc-nonfree
lsusb 2>/dev/null | grep -qi "fritz\|0x0bda\|2357" && try modprobe mt76x2u

# Berechtigungen finalisieren
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"
chmod +x "$TARGET_HOME/.xinitrc" "$TARGET_HOME/.bash_profile" 2>/dev/null || true

# DKMS-Hooks wiederherstellen
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "${hook}.snowfox-bak" ]] && mv "${hook}.snowfox-bak" "$hook"
done

echo "=== Installation abgeschlossen: $(date) ===" >> "$LOG"
step_ok "Konfiguration"

# ============================================================
# FERTIG
# ============================================================
whiptail --title "Installation abgeschlossen!" --msgbox \
"  SnowFoxOS v2.1 erfolgreich installiert!

  Installiert:
  + i3 + Polybar + Rofi + Picom + Dunst
  + XanMod LTS Kernel (x64v3)
  + PipeWire Audio
  + GPU-Treiber (automatisch)
  + ufw Firewall (aktiv)
  + MAC-Randomisierung & DNS-over-TLS
  + zram + earlyoom + tlp
  + snowfox CLI

  Log: $LOG

  Druecke ENTER — System startet neu." \
22 62

clear
echo -e "${GREEN}${BOLD}SnowFoxOS installiert. Starte neu...${RESET}"
sleep 2
reboot
