#!/bin/sh
printf '\033c\033]0;%s\a' Tiny MMO
base_path="$(dirname "$(realpath "$0")")"
"$base_path/kraftovia.server.0.1.x86_64" "$@"
