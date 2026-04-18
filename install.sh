#!/bin/bash
# ============================================================
#  SnowFoxOS v2.0 — Installer
#  Basis: Debian 12 (Bookworm) minimal
#  Desktop: i3 + Polybar + Rofi + Dunst + i3lock
#  Ausführen: sudo ./install.sh
# ============================================================

set -e

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${PURPLE}${BOLD}[SnowFox]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[FEHLER]${RESET} $1"; exit 1; }
step()    { echo -e "\n${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}";
            echo -e "${PURPLE}${BOLD}  $1${RESET}";
            echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"; }
ask_install() {
    echo ""
    read -rp "$(echo -e ${PURPLE}${BOLD}"[SnowFox] $1 installieren? [j/n]: "${RESET})" choice
    [[ "$choice" =~ ^[jJ]$ ]]
}

if [[ $EUID -ne 0 ]]; then
    error "Bitte mit sudo ausführen: sudo ./install.sh"
fi

TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    read -rp "Benutzername: " TARGET_USER
fi
TARGET_HOME="/home/$TARGET_USER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ ! -d "$TARGET_HOME" ]] && error "Home $TARGET_HOME nicht gefunden"

info "Installiere für: ${BOLD}$TARGET_USER${RESET}"
sleep 1

# ============================================================
# SCHRITT 1 — System & Repositories
# ============================================================
step "1/10 — System aktualisieren"

# DKMS-Hooks global deaktivieren fuer den gesamten Installer-Lauf.
# Grund: apt-get upgrade kann halbinstallierte Kernel-Pakete aus einem
# vorherigen fehlgeschlagenen Versuch konfigurieren wollen -- dabei wuerde
# DKMS sofort feuern und den Installer abbrechen, noch bevor XanMod-Code laeuft.
# Die Hooks werden am Ende des Installers wiederhergestellt.
DKMS_HOOKS=(
    /etc/kernel/postinst.d/dkms
    /etc/kernel/prerm.d/dkms
    /usr/lib/kernel/install.d/50-dkms.install
)
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "$hook" ]] && mv "$hook" "${hook}.snowfox-bak"
done
info "DKMS-Hooks fuer Installer-Lauf deaktiviert"

cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
EOF

dpkg --add-architecture i386
apt-get update -qq
# Halbinstallierte Pakete aus vorherigen Versuchen zuerst bereinigen
dpkg --configure -a 2>/dev/null || true
apt-get -f install -y 2>/dev/null || true
apt-get upgrade -y
apt-get install -y \
    curl wget git unzip \
    build-essential \
    ca-certificates \
    gnupg \
    pciutils usbutils \
    htop btop neofetch \
    bash-completion \
    xdg-utils \
    xdg-user-dirs \
    rfkill \
    imagemagick \
    bc \
    xorg \
    xinit \
    x11-utils \
    x11-xserver-utils \
    xclip \
    xdotool \
    dbus-x11

sudo -u "$TARGET_USER" xdg-user-dirs-update
success "System aktualisiert"

# Performance-Kernel (XanMod)
if ask_install "Performance-Kernel (XanMod)"; then
    info "Installiere XanMod Repository & Kernel..."
    curl -fSL https://dl.xanmod.org/archive.key | gpg --dearmor --yes -o /usr/share/keyrings/xanmod-archive-keyring.gpg
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' \
        | tee /etc/apt/sources.list.d/xanmod-kernel.list
    apt-get update -qq

    # DKMS-Hooks sind bereits global deaktiviert (seit Beginn von Schritt 1).
    set +e
    DEBIAN_FRONTEND=noninteractive apt-get install -y linux-xanmod-x64v3
    XANMOD_EXIT=$?
    set -e

    if [[ $XANMOD_EXIT -eq 0 ]]; then
        success "Performance-Kernel bereit (aktiv nach Reboot)"
    else
        warn "XanMod-Kernel-Installation schlug fehl (Exit $XANMOD_EXIT)."
        warn "Bitte manuell pruefen: apt-get install linux-xanmod-x64v3"
        warn "Installation wird fortgesetzt..."
    fi

    # NVIDIA-Hinweis: DKMS-Module nach Reboot in XanMod manuell nachbauen
    if lspci | grep -qi nvidia; then
        warn "NVIDIA erkannt: Nach dem ersten Reboot in den XanMod-Kernel bitte ausfuehren:"
        warn "  sudo dkms autoinstall -k \$(uname -r)"
    fi
