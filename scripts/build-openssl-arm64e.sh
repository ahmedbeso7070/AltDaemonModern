#!/bin/sh

# The pinned OpenSSL iPhoneOS libraries (AltSign/Dependencies/OpenSSL) contain
# only armv7, armv7s and arm64 slices, so an arm64e AltDaemon cannot link
# against them. This script builds an arm64e slice of the same OpenSSL version
# (1.1.1l) with the target definitions shipped in that submodule, then merges it
# with the existing arm64 slice into a new directory:
#
#   <output>/include/openssl/...   (copied from the pinned headers)
#   <output>/lib/libcrypto.a       (arm64 + arm64e)
#   <output>/lib/libssl.a          (arm64 + arm64e)
#
# Nothing inside the repository or its submodules is modified.

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <output-directory>" >&2
    exit 64
fi

ALTDAEMON_REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ALTDAEMON_OPENSSL_ROOT=${ALTDAEMON_OPENSSL_ROOT:-"$ALTDAEMON_REPOSITORY_ROOT/Dependencies/AltSign/Dependencies/OpenSSL"}
ALTDAEMON_OPENSSL_OUTPUT=$1

# Commit that the upstream tag OpenSSL_1_1_1l points to.
ALTDAEMON_OPENSSL_COMMIT=fb047ebc87b18bdc4cf9ddee9ee1f5ed93e56aff
ALTDAEMON_OPENSSL_URL=https://github.com/openssl/openssl.git

git -C "$ALTDAEMON_REPOSITORY_ROOT" submodule update --init --recursive Dependencies/AltSign

for ALTDAEMON_REQUIRED in \
    "$ALTDAEMON_OPENSSL_ROOT/config/20-apple.conf" \
    "$ALTDAEMON_OPENSSL_ROOT/iphoneos/include/openssl/err.h" \
    "$ALTDAEMON_OPENSSL_ROOT/iphoneos/lib/libcrypto.a" \
    "$ALTDAEMON_OPENSSL_ROOT/iphoneos/lib/libssl.a"
do
    if [ ! -f "$ALTDAEMON_REQUIRED" ]; then
        echo "error: missing $ALTDAEMON_REQUIRED" >&2
        exit 1
    fi
done

ALTDAEMON_WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/altdaemon-openssl.XXXXXX")
trap 'rm -rf -- "$ALTDAEMON_WORK_DIR"' EXIT HUP INT TERM

echo "Fetching OpenSSL 1.1.1l source ($ALTDAEMON_OPENSSL_COMMIT)"
ALTDAEMON_SRC="$ALTDAEMON_WORK_DIR/src"
mkdir -p "$ALTDAEMON_SRC"
git -C "$ALTDAEMON_SRC" init -q
git -C "$ALTDAEMON_SRC" remote add origin "$ALTDAEMON_OPENSSL_URL"
git -C "$ALTDAEMON_SRC" fetch -q --depth 1 origin "$ALTDAEMON_OPENSSL_COMMIT"
git -C "$ALTDAEMON_SRC" checkout -q FETCH_HEAD
if [ "$(git -C "$ALTDAEMON_SRC" rev-parse HEAD)" != "$ALTDAEMON_OPENSSL_COMMIT" ]; then
    echo "error: fetched OpenSSL commit does not match the pinned commit" >&2
    exit 1
fi

# Use the submodule's Apple target definitions, minus bitcode (removed from Xcode).
ALTDAEMON_CONFIG_DIR="$ALTDAEMON_WORK_DIR/config"
mkdir -p "$ALTDAEMON_CONFIG_DIR"
sed 's/ -fembed-bitcode//g' "$ALTDAEMON_OPENSSL_ROOT/config/20-apple.conf" > "$ALTDAEMON_CONFIG_DIR/20-apple.conf"
grep -q '"ios-cross-arm64e"' "$ALTDAEMON_CONFIG_DIR/20-apple.conf"

# Same source fix the submodule's build script applies (conflicts with <complex.h>).
perl -pi -e 's/BIGNUM \*I,/BIGNUM *i,/g' "$ALTDAEMON_SRC/crypto/rsa/rsa_local.h"

ALTDAEMON_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
export OPENSSL_LOCAL_CONFIG_DIR="$ALTDAEMON_CONFIG_DIR"
export IPHONEOS_DEPLOYMENT_VERSION=15.0
export CROSS_TOP="${ALTDAEMON_SDK%%/SDKs/*}"
export CROSS_SDK="${ALTDAEMON_SDK##*/SDKs/}"

cd "$ALTDAEMON_SRC"
./Configure ios-cross-arm64e no-asm no-shared --prefix="$ALTDAEMON_WORK_DIR/install" > "$ALTDAEMON_WORK_DIR/configure.log" 2>&1 || {
    tail -n 40 "$ALTDAEMON_WORK_DIR/configure.log" >&2
    exit 1
}
make -j"$(sysctl -n hw.ncpu)" build_libs > "$ALTDAEMON_WORK_DIR/make.log" 2>&1 || {
    tail -n 60 "$ALTDAEMON_WORK_DIR/make.log" >&2
    exit 1
}

mkdir -p "$ALTDAEMON_OPENSSL_OUTPUT/lib"
rm -rf -- "$ALTDAEMON_OPENSSL_OUTPUT/include"
cp -R "$ALTDAEMON_OPENSSL_ROOT/iphoneos/include" "$ALTDAEMON_OPENSSL_OUTPUT/include"

for ALTDAEMON_LIB in libcrypto.a libssl.a; do
    xcrun lipo "$ALTDAEMON_OPENSSL_ROOT/iphoneos/lib/$ALTDAEMON_LIB" -thin arm64 -output "$ALTDAEMON_WORK_DIR/$ALTDAEMON_LIB.arm64"
    xcrun lipo -create \
        "$ALTDAEMON_WORK_DIR/$ALTDAEMON_LIB.arm64" \
        "$ALTDAEMON_SRC/$ALTDAEMON_LIB" \
        -output "$ALTDAEMON_OPENSSL_OUTPUT/lib/$ALTDAEMON_LIB"
    echo "$ALTDAEMON_LIB: $(xcrun lipo -archs "$ALTDAEMON_OPENSSL_OUTPUT/lib/$ALTDAEMON_LIB")"
done

echo "Built arm64 + arm64e OpenSSL: $ALTDAEMON_OPENSSL_OUTPUT"
