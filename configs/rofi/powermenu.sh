#!/bin/bash
chosen=$(echo -e "Beenden\nNeustart\nStandby\nSperren" | rofi -dmenu -i -p "SnowFox Power:" -theme ~/.config/rofi/config.rasi)

case "$chosen" in
    "Beenden") poweroff ;;
    "Neustart") reboot ;;
    "Standby") systemctl suspend ;;
    "Sperren") i3lock -c 0f0f0f ;;
esac
