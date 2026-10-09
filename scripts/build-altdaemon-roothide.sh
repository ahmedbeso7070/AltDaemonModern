#!/bin/bash
set -eu

ALTDAEMON_REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ALTDAEMON_OPENSSL_ROOT="$ALTDAEMON_REPOSITORY_ROOT/Dependencies/AltSign/Dependencies/OpenSSL"
ALTDAEMON_OPENSSL_STAGE=${1:-"${TMPDIR:-/tmp}/OpenSSLArm64e"}
ALTDAEMON_DERIVED_DATA_DIR=${ALTDAEMON_DERIVED_DATA_DIR:-${TMPDIR:-/tmp}/AltDaemonRootHideDerivedData}
ALTDAEMON_PACKAGE_CACHE_DIR=${ALTDAEMON_PACKAGE_CACHE_DIR:-${TMPDIR:-/tmp}/AltDaemonPackages}

if [ -d "$ALTDAEMON_OPENSSL_STAGE/iphoneos" ]; then
    ALTDAEMON_OPENSSL_INCLUDE="$ALTDAEMON_OPENSSL_STAGE/iphoneos/include"
    ALTDAEMON_OPENSSL_LIB="$ALTDAEMON_OPENSSL_STAGE/iphoneos/lib"
elif [ -d "$ALTDAEMON_OPENSSL_STAGE/include" ]; then
    ALTDAEMON_OPENSSL_INCLUDE="$ALTDAEMON_OPENSSL_STAGE/include"
    ALTDAEMON_OPENSSL_LIB="$ALTDAEMON_OPENSSL_STAGE/lib"
else
    ALTDAEMON_OPENSSL_INCLUDE=""
    ALTDAEMON_OPENSSL_LIB=""
fi

if [ -d "$ALTDAEMON_OPENSSL_ROOT/iphoneos" ] && [ ! -d "$ALTDAEMON_OPENSSL_STAGE/iphoneos" ]; then
    mkdir -p "$ALTDAEMON_OPENSSL_STAGE"
    cp -R "$ALTDAEMON_OPENSSL_ROOT/iphoneos/." "$ALTDAEMON_OPENSSL_STAGE/"
fi

if [ ! -d "$ALTDAEMON_OPENSSL_STAGE/iphoneos" ] && [ ! -d "$ALTDAEMON_OPENSSL_STAGE/include" ]; then
    echo "error: OpenSSL stage is missing; run scripts/build-openssl-arm64e.sh first" >&2
    exit 1
fi

if [ -z "$ALTDAEMON_OPENSSL_INCLUDE" ] || [ ! -f "$ALTDAEMON_OPENSSL_INCLUDE/openssl/err.h" ]; then
    echo "error: staged OpenSSL headers are missing from $ALTDAEMON_OPENSSL_STAGE" >&2
    exit 1
fi

git -C "$ALTDAEMON_REPOSITORY_ROOT" submodule update --init --recursive Dependencies/AltSign

xcodebuild \
    -quiet \
    -workspace "$ALTDAEMON_REPOSITORY_ROOT/AltStore.xcworkspace" \
    -scheme AltDaemon \
    -configuration Release \
    -sdk iphoneos \
    -destination generic/platform=iOS \
    -derivedDataPath "$ALTDAEMON_DERIVED_DATA_DIR" \
    -clonedSourcePackagesDirPath "$ALTDAEMON_PACKAGE_CACHE_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    ARCHS="arm64 arm64e" \
    ONLY_ACTIVE_ARCH=NO \
    "HEADER_SEARCH_PATHS=\$(inherited) $ALTDAEMON_OPENSSL_INCLUDE" \
    "LIBRARY_SEARCH_PATHS=\$(inherited) $ALTDAEMON_OPENSSL_LIB" \
    build

echo "Built unsigned arm64 + arm64e binary: $ALTDAEMON_DERIVED_DATA_DIR/Build/Products/Release-iphoneos/AltDaemon"
