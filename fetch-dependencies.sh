#!/bin/sh
set -eu

case "${1-}" in
    godot|han-march) project=$1 ;;
    *) printf '%s\n' 'Usage: sh fetch-dependencies.sh godot|han-march' >&2; exit 2 ;;
esac

cd "$(dirname "$0")"
test -f "$project/project.godot"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

curl --fail --silent --show-error --location \
    'https://raw.githubusercontent.com/google/fonts/4efc2774c63917927efe769ca845def6bd6debae/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf' \
    -o "$scratch/font.ttf"
(cd "$scratch" && printf '%s\n' '194018e6b2b293a7964f037b25c0249ce1418bc9ab3c971060a03aa57861e252  font.ttf' | shasum -a 256 -c -)
cp "$scratch/font.ttf" "$project/assets/NotoSansKR.ttf"

if [ "$project" = han-march ]; then
    curl --fail --silent --show-error --location \
        'https://github.com/limbonaut/limboai/releases/download/v1.7.1/limboai%2Bv1.7.1.gdextension-4.6.zip' \
        -o "$scratch/limbo.zip"
    (cd "$scratch" && printf '%s\n' 'ceb1757103744454d87ef12884e9d30978ff6edda6b4f09ff8da4d88e11a814e  limbo.zip' | shasum -a 256 -c -)
    unzip -oq "$scratch/limbo.zip" 'addons/limboai/*' -d "$project"
fi
