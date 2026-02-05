#!/bin/sh
echo -ne '\033c\033]0;MP Hot Rum\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/MP Hot Rum.x86_64" "$@"
