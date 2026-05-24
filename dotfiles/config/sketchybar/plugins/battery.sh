#!/bin/sh

source "$CONFIG_DIR/icons.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

if [[ "$CHARGING" != "" ]]; then
  ICON="$BATTERY_CHARGING"
else
  case "${PERCENTAGE}" in
    8[0-9]|9[0-9]|100)
      ICON="$BATTERY_100"
      ;;
    3[4-9]|[4-7][0-9])
      ICON="$BATTERY_66"
      ;;
    1[1-9]|2[0-9]|3[0-3])
      ICON="$BATTERY_33"
      ;;
    10)
      ICON="$BATTERY_10"
      ;;
    [0-9])
      ICON="$BATTERY_0"
      ;;
    *) ICON="$BATTERY_0";;
  esac
fi

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set "$NAME" icon="$ICON" label=" ${PERCENTAGE}%"
