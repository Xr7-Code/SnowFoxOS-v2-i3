#!/bin/bash
# ============================================================
#  SnowFoxOS v2.1 — Installer mit whiptail TUI
#  Basis: Debian 12 (Bookworm) minimal
#  Desktop: i3 + Polybar + Rofi + Dunst + i3lock
#  Ausführen: sudo bash install.sh
# ============================================================

set -e

# ── Farben für Konsolenausgabe ───────────────────────────────
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${PURPLE}${BOLD}[SnowFox]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[FEHLER]${RESET} $1"; exit 1; }

# ── Root-Check ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    error "Bitte mit sudo ausführen: sudo bash install.sh"
fi

# ── whiptail sicherstellen ───────────────────────────────────
if ! command -v whiptail &>/dev/null; then
    info "Installiere whiptail..."
    apt-get install -y whiptail -qq
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

# ── Benutzer ermitteln ───────────────────────────────────────
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    TARGET_USER=$(whiptail \
        --title "SnowFoxOS Installer" \
        --inputbox "Für welchen Benutzer soll SnowFoxOS installiert werden?" \
        8 60 "" 3>&1 1>&2 2>&3) || exit 1
fi
TARGET_HOME="/home/$TARGET_USER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ ! -d "$TARGET_HOME" ]] && error "Home $TARGET_HOME nicht gefunden."

LOG="/tmp/snowfox_install.log"
> "$LOG"
run() { "$@" >> "$LOG" 2>&1; }

# ============================================================
# SCREEN 0 — Willkommen
# ============================================================
whiptail \
    --title "SnowFoxOS v2.1 Installer" \
    --msgbox \
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

  Drücke ENTER um fortzufahren." \
    22 72

# ============================================================
# SCREEN 1 — Lizenz
# ============================================================
whiptail \
    --title "SnowFox Public License v1.1" \
    --scrolltext \
    --msgbox \
"SnowFox Public License (SFL) v1.1
Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)

Diese Lizenz definiert die Bedingungen unter denen SnowFoxOS
und seine Derivate genutzt, verändert und verteilt werden duerfen.

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
- Sicherstellen dass Empfaenger dieselben Rechte erhalten

────────────────────────────────────────
3. MARKEN- UND NAMENSNUTZUNG
────────────────────────────────────────

- Der Name 'SnowFoxOS' darf nur fuer Distributionen verwendet
  werden die dem urspruenglichen Projektziel treu bleiben,
  einschliesslich des Fokus auf Benutzerkontrolle und Privacy.
- Abgeleitete Werke duerfen sich nicht als das originale
  SnowFoxOS ausgeben wenn sie diese Grundsaetze wesentlich
  veraendern.
- Der Name darf nicht irrefuehrend zur Billigung durch den
  Originalautor genutzt werden.

────────────────────────────────────────
4. PRIVACY UND NUTZERRESPEKT
────────────────────────────────────────

- Keine unautorisierten Telemetrie- oder Tracking-Funktionen
- Jede Datensammlung muss transparent und mit Zustimmung erfolgen
- Die Software darf Nutzer nicht absichtlich schaedigen

────────────────────────────────────────
5. EINSCHRAENKUNGEN
────────────────────────────────────────

Du darfst nicht:
- Diese Lizenz bei der Weitergabe entfernen oder veraendern
- Die Software ohne Beibehaltung der Zuschreibung weitergeben
- Den Ursprung der Software falsch darstellen
- Exklusive Autorenschaft am Originalwerk beanspruchen

────────────────────────────────────────
6. KEINE GEWAEHRLEISTUNG
────────────────────────────────────────

Diese Software wird 'so wie sie ist' bereitgestellt, ohne
jegliche ausdruckliche oder stillschweigende Gewaehrleistung.
Der Autor haftet nicht fuer Schaeden aus der Nutzung.

────────────────────────────────────────
7. KUENDIGUNG
────────────────────────────────────────

Jeder Verstoss fuehrt zum sofortigen Erloeschen der Rechte.

────────────────────────────────────────
8. ABSCHLUSSERKLARUNG
────────────────────────────────────────