fi

# Fritz USB AC 860 Treiber (mt76x2u)
info "Prüfe Fritz USB AC 860 Treiber..."
apt-get install -y firmware-misc-nonfree linux-headers-$(uname -r) 2>/dev/null || true
if lsusb 2>/dev/null | grep -qi "fritz\|0x0bda\|2357"; then
    modprobe mt76x2u 2>/dev/null && \
        success "Fritz USB AC 860 Treiber geladen (mt76x2u)" || \
        warn "Fritz USB AC 860 Treiber nicht gefunden — nach Reboot prüfen"
fi

# ============================================================
# SCHRITT 2 — Intelligente Hardware-Erkennung
# ============================================================
step "2/10 — Hardware-Analyse & Treiber"

IS_LAPTOP=false
[[ "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" =~ ^(8|9|10|14)$ ]] && IS_LAPTOP=true

# CPU Microcode
CPU_INFO=$(grep -m1 "vendor_id" /proc/cpuinfo)
if echo "$CPU_INFO" | grep -qi "AuthenticAMD"; then
    apt-get install -y amd64-microcode
    success "AMD CPU Microcode installiert"
else
    apt-get install -y intel-microcode
    success "Intel CPU Microcode installiert"
fi

# GPU-Check
GPU_INFO=$(lspci | grep -iE 'vga|3d|display')
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    info "NVIDIA GPU erkannt — Optimiere für Gaming & DLSS..."
    apt-get install -y nvidia-driver nvidia-vulkan-icd nvidia-settings libvulkan1:i386 libvulkan1
    success "NVIDIA Stack installiert"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    info "AMD GPU erkannt — Nutze Mesa..."
    apt-get install -y firmware-amd-graphics mesa-vulkan-drivers mesa-va-drivers
    success "AMD Stack installiert"
else
    info "Intel Grafik erkannt — Optimiere für Effizienz..."
    apt-get install -y intel-media-va-driver-non-free i965-va-driver
    success "Intel Stack installiert"
fi

# Laptop-Spezifische Optimierung
if [ "$IS_LAPTOP" = true ]; then
    info "Laptop erkannt: Installiere Akku- & Touchpad-Tools..."
    apt-get install -y tlp tlp-rdw thermald xserver-xorg-input-libinput
    systemctl enable tlp thermald
    success "Laptop-Optimierung abgeschlossen"
fi

success "GPU-Treiber eingerichtet"

# ============================================================
# SCHRITT 3 — i3 Desktop
# ============================================================
step "3/10 — i3 + Polybar + Rofi + Dunst + i3lock"

apt-get install -y \
    i3 \
    i3status \
    i3lock \
    polybar \
    rofi \
    dunst \
    libnotify-bin \
    feh \
    redshift \
    scrot \
    xautolock \
    brightnessctl \
    playerctl \
    network-manager \
    network-manager-gnome \
    nm-tray \
    bluez \
    blueman \
    fonts-inter \
    fonts-noto \
    fonts-noto-color-emoji \
    fonts-font-awesome \
    papirus-icon-theme \
    arc-theme \
    xsettingsd \
    lxpolkit \
    lxappearance \
    picom \
    xss-lock \
    xserver-xorg-input-libinput

systemctl enable bluetooth

# Touchpad Konfiguration
mkdir -p /etc/X11/xorg.conf.d
if [[ -f "$SCRIPT_DIR/configs/xorg/30-touchpad.conf" ]]; then
    cp "$SCRIPT_DIR/configs/xorg/30-touchpad.conf" /etc/X11/xorg.conf.d/30-touchpad.conf
    info "Touchpad-Config aus Repo kopiert"
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
    info "Standard-Touchpad-Config (Tapping/Natural Scroll) erstellt"
