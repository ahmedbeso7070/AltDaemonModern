#!/bin/bash
set -eu

ALTDAEMON_REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ALTDAEMON_OPENSSL_ROOT="$ALTDAEMON_REPOSITORY_ROOT/Dependencies/AltSign/Dependencies/OpenSSL"
ALTDAEMON_OUTPUT_DIR=${1:-"${TMPDIR:-/tmp}/OpenSSLArm64e"}
ALTDAEMON_OPENSSL_STAGE="$ALTDAEMON_OUTPUT_DIR/iphoneos"

mkdir -p "$ALTDAEMON_OUTPUT_DIR"

if [ -d "$ALTDAEMON_OPENSSL_ROOT/iphoneos" ]; then
    rm -rf "$ALTDAEMON_OPENSSL_STAGE"
    mkdir -p "$ALTDAEMON_OPENSSL_STAGE"
    cp -R "$ALTDAEMON_OPENSSL_ROOT/iphoneos/." "$ALTDAEMON_OPENSSL_STAGE/"
    echo "Staged pinned iPhoneOS OpenSSL under $ALTDAEMON_OPENSSL_STAGE"
    exit 0
fi

if [ -d "$ALTDAEMON_OPENSSL_ROOT" ] && [ -f "$ALTDAEMON_OPENSSL_ROOT/Configure" ]; then
    rm -rf "$ALTDAEMON_OPENSSL_STAGE"
    mkdir -p "$ALTDAEMON_OPENSSL_STAGE"

    cd "$ALTDAEMON_OPENSSL_ROOT"
    ./Configure \
        iphoneos-cross \
        --prefix="$ALTDAEMON_OPENSSL_STAGE" \
        no-shared \
        enable-ec_nistp_64_gcc_128 \
        no-ssl2 \
        no-ssl3 \
        no-tests

    make -j"$(sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
    make install_sw install_ssldirs

    echo "Built OpenSSL for arm64/arm64e under $ALTDAEMON_OPENSSL_STAGE"
    exit 0
fi

echo "error: pinned OpenSSL sources are missing at $ALTDAEMON_OPENSSL_ROOT" >&2
exit 1