Diese Software ist dazu bestimmt ihren Nutzern zu dienen,
nicht sie auszunutzen. Nutzer behalten die Kontrolle ueber
ihre Systeme, ihre Daten und ihre Computerumgebung.

'Dein Computer gehoert dir.'
-- Alexander Valentin Ludwig" \
    36 72

if ! whiptail \
    --title "Lizenz akzeptieren" \
    --yesno \
"Hast du die SnowFox Public License v1.1 gelesen
und akzeptierst du die Bedingungen?

Ohne Zustimmung kann die Installation nicht
fortgesetzt werden." \
    12 60; then
    clear
    echo -e "${RED}${BOLD}Abgebrochen — Lizenz nicht akzeptiert.${RESET}"
    exit 1
fi

# ============================================================
# SCREEN 2 — Optionale Pakete
# ============================================================
OPTIONAL_CHOICES=$(whiptail \
    --title "Optionale Pakete" \
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

# ============================================================
# SCREEN 3 — Browser
# ============================================================
BROWSER_CHOICE=$(whiptail \
    --title "Browser waehlen" \
    --menu \
"Waehle deinen Standard-Browser:" \
    16 68 5 \
    "1" "Zen Browser   (Firefox-Basis, Privacy — empfohlen)" \
    "2" "LibreWolf     (gehaerteter Firefox, max. Privacy)" \
    "3" "Brave         (Chromium-Basis, Privacy)" \
    "4" "Firefox-ESR   (Standard, stabil)" \
    "5" "Chromium      (leicht, schnell)" \
    3>&1 1>&2 2>&3) || { clear; echo "Abgebrochen."; exit 1; }

# ============================================================
# SCREEN 4 — Standard-Editor
# ============================================================
EDITOR_CHOICE=$(whiptail \
    --title "Standard-Texteditor" \
    --menu \
"Welcher Editor soll als Standard gesetzt werden?" \
    12 68 2 \
    "1" "Mousepad  (leicht, GTK)" \
    "2" "VSCodium  (nur wenn oben gewaehlt)" \
    3>&1 1>&2 2>&3) || EDITOR_CHOICE="1"

# ============================================================
# SCREEN 5 — Zusammenfassung
# ============================================================
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

if ! whiptail \
    --title "Zusammenfassung" \
    --yesno \
"Folgendes wird installiert:

  Benutzer : $TARGET_USER
  Browser  : $BROWSER_NAME
  Editor   : $EDITOR_NAME

  Optionale Pakete:
$(echo -e "$OPT_LIST")
  Immer enthalten:
  + i3 + Polybar + Rofi + Dunst + Picom
  + XanMod LTS Kernel (x64v3)
  + PipeWire Audio
  + GPU-Treiber (automatisch erkannt)
  + ufw Firewall + MAC-Rand. + DNS-over-TLS
  + zram + earlyoom + tlp + snowfox CLI

Installation jetzt starten?" \
    28 68; then
    clear
    echo "Installation abgebrochen."
    exit 0
fi

# ============================================================
# INSTALLATION — mit Fortschrittsbalken
# ============================================================
(

# ── Schritt 1: System & Repos ────────────────────────────────
echo "2"; echo "XXX"; echo "System vorbereiten & Repos einrichten..."; echo "XXX"

DKMS_HOOKS=(/etc/kernel/postinst.d/dkms /etc/kernel/prerm.d/dkms /usr/lib/kernel/install.d/50-dkms.install)
for hook in "${DKMS_HOOKS[@]}"; do [[ -f "$hook" ]] && mv "$hook" "${hook}.snowfox-bak"; done

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
run dpkg --configure -a
run apt-get -f install -y
run apt-get upgrade -y
run apt-get install -y \
    curl wget git unzip build-essential ca-certificates gnupg \
    pciutils usbutils htop btop neofetch bash-completion \
    xdg-utils xdg-user-dirs rfkill imagemagick bc \
    xorg xinit x11-utils x11-xserver-utils xclip xdotool dbus-x11
run sudo -u "$TARGET_USER" xdg-user-dirs-update

# ── Schritt 2: XanMod Kernel ─────────────────────────────────
echo "12"; echo "XXX"; echo "XanMod LTS Kernel installieren..."; echo "XXX"

curl -fSL https://dl.xanmod.org/archive.key \
    | gpg --dearmor --yes -o /usr/share/keyrings/xanmod-archive-keyring.gpg >> "$LOG" 2>&1
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' \
    | tee /etc/apt/sources.list.d/xanmod-kernel.list >> "$LOG"
run apt-get update -qq
set +e; DEBIAN_FRONTEND=noninteractive apt-get install -y linux-xanmod-lts-x64v3 >> "$LOG" 2>&1; set -e

CURRENT_KERNEL=$(uname -r)
for pkg in $(dpkg --list | grep "linux-image-[0-9]" | awk '{print $2}' | grep -v "$CURRENT_KERNEL" | grep -v "xanmod"); do
    run apt-get purge -y "$pkg"
done
run apt-get autoremove -y
run update-grub

# ── Schritt 3: GPU & Hardware ────────────────────────────────
echo "22"; echo "XXX"; echo "Hardware erkennen & Treiber installieren..."; echo "XXX"

IS_LAPTOP=false
[[ "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" =~ ^(8|9|10|14)$ ]] && IS_LAPTOP=true

grep -m1 "vendor_id" /proc/cpuinfo | grep -qi "AuthenticAMD" \
    && run apt-get install -y amd64-microcode \
    || run apt-get install -y intel-microcode

GPU_INFO=$(lspci | grep -iE 'vga|3d|display')
HAS_NVIDIA=false; HAS_AMD=false
echo "$GPU_INFO" | grep -qi "nvidia" && HAS_NVIDIA=true
echo "$GPU_INFO" | grep -qi "amd"    && HAS_AMD=true

if $HAS_NVIDIA; then
    run apt-get install -y clang-19 lld-19
    for alt in clang clang++ lld ld.lld; do
        binary="${alt/ld.lld/lld-19}"; binary="${binary/clang++/clang++-19}"; binary="${binary/clang/clang-19}"
        update-alternatives --install /usr/bin/$alt $alt /usr/bin/$binary 100 >> "$LOG" 2>&1 || true
    done
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub \
        | gpg --dearmor | tee /usr/share/keyrings/nvidia-cuda-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /" \
        | tee /etc/apt/sources.list.d/nvidia-cuda.list >> "$LOG"
    cat > /etc/apt/preferences.d/nvidia-cuda << 'EOF'
Package: cuda-drivers* nvidia-* libcuda* libnvidia-*
Pin: origin "developer.download.nvidia.com"
Pin-Priority: 900
Package: *
Pin: release o=Debian
Pin-Priority: 500
EOF
    run apt-get update -qq
    set +e; run apt-get purge -y nvidia-driver nvidia-kernel-dkms; set -e
    run apt-get install -y cuda-drivers-580 libvulkan1 libvulkan1:i386 nvidia-vulkan-icd nvidia-vulkan-icd:i386
    $HAS_AMD && { set +e; pip3 install envycontrol --break-system-packages >> "$LOG" 2>&1; set -e; }
    XANMOD_KERNEL=$(ls /lib/modules | grep xanmod | sort -V | tail -1)
    NVIDIA_VER=$(ls /var/lib/dkms/nvidia/ 2>/dev/null | sort -V | tail -1)
    [[ -n "$XANMOD_KERNEL" && -n "$NVIDIA_VER" ]] && { set +e; dkms install nvidia/"$NVIDIA_VER" -k "$XANMOD_KERNEL" >> "$LOG" 2>&1; set -e; }
elif $HAS_AMD; then
    run apt-get install -y firmware-amd-graphics mesa-vulkan-drivers mesa-va-drivers
else
    run apt-get install -y intel-media-va-driver-non-free i965-va-driver
fi

$IS_LAPTOP && { run apt-get install -y tlp tlp-rdw thermald xserver-xorg-input-libinput; run systemctl enable tlp thermald; }

# ── Schritt 4: i3 Desktop ────────────────────────────────────
echo "35"; echo "XXX"; echo "i3 Desktop installieren..."; echo "XXX"

run apt-get install -y \
    i3 i3status i3lock polybar rofi dunst libnotify-bin feh redshift \
    scrot brightnessctl playerctl network-manager network-manager-gnome \
    bluez blueman fonts-inter fonts-noto fonts-noto-color-emoji \
    fonts-font-awesome papirus-icon-theme arc-theme xsettingsd lxpolkit \
    lxappearance picom xss-lock xserver-xorg-input-libinput clipit \
    cups cups-bsd cups-client printer-driver-splix

run systemctl enable bluetooth

cat > "$TARGET_HOME/.config/picom.conf" << 'EOF'
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

BASH_PROFILE="$TARGET_HOME/.bash_profile"
grep -q "startx" "$BASH_PROFILE" 2>/dev/null || {
    echo '' >> "$BASH_PROFILE"
    echo '# SnowFoxOS — i3 automatisch starten' >> "$BASH_PROFILE"
    echo '[ "$(tty)" = "/dev/tty1" ] && exec startx' >> "$BASH_PROFILE"
}

cat > "$TARGET_HOME/.xinitrc" << 'EOF'
#!/bin/sh
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games
[ -f /usr/bin/dbus-launch ] && eval $(/usr/bin/dbus-launch --sh-syntax --exit-with-session)
exec i3
EOF
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.xinitrc"
chmod +x "$TARGET_HOME/.xinitrc"

# ── Schritt 5: Audio ─────────────────────────────────────────
echo "45"; echo "XXX"; echo "PipeWire Audio installieren..."; echo "XXX"

run apt-get install -y pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol pulseaudio-utils
set +e; run apt-get remove --purge -y pulseaudio; set -e
sudo -u "$TARGET_USER" systemctl --user enable pipewire pipewire-pulse wireplumber >> "$LOG" 2>&1 || true

# ── Schritt 6: Terminal & Apps ───────────────────────────────
echo "52"; echo "XXX"; echo "Terminal & Apps installieren..."; echo "XXX"

run apt-get install -y kitty mc mousepad ristretto file-roller mpv ffmpeg

echo "$OPTIONAL_CHOICES" | grep -q "THUNAR"     && run apt-get install -y thunar thunar-archive-plugin thunar-volman gvfs gvfs-backends
echo "$OPTIONAL_CHOICES" | grep -q "VLC"        && run apt-get install -y vlc
echo "$OPTIONAL_CHOICES" | grep -q "GIMP"       && run apt-get install -y gimp

if echo "$OPTIONAL_CHOICES" | grep -q "VSCODE"; then
    set +e
    curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor | tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main" \
        | tee /etc/apt/sources.list.d/vscodium.list >> "$LOG"
    run apt-get update -qq
    run apt-get install -y codium
    set -e
fi

if echo "$OPTIONAL_CHOICES" | grep -q "ONLYOFFICE"; then
    set +e
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE \
        | gpg --dearmor -o /etc/apt/keyrings/onlyoffice.gpg
    echo "deb [signed-by=/etc/apt/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" \
        | tee /etc/apt/sources.list.d/onlyoffice.list >> "$LOG"
    run apt-get update -qq
    run apt-get install -y onlyoffice-desktopeditors
    set -e
fi

curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp >> "$LOG" 2>&1 && chmod +x /usr/local/bin/yt-dlp

# ── Schritt 7: Browser ───────────────────────────────────────
echo "62"; echo "XXX"; echo "Browser installieren..."; echo "XXX"

case "$BROWSER_CHOICE" in
    1)
        set +e
        ZEN_URL=$(curl -s https://api.github.com/repos/zen-browser/desktop/releases/latest \
            | grep "browser_download_url.*x86_64.AppImage\"" | head -1 | cut -d '"' -f 4)
        if [[ -n "$ZEN_URL" ]]; then
            curl -L "$ZEN_URL" -o /opt/zen-browser.AppImage >> "$LOG" 2>&1
            chmod +x /opt/zen-browser.AppImage
            run apt-get install -y libfuse2
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
            run apt-get install -y firefox-esr
            DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop"
        fi
        set -e ;;
    2)
        set +e
        curl -fsSL https://deb.librewolf.net/keyring.gpg \
            | gpg --dearmor | tee /usr/share/keyrings/librewolf.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/librewolf.gpg arch=amd64] https://deb.librewolf.net bookworm main" \
            | tee /etc/apt/sources.list.d/librewolf.list >> "$LOG"
        run apt-get update -qq
        run apt-get install -y librewolf
        DEFAULT_BROWSER_DESKTOP="librewolf.desktop"
        set -e ;;
    3)
        curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
            | tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
            | tee /etc/apt/sources.list.d/brave-browser.list >> "$LOG"
        run apt-get update -qq
        run apt-get install -y brave-browser >> "$LOG" 2>&1
        DEFAULT_BROWSER_DESKTOP="brave-browser.desktop" ;;
    4)
        run apt-get install -y firefox-esr
        DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop" ;;
    5)
        run apt-get install -y chromium
        DEFAULT_BROWSER_DESKTOP="chromium.desktop" ;;
    *)
        DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop" ;;
