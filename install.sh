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
apt-get upgrade -y
# WICHTIG: dbus-x11 für Session-Management hinzugefügt
apt-get install -y \
    curl wget git unzip \
    build-essential \
    ca-certificates \
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

# Fritz USB AC 860 Treiber (mt76x2u)
info "Prüfe Fritz USB AC 860 Treiber..."
apt-get install -y firmware-misc-nonfree linux-headers-$(uname -r) 2>/dev/null || true
if lsusb 2>/dev/null | grep -qi "fritz\|0x0bda\|2357"; then
    modprobe mt76x2u 2>/dev/null && \
        success "Fritz USB AC 860 Treiber geladen (mt76x2u)" || \
        warn "Fritz USB AC 860 Treiber nicht gefunden — nach Reboot prüfen"
fi

success "System aktualisiert"

# ============================================================
# SCHRITT 2 — GPU-Erkennung & Treiber
# ============================================================
step "2/10 — GPU-Erkennung & Treiber"

GPU_INFO=$(lspci | grep -iE 'vga|3d|display')
HAS_NVIDIA=false
HAS_AMD=false
HAS_INTEL=false
IS_HYBRID=false

echo "$GPU_INFO" | grep -qi "nvidia" && HAS_NVIDIA=true && info "Nvidia GPU gefunden"
echo "$GPU_INFO" | grep -qi "amd\|radeon\|advanced micro" && HAS_AMD=true && info "AMD GPU gefunden"
echo "$GPU_INFO" | grep -qi "intel" && HAS_INTEL=true && info "Intel GPU gefunden"
[[ "$HAS_NVIDIA" = true && ( "$HAS_AMD" = true || "$HAS_INTEL" = true ) ]] && IS_HYBRID=true

if $HAS_AMD || $HAS_INTEL; then
    apt-get install -y \
        libgl1-mesa-dri libgl1-mesa-dri:i386 \
        mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
        mesa-va-drivers mesa-vdpau-drivers 2>/dev/null || true
    $HAS_AMD && apt-get install -y firmware-amd-graphics 2>/dev/null || true
    $HAS_INTEL && apt-get install -y intel-media-va-driver xserver-xorg-video-intel 2>/dev/null || true
    success "Mesa/AMD/Intel Treiber installiert"
fi

if $HAS_NVIDIA; then
    apt-get install -y linux-headers-$(uname -r) 2>/dev/null || true
    apt-get install -y \
        nvidia-driver \
        nvidia-kernel-dkms \
        firmware-misc-nonfree \
        libgbm1 \
        nvidia-vulkan-icd \
        nvidia-vulkan-icd:i386 \
        nvidia-settings 2>/dev/null || true

    cat > /etc/modprobe.d/blacklist-nouveau.conf << 'EOF'
blacklist nouveau
options nouveau modeset=0
install nouveau /bin/false
EOF
    update-initramfs -u -k all 2>/dev/null || true
    success "Nvidia Treiber installiert"
fi

if $IS_HYBRID; then
    apt-get install -y python3 python3-pip
    pip3 install envycontrol --break-system-packages 2>/dev/null || true
    if command -v envycontrol &>/dev/null; then
        envycontrol -s nvidia 2>/dev/null && success "envycontrol: Nvidia-Modus aktiviert" || true
        warn "Hybrid-GPU: Alle Monitore an die Nvidia-Karte anschließen!"
    fi
fi

if ! $HAS_NVIDIA && ! $HAS_AMD && ! $HAS_INTEL; then
    apt-get install -y libgl1-mesa-dri libgl1-mesa-dri:i386 mesa-vulkan-drivers 2>/dev/null || true
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

# Touchpad Konfiguration
# Touchpad Konfiguration sicherstellen
mkdir -p /etc/X11/xorg.conf.d

if [[ -f "$SCRIPT_DIR/configs/xorg/30-touchpad.conf" ]]; then
    cp "$SCRIPT_DIR/configs/xorg/30-touchpad.conf" /etc/X11/xorg.conf.d/30-touchpad.conf
    info "Touchpad-Config aus Repo kopiert"
else
    # Fallback: Erstelle eine funktionierende Standard-Config
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

# xinitrc — FIX: Pfad-Erzwingung & dbus-launch
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
    ffmpeg \
    gnupg

# Dateimanager Auswahl
echo ""
echo -e "${PURPLE}${BOLD}  Welchen Dateimanager möchtest du installieren?${RESET}"
echo -e "  1) Thunar  (grafisch, empfohlen)"
echo -e "  2) MC      (Terminal, Midnight Commander)"
echo -e "  3) Beide"
echo ""
read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-3]: "${RESET})" FM_CHOICE
case "$FM_CHOICE" in
    1)
        apt-get install -y thunar thunar-archive-plugin thunar-volman gvfs gvfs-backends
        success "Thunar installiert"
        ;;
    2)
        success "MC bereits installiert"
        ;;
    3)
        apt-get install -y thunar thunar-archive-plugin thunar-volman gvfs gvfs-backends
        success "Thunar + MC installiert"
        ;;
    *)
        apt-get install -y thunar thunar-archive-plugin thunar-volman gvfs gvfs-backends
        success "Thunar installiert (Standard)"
        ;;
esac

# VSCodium
echo ""
read -rp "$(echo -e ${PURPLE}${BOLD}"[SnowFox] VSCodium installieren? [j/n]: "${RESET})" INSTALL_VSCODIUM
if [[ "$INSTALL_VSCODIUM" =~ ^[jJ]$ ]]; then
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

