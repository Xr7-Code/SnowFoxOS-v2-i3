#!/bin/bash
# SnowFoxOS — Netzwerk-Manager via Rofi (X11)

NETWORKS=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | while IFS=: read -r INUSE SSID SIGNAL SECURITY; do
    [[ -z "$SSID" || "$SSID" == "--" ]] && continue
    # Maskiere Doppelpunkte in SSIDs zurück (nmcli -t nutzt : als Trenner)
    SSID_CLEAN=$(echo "$SSID" | sed 's/\\:/:/g')
    ICON=$([ "$INUSE" = "*" ] && echo "●" || echo "○")
    SEC_LABEL=$([ -z "$SECURITY" ] && echo "OPEN" || echo "$SECURITY")
    printf "%s %-30s %3s%%  %s\n" "$ICON" "$SSID_CLEAN" "$SIGNAL" "$SEC_LABEL"
done)

EXTRAS="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WiFi an/aus
  Verbindung trennen
  Ethernet-Status
  Netzwerk-Details"

CHOICE=$(echo -e "$NETWORKS\n$EXTRAS" | rofi -dmenu \
    -p "Netzwerk" \
    -theme ~/.config/rofi/config.rasi \
    -width 500 \
    -lines 12)

[[ -z "$CHOICE" ]] && exit 0

case "$CHOICE" in
    *"WiFi an/aus"*)
        STATE=$(nmcli radio wifi)
        if [[ "$STATE" == "enabled" ]]; then
            nmcli radio wifi off
            notify-send "🦊 SnowFox" "WiFi deaktiviert"
        else
            nmcli radio wifi on
            notify-send "🦊 SnowFox" "WiFi aktiviert"
        fi
        ;;
    *"Verbindung trennen"*)
        ACTIVE=$(nmcli -t -f NAME connection show --active | head -1)
        if [[ -n "$ACTIVE" ]]; then
            nmcli connection down "$ACTIVE"
            notify-send "🦊 SnowFox" "Getrennt von: $ACTIVE"
        else
            notify-send "🦊 SnowFox" "Keine aktive Verbindung"
        fi
        ;;
    *"Ethernet-Status"*)
        ETH=$(nmcli device status | grep ethernet)
        notify-send "🦊 SnowFox Ethernet" "$ETH"
        ;;
    *"Netzwerk-Details"*)
        INFO=$(nmcli device show | grep -E "GENERAL.DEVICE|GENERAL.STATE|IP4.ADDRESS|IP4.GATEWAY" | head -12)
        notify-send "🦊 SnowFox Netzwerk" "$INFO"
        ;;
    *"━━━"*)
        exit 0
        ;;
    *)
        # SSID extrahieren (Position 3 bis 32 basierend auf dem printf-Format)
        SSID=$(echo "$CHOICE" | cut -c3-32 | sed 's/  *$//')
        [[ -z "$SSID" ]] && exit 0

        # Aktuelle SSID sicher ermitteln (nur wenn WiFi an ist)
        CURRENT=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2- | sed 's/\\:/:/g')
        if [[ "$CURRENT" == "$SSID" ]]; then
            PORTAL_URL=$(curl -s -I --max-time 3 http://detectportal.firefox.com/success.txt \
                | grep -i "^location:" | awk '{print $2}' | tr -d '\r')
            if [[ -n "$PORTAL_URL" ]]; then
                notify-send "🦊 SnowFox" "Captive Portal erkannt"
                xdg-open "$PORTAL_URL" &
            else
                notify-send "🦊 SnowFox" "Bereits verbunden mit: $SSID"
            fi
            exit 0
        fi

        # Security-Typ sicher aus dem Choice-String extrahieren (letztes Wort)
        SECURITY=$(echo "$CHOICE" | rev | awk '{print $1}' | rev)

        if nmcli connection show "$SSID" &>/dev/null; then
            nmcli connection up "$SSID" && \
                notify-send "🦊 SnowFox" "Verbunden mit: $SSID" || \
                notify-send "🦊 SnowFox" "Verbindung fehlgeschlagen"

        elif [[ "$SECURITY" = "--" || "$CHOICE" == *"OPEN"* ]]; then
            notify-send "🦊 SnowFox" "Verbinde mit: $SSID"
            nmcli device wifi connect "$SSID" 2>/dev/null
            sleep 3
            PORTAL_URL=$(curl -s -I --max-time 3 http://detectportal.firefox.com/success.txt \
                | grep -i "^location:" | awk '{print $2}' | tr -d '\r')
            if [[ -n "$PORTAL_URL" ]]; then
                notify-send "🦊 SnowFox" "Captive Portal — Browser wird geöffnet"
                xdg-open "$PORTAL_URL" &
            else
                notify-send "🦊 SnowFox" "Verbunden mit: $SSID"
            fi

        else
            PASS=$(rofi -dmenu \
                -p "Passwort für $SSID" \
                -theme ~/.config/rofi/config.rasi \
                -width 400 \
                -lines 0 \
                -password)

            if [[ -n "$PASS" ]]; then
                nmcli device wifi connect "$SSID" password "$PASS" && \
                    notify-send "🦊 SnowFox" "Verbunden mit: $SSID" || \
                    notify-send "🦊 SnowFox" "Verbindung fehlgeschlagen — falsches Passwort?"
            else
                nmcli device wifi connect "$SSID" && \
                    notify-send "🦊 SnowFox" "Verbunden mit: $SSID" || \
                    notify-send "🦊 SnowFox" "Verbindung fehlgeschlagen"
            fi
        fi
        ;;
esac