esac

# ── Schritt 8: Steam & Gaming ────────────────────────────────
echo "70"; echo "XXX"; echo "Gaming-Komponenten installieren..."; echo "XXX"

if echo "$OPTIONAL_CHOICES" | grep -q "STEAM"; then
    run apt-get install -y steam steam-devices libvulkan1 libvulkan1:i386 \
        vulkan-tools libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386 gamemode
    run systemctl enable gamemoded
    PROTON_GE_URL=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest \
        | grep "browser_download_url.*tar.gz" | cut -d '"' -f 4)
    if [[ -n "$PROTON_GE_URL" ]]; then
        curl -L "$PROTON_GE_URL" -o /tmp/proton-ge.tar.gz >> "$LOG" 2>&1
        mkdir -p "$TARGET_HOME/.steam/root/compatibilitytools.d"
        tar -xzf /tmp/proton-ge.tar.gz -C "$TARGET_HOME/.steam/root/compatibilitytools.d/"
        rm -f /tmp/proton-ge.tar.gz
        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.steam/root/compatibilitytools.d/"
    fi
fi

# ── Schritt 9: Performance & Sicherheit ─────────────────────
echo "80"; echo "XXX"; echo "Performance & Sicherheit einrichten..."; echo "XXX"

run apt-get install -y zram-tools tlp tlp-rdw earlyoom ufw