BROWSER_NAME="keiner"
case "$BROWSER_CHOICE" in
    1) apt-get install -y chromium; BROWSER_NAME="Chromium" ;;
    2) apt-get install -y falkon; BROWSER_NAME="Falkon" ;;
    3) 
       curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
           | tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
       echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
           | tee /etc/apt/sources.list.d/brave-browser.list
       apt-get update -qq && apt-get install -y brave-browser
       BROWSER_NAME="Brave"
       ;;
    *) warn "Kein Browser installiert" ;;
esac

apt-get remove --purge -y firefox-esr 2>/dev/null || true

# ============================================================
# SCHRITT 7 — Steam
# ============================================================
step "7/10 — Steam"

read -rp "$(echo -e ${PURPLE}${BOLD}"[SnowFox] Steam installieren? [j/n]: "${RESET})" INSTALL_STEAM
if [[ "$INSTALL_STEAM" =~ ^[jJ]$ ]]; then
    apt-get install -y \
        steam steam-devices \
        libvulkan1 libvulkan1:i386 \
        vulkan-tools libgl1-mesa-dri:i386 \
        mesa-vulkan-drivers:i386 2>/dev/null || warn "Steam teilweise fehlgeschlagen"
    success "Steam installiert"
fi

# ============================================================
# SCHRITT 8 — Performance & Akku
# ============================================================
step "8/10 — Performance & Akku"

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

# Dienste optimieren
for svc in avahi-daemon cups cups-browsed ModemManager bluetooth; do
    systemctl disable "$svc" 2>/dev/null || true
done

success "Performance optimiert"

# ============================================================
# SCHRITT 9 — Plymouth & Branding
# ============================================================
step "9/10 — Plymouth & Branding"

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

# Assets konvertieren
if [[ -f "$SCRIPT_DIR/assets/fuchs.png" ]]; then
    convert "$SCRIPT_DIR/assets/fuchs.png" -resize 200x200 "$PLYMOUTH_DIR/logo.png" 2>/dev/null || true
fi
convert -size 1920x1080 xc:#0f0f0f "$PLYMOUTH_DIR/background.png" 2>/dev/null || true

plymouth-set-default-theme snowfox 2>/dev/null || true
update-initramfs -u 2>/dev/null || true

# OS Namen setzen
echo "SnowFoxOS 2.0" > /etc/issue
echo "snowfox" > /etc/hostname

success "Branding & Boot-Screen bereit"

# ============================================================
# SCHRITT 10 — Konfiguration & Branding
# ============================================================
step "10/10 — Konfiguration & Neofetch"

CONFIG_DIR="$TARGET_HOME/.config"

# Verzeichnisse erstellen
mkdir -p "$CONFIG_DIR"
mkdir -p "$TARGET_HOME/Pictures/wallpapers"

# WICHTIG: Falls xsettingsd eine Datei ist, löschen wir sie, 
# damit der Ordner aus dem Repo kopiert werden kann.
[[ -f "$CONFIG_DIR/xsettingsd" ]] && rm -f "$CONFIG_DIR/xsettingsd"

# Configs aus dem Repo kopieren
if [[ -d "$SCRIPT_DIR/configs" ]]; then
    # Wir kopieren den INHALT von configs/ in ~/.config/
    cp -r "$SCRIPT_DIR/configs/"* "$CONFIG_DIR/"
    success "Konfigurationsdateien kopiert"
else
    warn "Kein 'configs' Ordner im Repo gefunden!"
fi

# Wallpaper-Fix
if [[ -d "$SCRIPT_DIR/wallpapers" ]]; then
    cp "$SCRIPT_DIR/wallpapers/"* "$TARGET_HOME/Pictures/wallpapers/" 2>/dev/null || true
    success "Wallpapers kopiert"
fi

# Neofetch Logo
mkdir -p "$CONFIG_DIR/neofetch"
cat > "$CONFIG_DIR/neofetch/snowfox.txt" << 'ASCIIEOF'
                .... .....-            
   ..      ... ..- ........        
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

# Akku Check für Polybar
BAT_NAME="BAT0"
for bat in /sys/class/power_supply/BAT*; do
    [[ -d "$bat" ]] && BAT_NAME=$(basename "$bat") && break
done
if [[ -f "$CONFIG_DIR/polybar/config.ini" ]]; then
    sed -i "s/^battery = BAT.*/battery = $BAT_NAME/" "$CONFIG_DIR/polybar/config.ini" 2>/dev/null || true
fi

# snowfox CLI & Greeting
cp "$SCRIPT_DIR/snowfox" /usr/local/bin/snowfox 2>/dev/null || true
chmod +x /usr/local/bin/snowfox 2>/dev/null || true
cp "$SCRIPT_DIR/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting 2>/dev/null || true
chmod +x /usr/local/bin/snowfox-greeting 2>/dev/null || true

if ! grep -q "snowfox-greeting" "$TARGET_HOME/.bashrc" 2>/dev/null; then
    echo '' >> "$TARGET_HOME/.bashrc"
    echo '# SnowFoxOS Greeting' >> "$TARGET_HOME/.bashrc"
    echo '[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting' >> "$TARGET_HOME/.bashrc"
fi

# GTK2 Theme-Fix (Arc-Dark)
cat > "$TARGET_HOME/.gtkrc-2.0" << 'EOF'
include "/usr/share/themes/Arc-Dark/gtk-2.0/gtkrc"
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Sans 10"
gtk-cursor-theme-name="Adwaita"
EOF

# Finale Berechtigungen (WICHTIG)
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"
success "Berechtigungen für $TARGET_USER gesetzt"
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
