#!/bin/sh

source "$CONFIG_DIR/icons.sh"

# The volume_change event supplies a $INFO variable in which the current volume
# percentage is passed to the script.

if [ "$SENDER" = "volume_change" ]; then
  VOLUME="$INFO"

  case "$VOLUME" in
    6[6-9]|7[0-9]|8[0-9]|9[0-9]|100)
      ICON="$VOLUME_100"
      ;;
    3[3-9]|4[0-9]|5[0-9]|6[0-5])
      ICON="$VOLUME_66"
      ;;
    1[0-9]|2[0-9]|3[0-2])
      ICON="$VOLUME_33"
      ;;
    [1-9]|10)
      ICON="$VOLUME_10"
      ;;
    0)
      ICON="$VOLUME_0"
      ;;
    *)
      ICON="$VOLUME_0"
  esac

  sketchybar --set "$NAME" icon="$ICON" label=" $VOLUME%"
fi