cat > /etc/default/zramswap << 'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF
run systemctl enable zramswap tlp earlyoom

cat > /etc/sysctl.d/99-snowfox.conf << 'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.use_tempaddr=2
net.ipv6.conf.default.use_tempaddr=2
EOF

grep -q "tmpfs /tmp" /etc/fstab || echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab

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
run systemctl enable systemd-resolved

for svc in avahi-daemon cups-browsed ModemManager colord; do
    systemctl disable "$svc" >> "$LOG" 2>&1 || true
done
sed -i 's/#HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf

# ── Schritt 10: Plymouth & Branding ─────────────────────────
echo "88"; echo "XXX"; echo "Plymouth & Branding einrichten..."; echo "XXX"

run apt-get install -y plymouth plymouth-themes
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
    convert "$SCRIPT_DIR/assets/fuchs.png" -resize 200x200 "$PLYMOUTH_DIR/logo.png" >> "$LOG" 2>&1 || true
convert -size 1920x1080 xc:#0f0f0f "$PLYMOUTH_DIR/background.png" >> "$LOG" 2>&1 || true
plymouth-set-default-theme snowfox >> "$LOG" 2>&1 || true
update-initramfs -u >> "$LOG" 2>&1 || true

# ── Schritt 11: Konfiguration & Finishing ───────────────────
echo "94"; echo "XXX"; echo "Konfiguration & Finishing..."; echo "XXX"

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR/neofetch" "$TARGET_HOME/Pictures/wallpapers"

