#!/bin/sh

sketchybar --set "$NAME" label="$(date '+✱  %A %-m.%-d  ✱  %I:%M:%S' | tr '[:upper:]' '[:lower:]')"
