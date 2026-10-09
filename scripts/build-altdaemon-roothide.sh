#!/bin/sh

# RootHide variant of build-altdaemon.sh: builds AltDaemon for arm64 + arm64e.
# The original script is intentionally left untouched.
#
# Requires an OpenSSL directory that contains arm64 and arm64e slices, as
# produced by scripts/build-openssl-arm64e.sh:
#   usage: build-altdaemon-roothide.sh <openssl-arm64e-directory>

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <openssl-arm64e-directory>" >&2
    exit 64
fi

ALTDAEMON_REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ALTDAEMON_OPENSSL_ROOT=$(CDPATH= cd -- "$1" && pwd)
ALTDAEMON_DERIVED_DATA_DIR=${ALTDAEMON_DERIVED_DATA_DIR:-${TMPDIR:-/tmp}/AltDaemonModernRootHideDerivedData}
ALTDAEMON_PACKAGE_CACHE_DIR=${ALTDAEMON_PACKAGE_CACHE_DIR:-${TMPDIR:-/tmp}/AltDaemonModernPackages}

git -C "$ALTDAEMON_REPOSITORY_ROOT" submodule update --init --recursive Dependencies/AltSign

if [ ! -f "$ALTDAEMON_OPENSSL_ROOT/include/openssl/err.h" ]; then
    echo "error: OpenSSL headers are missing in $ALTDAEMON_OPENSSL_ROOT/include" >&2
    exit 1
fi

for ALTDAEMON_LIB in libcrypto.a libssl.a; do
    ALTDAEMON_LIB_ARCHS=$(xcrun lipo -archs "$ALTDAEMON_OPENSSL_ROOT/lib/$ALTDAEMON_LIB")
    case " $ALTDAEMON_LIB_ARCHS " in
        *" arm64 "*" arm64e "* | *" arm64e "*" arm64 "*) ;;
        *)
            echo "error: $ALTDAEMON_LIB needs arm64 and arm64e slices (found: $ALTDAEMON_LIB_ARCHS)" >&2
            exit 1
            ;;
    esac
done

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
    "ARCHS=arm64 arm64e" \
    ONLY_ACTIVE_ARCH=NO \
    "HEADER_SEARCH_PATHS=\$(inherited) $ALTDAEMON_OPENSSL_ROOT/include" \
    "LIBRARY_SEARCH_PATHS=\$(inherited) $ALTDAEMON_OPENSSL_ROOT/lib" \
    build

echo "Built unsigned arm64/arm64e binary: $ALTDAEMON_DERIVED_DATA_DIR/Build/Products/Release-iphoneos/AltDaemon"