cat > /etc/os-release << 'EOF'
PRETTY_NAME="SnowFoxOS 2.1"
NAME="SnowFoxOS"
ID=debian
ID_LIKE=debian
ANSI_COLOR="0;35"
EOF
echo "snowfox"       > /etc/hostname
echo "SnowFoxOS 2.1" > /etc/issue

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

[[ -f "$CONFIG_DIR/xsettingsd" ]] && rm -f "$CONFIG_DIR/xsettingsd"
[[ -d "$SCRIPT_DIR/configs"    ]] && cp -r "$SCRIPT_DIR/configs/"* "$CONFIG_DIR/"
[[ -d "$SCRIPT_DIR/wallpapers" ]] && cp -r "$SCRIPT_DIR/wallpapers/"* "$TARGET_HOME/Pictures/wallpapers/"

if [[ -d "$SCRIPT_DIR/configs/modprobe" ]]; then
    cp "$SCRIPT_DIR/configs/modprobe/amdgpu.conf" /etc/modprobe.d/amdgpu.conf >> "$LOG" 2>&1 || true
    cp "$SCRIPT_DIR/configs/modprobe/nvidia.conf"  /etc/modprobe.d/nvidia.conf  >> "$LOG" 2>&1 || true
    update-initramfs -u >> "$LOG" 2>&1 || true
