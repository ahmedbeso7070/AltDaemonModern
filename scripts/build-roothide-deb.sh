#!/bin/sh

set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: $0 <unsigned-or-signed-AltDaemon> [output.deb]" >&2
    exit 64
fi

ALTDAEMON_REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ALTDAEMON_INPUT_BINARY=$1
ALTDAEMON_DEB_OUTPUT=${2:-"$ALTDAEMON_REPOSITORY_ROOT/AltDaemonModern_1.2.0_iphoneos-arm64e.deb"}
ALTDAEMON_LDID_TOOL=${ALTDAEMON_LDID_TOOL:-ldid}
ALTDAEMON_DPKG_DEB_TOOL=${ALTDAEMON_DPKG_DEB_TOOL:-dpkg-deb}
ALTDAEMON_LIPO_TOOL=${ALTDAEMON_LIPO_TOOL:-lipo}
ALTDAEMON_PACKAGE_DIR="$ALTDAEMON_REPOSITORY_ROOT/AltDaemon/package-roothide"
ALTDAEMON_PACKAGE_STAGE=$(mktemp -d "${TMPDIR:-/tmp}/altdaemon-modern-roothide.XXXXXX")
ALTDAEMON_COMPAT_BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/altdaemon-modern-compat.XXXXXX")
ALTDAEMON_AUTH_COMPAT_BINARY=${ALTDAEMON_AUTH_COMPAT_BINARY:-"$ALTDAEMON_COMPAT_BUILD_DIR/AltStoreAuthCompat.dylib"}

cleanup()
{
    rm -rf -- "$ALTDAEMON_PACKAGE_STAGE" "$ALTDAEMON_COMPAT_BUILD_DIR"
}
trap cleanup EXIT HUP INT TERM

test -f "$ALTDAEMON_INPUT_BINARY"
command -v "$ALTDAEMON_LDID_TOOL" >/dev/null
command -v "$ALTDAEMON_DPKG_DEB_TOOL" >/dev/null

# The RootHide package must carry an arm64e slice.
if command -v "$ALTDAEMON_LIPO_TOOL" >/dev/null 2>&1; then
    ALTDAEMON_BINARY_ARCHS=$("$ALTDAEMON_LIPO_TOOL" -archs "$ALTDAEMON_INPUT_BINARY")
    case " $ALTDAEMON_BINARY_ARCHS " in
        *" arm64e "*) ;;
        *)
            echo "error: $ALTDAEMON_INPUT_BINARY has no arm64e slice (found: $ALTDAEMON_BINARY_ARCHS)" >&2
            exit 1
            ;;
    esac
fi

if [ ! -f "$ALTDAEMON_AUTH_COMPAT_BINARY" ]; then
    sh "$ALTDAEMON_REPOSITORY_ROOT/scripts/build-altstore-auth-compat-roothide.sh" "$ALTDAEMON_AUTH_COMPAT_BINARY"
fi

# RootHide packages install to ordinary paths; the jailbreak maps them into its
# randomized root, so nothing is staged under /var/jb.
mkdir -p \
    "$ALTDAEMON_PACKAGE_STAGE/DEBIAN" \
    "$ALTDAEMON_PACKAGE_STAGE/usr/bin" \
    "$ALTDAEMON_PACKAGE_STAGE/Library/LaunchDaemons" \
    "$ALTDAEMON_PACKAGE_STAGE/Library/MobileSubstrate/DynamicLibraries" \
    "$ALTDAEMON_PACKAGE_STAGE/usr/share/doc/altdaemonmodern"

chmod 0755 "$ALTDAEMON_PACKAGE_STAGE"

cp "$ALTDAEMON_PACKAGE_DIR/DEBIAN/control" "$ALTDAEMON_PACKAGE_STAGE/DEBIAN/control"
cp "$ALTDAEMON_PACKAGE_DIR/DEBIAN/preinst" "$ALTDAEMON_PACKAGE_STAGE/DEBIAN/preinst"
cp "$ALTDAEMON_PACKAGE_DIR/DEBIAN/postinst" "$ALTDAEMON_PACKAGE_STAGE/DEBIAN/postinst"
cp "$ALTDAEMON_PACKAGE_DIR/DEBIAN/prerm" "$ALTDAEMON_PACKAGE_STAGE/DEBIAN/prerm"
cp "$ALTDAEMON_INPUT_BINARY" "$ALTDAEMON_PACKAGE_STAGE/usr/bin/AltDaemon"
cp "$ALTDAEMON_PACKAGE_DIR/Library/LaunchDaemons/com.rileytestut.altdaemon.plist" "$ALTDAEMON_PACKAGE_STAGE/Library/LaunchDaemons/com.rileytestut.altdaemon.plist"
cp "$ALTDAEMON_AUTH_COMPAT_BINARY" "$ALTDAEMON_PACKAGE_STAGE/Library/MobileSubstrate/DynamicLibraries/AltStoreAuthCompat.dylib"
cp "$ALTDAEMON_REPOSITORY_ROOT/Compatibility/AltStoreAuthCompat/AltStoreAuthCompat.plist" "$ALTDAEMON_PACKAGE_STAGE/Library/MobileSubstrate/DynamicLibraries/AltStoreAuthCompat.plist"
cp "$ALTDAEMON_REPOSITORY_ROOT/LICENSE" "$ALTDAEMON_PACKAGE_STAGE/usr/share/doc/altdaemonmodern/AGPL-3.0.txt"
cp "$ALTDAEMON_REPOSITORY_ROOT/AltDaemon/NOTICE.md" "$ALTDAEMON_PACKAGE_STAGE/usr/share/doc/altdaemonmodern/NOTICE.md"

chmod 0755 "$ALTDAEMON_PACKAGE_STAGE/DEBIAN/preinst" "$ALTDAEMON_PACKAGE_STAGE/DEBIAN/postinst" "$ALTDAEMON_PACKAGE_STAGE/DEBIAN/prerm"
chmod 0755 "$ALTDAEMON_PACKAGE_STAGE/usr/bin/AltDaemon"
chmod 0755 "$ALTDAEMON_PACKAGE_STAGE/Library/MobileSubstrate/DynamicLibraries/AltStoreAuthCompat.dylib"
chmod 0644 \
    "$ALTDAEMON_PACKAGE_STAGE/DEBIAN/control" \
    "$ALTDAEMON_PACKAGE_STAGE/Library/LaunchDaemons/com.rileytestut.altdaemon.plist" \
    "$ALTDAEMON_PACKAGE_STAGE/Library/MobileSubstrate/DynamicLibraries/AltStoreAuthCompat.plist" \
    "$ALTDAEMON_PACKAGE_STAGE/usr/share/doc/altdaemonmodern/AGPL-3.0.txt" \
    "$ALTDAEMON_PACKAGE_STAGE/usr/share/doc/altdaemonmodern/NOTICE.md"

"$ALTDAEMON_LDID_TOOL" -S"$ALTDAEMON_REPOSITORY_ROOT/AltDaemon/AltDaemon.entitlements" "$ALTDAEMON_PACKAGE_STAGE/usr/bin/AltDaemon"
"$ALTDAEMON_LDID_TOOL" -S "$ALTDAEMON_PACKAGE_STAGE/Library/MobileSubstrate/DynamicLibraries/AltStoreAuthCompat.dylib"
"$ALTDAEMON_DPKG_DEB_TOOL" --build --root-owner-group "$ALTDAEMON_PACKAGE_STAGE" "$ALTDAEMON_DEB_OUTPUT"

echo "Built RootHide package: $ALTDAEMON_DEB_OUTPUT"