fi

# i3 startet automatisch von TTY1
BASH_PROFILE="$TARGET_HOME/.bash_profile"
if ! grep -q "startx" "$BASH_PROFILE" 2>/dev/null; then
    echo '' >> "$BASH_PROFILE"
    echo '# SnowFoxOS — i3 automatisch starten' >> "$BASH_PROFILE"
    echo '[ "$(tty)" = "/dev/tty1" ] && exec startx' >> "$BASH_PROFILE"
fi

# xinitrc
cat > "$TARGET_HOME/.xinitrc" << 'EOF'
#!/bin/sh
# SnowFoxOS xinitrc
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games
if [ -f /usr/bin/dbus-launch ]; then
    eval $(/usr/bin/dbus-launch --sh-syntax --exit-with-session)
fi
exec i3
EOF
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.xinitrc"
chmod +x "$TARGET_HOME/.xinitrc"

success "i3 Desktop & Autostart eingerichtet"

# ============================================================
# SCHRITT 4 — Audio (PipeWire)
# ============================================================
step "4/10 — Audio (PipeWire)"

apt-get install -y \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    wireplumber \
    pavucontrol \
    pulseaudio-utils

apt-get remove --purge -y pulseaudio 2>/dev/null || true
sudo -u "$TARGET_USER" systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

success "PipeWire installiert"

# ============================================================
# SCHRITT 5 — Terminal & Apps
# ============================================================
step "5/10 — Terminal & Standard-Apps"

apt-get install -y \
    kitty \
    mc \
    mousepad \
    ristretto \
    file-roller \
    mpv \
    ffmpeg

# Dateimanager Auswahl
echo ""
echo -e "${PURPLE}${BOLD}  Welchen Dateimanager möchtest du installieren?${RESET}"
echo -e "  1) Thunar  (grafisch, empfohlen)"
echo -e "  2) MC      (Terminal, bereits installiert)"
echo -e "  3) Beide"
echo ""
read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-3]: "${RESET})" FM_CHOICE
case "$FM_CHOICE" in
    1|3) apt-get install -y thunar thunar-archive-plugin thunar-volman gvfs gvfs-backends; success "Thunar installiert" ;;
    2)   success "MC bereits installiert" ;;
    *)   apt-get install -y thunar thunar-archive-plugin thunar-volman gvfs gvfs-backends; success "Thunar installiert (Standard)" ;;
esac

# Optionale Apps
if ask_install "Firefox-ESR (Stabil)"; then
    apt-get install -y firefox-esr
    success "Firefox-ESR installiert"
fi

if ask_install "VLC Media Player"; then
    apt-get install -y vlc
    success "VLC installiert"
fi

if ask_install "GIMP (Bildbearbeitung)"; then
    apt-get install -y gimp
    success "GIMP installiert"
fi

# VSCodium
if ask_install "VSCodium"; then
    set +e
    curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor \
        | tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main" \
        | tee /etc/apt/sources.list.d/vscodium.list
    apt-get update -qq
    apt-get install -y codium && success "VSCodium installiert" || warn "VSCodium fehlgeschlagen"
    set -e
fi

# OnlyOffice
if ask_install "OnlyOffice"; then
    set +e
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE \
        | gpg --dearmor -o /etc/apt/keyrings/onlyoffice.gpg
    echo "deb [signed-by=/etc/apt/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" \
        | tee /etc/apt/sources.list.d/onlyoffice.list
    apt-get update -qq
    apt-get install -y onlyoffice-desktopeditors && success "OnlyOffice installiert" || warn "OnlyOffice fehlgeschlagen"
    set -e
fi

# yt-dlp
curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp && chmod +x /usr/local/bin/yt-dlp
success "yt-dlp installiert"

# ============================================================
# SCHRITT 6 — Browser
# ============================================================
step "6/10 — Browser"

