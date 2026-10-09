#!/bin/bash
set -eu

ALTDAEMON_REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ALTDAEMON_OUTPUT=${1:-"${TMPDIR:-/tmp}/AltStoreAuthCompat.dylib"}
ALTDAEMON_IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
ALTDAEMON_CLANG=$(xcrun --sdk iphoneos --find clang)

mkdir -p "$(dirname -- "$ALTDAEMON_OUTPUT")"

"$ALTDAEMON_CLANG" \
    -arch arm64 \
    -arch arm64e \
    -dynamiclib \
    -fobjc-arc \
    -Os \
    -Wall \
    -Wextra \
    -Werror \
    -miphoneos-version-min=15.0 \
    -isysroot "$ALTDAEMON_IPHONEOS_SDK" \
    -framework Foundation \
    -install_name @rpath/AltStoreAuthCompat.dylib \
    "$ALTDAEMON_REPOSITORY_ROOT/Compatibility/AltStoreAuthCompat/Tweak.m" \
    -o "$ALTDAEMON_OUTPUT"

echo "Built unsigned roothide compatibility module: $ALTDAEMON_OUTPUT"