fi

[[ "$EDITOR_CHOICE" == "2" ]] && DEFAULT_EDITOR_DESKTOP="codium.desktop" || DEFAULT_EDITOR_DESKTOP="mousepad.desktop"
cat > "$TARGET_HOME/.config/mimeapps.list" << MEOF
[Default Applications]
inode/directory=thunar.desktop
text/plain=$DEFAULT_EDITOR_DESKTOP
text/x-python=$DEFAULT_EDITOR_DESKTOP
text/x-shellscript=$DEFAULT_EDITOR_DESKTOP
x-scheme-handler/http=${DEFAULT_BROWSER_DESKTOP:-firefox-esr.desktop}
x-scheme-handler/https=${DEFAULT_BROWSER_DESKTOP:-firefox-esr.desktop}
text/html=${DEFAULT_BROWSER_DESKTOP:-firefox-esr.desktop}
application/pdf=${DEFAULT_BROWSER_DESKTOP:-firefox-esr.desktop}
image/png=ristretto.desktop
image/jpeg=ristretto.desktop
video/mp4=mpv.desktop
audio/mpeg=mpv.desktop
application/zip=org.gnome.FileRoller.desktop
application/x-tar=org.gnome.FileRoller.desktop
MEOF

for f in snowfox snowfox-greeting.sh; do
    [[ -f "$SCRIPT_DIR/$f" ]] && cp "$SCRIPT_DIR/$f" "/usr/local/bin/${f%.sh}" && chmod +x "/usr/local/bin/${f%.sh}"
done
[[ -f "$SCRIPT_DIR/configs/powermenu.sh" ]] && \
    cp "$SCRIPT_DIR/configs/powermenu.sh" /usr/local/bin/snowfox-powermenu && \
    chmod +x /usr/local/bin/snowfox-powermenu

grep -q "snowfox-greeting" "$TARGET_HOME/.bashrc" 2>/dev/null || \
    echo -e '\n# SnowFoxOS Greeting\n[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting' >> "$TARGET_HOME/.bashrc"

run apt-get install -y firmware-misc-nonfree linux-headers-$(uname -r)
lsusb 2>/dev/null | grep -qi "fritz\|0x0bda\|2357" && modprobe mt76x2u >> "$LOG" 2>&1 || true

chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "${hook}.snowfox-bak" ]] && mv "${hook}.snowfox-bak" "$hook"
done

echo "100"; echo "XXX"; echo "Fertig!"; echo "XXX"

) | whiptail \
    --title "SnowFoxOS wird installiert..." \
    --gauge "Bitte warten — dies kann 20-60 Minuten dauern..." \
    8 68 0

# ============================================================
# FERTIG-SCREEN
# ============================================================
whiptail \
    --title "Installation abgeschlossen!" \
    --msgbox \
"  SnowFoxOS v2.1 wurde erfolgreich installiert!

  Was wurde eingerichtet:
  + i3 + Polybar + Rofi + Picom + Dunst
  + XanMod LTS Kernel (x64v3)
  + PipeWire Audio
  + GPU-Treiber (automatisch erkannt)
  + ufw Firewall (aktiv)
  + MAC-Randomisierung & DNS-over-TLS
  + zram + earlyoom + tlp
  + snowfox CLI

  Das Installations-Log findest du unter:
  /tmp/snowfox_install.log

  Druecke ENTER — das System wird neu gestartet." \
    22 60

clear
echo -e "${GREEN}${BOLD}SnowFoxOS installiert. Starte neu...${RESET}"
sleep 2
reboot