echo ""
echo -e "${PURPLE}${BOLD}  Browser Wahl:${RESET}"
echo -e "  1) Chromium  (empfohlen)"
echo -e "  2) Falkon    (leicht)"
echo -e "  3) Brave     (Privacy)"
echo -e "  4) Keinen"
echo ""
read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-4]: "${RESET})" BROWSER_CHOICE

case "$BROWSER_CHOICE" in
    1) apt-get install -y chromium; success "Chromium installiert" ;;
    2) apt-get install -y falkon; success "Falkon installiert" ;;
    3)
       curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
           | tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
       echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
           | tee /etc/apt/sources.list.d/brave-browser.list
       apt-get update -qq && apt-get install -y brave-browser
       success "Brave installiert"
       ;;
    *) warn "Kein Browser installiert" ;;
esac

# ============================================================
# SCHRITT 7 — Steam & Gaming
# ============================================================
step "7/10 — Steam & Gaming"

if ask_install "Steam"; then
    apt-get install -y \
        steam steam-devices \
        libvulkan1 libvulkan1:i386 \
        vulkan-tools libgl1-mesa-dri:i386 \
        mesa-vulkan-drivers:i386 2>/dev/null || warn "Steam teilweise fehlgeschlagen"
    success "Steam installiert"
fi

# ============================================================
# SCHRITT 8 — Performance & Stabilität
# ============================================================
step "8/10 — Performance & Stabilität"

apt-get install -y zram-tools tlp tlp-rdw earlyoom

cat > /etc/default/zramswap << 'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF

systemctl enable zramswap tlp earlyoom

cat > /etc/sysctl.d/99-snowfox.conf << 'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF

# /tmp im RAM
grep -q "tmpfs /tmp" /etc/fstab || echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab

# Unbenötigte Dienste deaktivieren
for svc in avahi-daemon cups cups-browsed ModemManager; do
    systemctl disable "$svc" 2>/dev/null || true
done

# Power-Button: i3 Power-Menü übernimmt das — kein harter Shutdown via logind
sed -i 's/#HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf

success "Performance optimiert"

# ============================================================
# SCHRITT 9 — Plymouth & Branding
# ============================================================
step "9/10 — Plymouth & Boot-Screen"

apt-get install -y plymouth plymouth-themes 2>/dev/null || true
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
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
wallpaper_sprite = Sprite(wallpaper_image);
wallpaper_sprite.SetX(screen_width / 2 - wallpaper_image.GetWidth() / 2);
wallpaper_sprite.SetY(screen_height / 2 - wallpaper_image.GetHeight() / 2);
logo_image = Image("logo.png");
logo_sprite = Sprite(logo_image);
logo_sprite.SetX(screen_width / 2 - logo_image.GetWidth() / 2);
logo_sprite.SetY(screen_height / 2 - logo_image.GetHeight() / 2);
EOF

if [[ -f "$SCRIPT_DIR/assets/fuchs.png" ]]; then
    convert "$SCRIPT_DIR/assets/fuchs.png" -resize 200x200 "$PLYMOUTH_DIR/logo.png" 2>/dev/null || true
fi
convert -size 1920x1080 xc:#0f0f0f "$PLYMOUTH_DIR/background.png" 2>/dev/null || true

plymouth-set-default-theme snowfox 2>/dev/null || true
update-initramfs -u 2>/dev/null || true

success "Branding & Boot-Screen bereit"

# ============================================================
# SCHRITT 10 — Konfiguration & Abschluss
# ============================================================
step "10/10 — Konfiguration & Finishing"

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR/neofetch"
mkdir -p "$TARGET_HOME/Pictures/wallpapers"

# OS-Identität setzen
cat > /etc/os-release << 'EOF'
PRETTY_NAME="SnowFoxOS 2.1"
NAME="SnowFoxOS"
ID=debian
ID_LIKE=debian
ANSI_COLOR="0;35"
EOF

echo "snowfox" > /etc/hostname
echo "SnowFoxOS 2.1" > /etc/issue

# Neofetch konfigurieren
cat > "$CONFIG_DIR/neofetch/config.conf" << EOF
print_info() {
    info title
    info underline
    info "OS" distro
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "Resolution" resolution
    info "WM" wm
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory
}
image_backend="ascii"
image_source="$CONFIG_DIR/neofetch/snowfox.txt"
ascii_colors=(5 7)
EOF

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

# Repo-Configs kopieren (enthält alle i3, polybar, rofi, dunst, powermenu usw.)
[[ -f "$CONFIG_DIR/xsettingsd" ]] && rm -f "$CONFIG_DIR/xsettingsd"
if [[ -d "$SCRIPT_DIR/configs" ]]; then
    cp -r "$SCRIPT_DIR/configs/"* "$CONFIG_DIR/"
    success "Konfigurationsdateien aus Repo kopiert"
else
    warn "configs/-Verzeichnis nicht gefunden — bitte manuell kopieren"
fi

# Wallpaper aus Repo kopieren
if [[ -d "$SCRIPT_DIR/wallpapers" ]]; then
    cp -r "$SCRIPT_DIR/wallpapers/"* "$TARGET_HOME/Pictures/wallpapers/"
    success "Wallpapers kopiert"
fi

# Power-Menü aus Repo als System-Binary verfügbar machen
if [[ -f "$SCRIPT_DIR/configs/powermenu.sh" ]]; then
    cp "$SCRIPT_DIR/configs/powermenu.sh" /usr/local/bin/snowfox-powermenu
    chmod +x /usr/local/bin/snowfox-powermenu
    success "Power-Menü installiert"
else
    warn "configs/powermenu.sh nicht gefunden — wird übersprungen"
fi

# snowfox CLI & Greeting
if [[ -f "$SCRIPT_DIR/snowfox" ]]; then
    cp "$SCRIPT_DIR/snowfox" /usr/local/bin/snowfox
    chmod +x /usr/local/bin/snowfox
    success "snowfox CLI installiert"
fi

if [[ -f "$SCRIPT_DIR/snowfox-greeting.sh" ]]; then
    cp "$SCRIPT_DIR/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting
    chmod +x /usr/local/bin/snowfox-greeting
    success "snowfox-greeting installiert"
fi

# Greeting in .bashrc einbinden
if ! grep -q "snowfox-greeting" "$TARGET_HOME/.bashrc" 2>/dev/null; then
    echo -e '\n# SnowFoxOS Greeting\n[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting' >> "$TARGET_HOME/.bashrc"
fi

# Finale Berechtigungen
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

# DKMS-Hooks wiederherstellen
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "${hook}.snowfox-bak" ]] && mv "${hook}.snowfox-bak" "$hook"
done
info "DKMS-Hooks wiederhergestellt"

# ============================================================
# Fertig!
# ============================================================
echo -e "${PURPLE}${BOLD}"
echo "  ███████╗███╗  ██╗ ██████╗ ██╗    ██╗███████╗ ██████╗ ██╗  ██╗"
echo "  ██╔════╝████╗ ██║██╔═══██╗██║    ██║██╔════╝██╔═══██╗╚██╗██╔╝"
echo "  ███████╗██╔██╗██║██║   ██║██║ █╗ ██║█████╗  ██║   ██║ ╚███╔╝ "
echo "  ╚════██║██║╚████║██║   ██║██║███╗██║██╔══╝  ██║   ██║ ██╔██╗ "
echo "  ███████║██║ ╚███║╚██████╔╝╚███╔███╔╝██║      ╚██████╔╝██╔╝╚██╗"
echo "  ╚══════╝╚═╝  ╚══╝ ╚═════╝  ╚══╝╚══╝ ╚═╝      ╚═════╝ ╚═╝  ╚═╝"
echo -e "${RESET}"
success "SnowFoxOS v2.0 erfolgreich installiert!"
info "Bitte neu starten: sudo reboot"
