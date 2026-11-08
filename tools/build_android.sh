#!/usr/bin/env bash
# Build the Android APK at build/android/snake3d.apk.
#
#   tools/build_android.sh            # release build (optimised engine), signed with a local key
#   tools/build_android.sh debug      # debug build, signed with the Android debug keystore
#   tools/build_android.sh --emulator # x86_64 build (build/android/snake3d-x86_64.apk) for the
#                                     # Android emulator; combinable with "debug"
#   tools/build_android.sh --showcase # demo build for screenshots (build/android/snake3d-showcase.apk):
#                                     # package com.studio.snake3d.showcase installs next to the game,
#                                     # with a demo profile and the autopilot playing (main.gd --showcase)
#   tools/build_android.sh --aab      # Android App Bundle for Google Play (build/android/snake3d.aab),
#                                     # built with Gradle; run "tools/setup_godot.sh --gradle" once first
#
# Environment overrides:
#   GODOT                                   path to a Godot 4.7.x editor binary (default tools/godot/godot)
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH     use your own release keystore instead of signing/release.keystore
#   GODOT_ANDROID_KEYSTORE_RELEASE_USER     its key alias
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD its password
#
# The first release build creates signing/release.keystore (git-ignored). Keep that file:
# Android only accepts an update of an installed APK signed with the same key.
set -euo pipefail

cd "$(dirname "$0")/.."
MODE="release"
PRESET="Android"
OUT="build/android/snake3d.apk"
for arg in "$@"; do
	case "$arg" in
		debug|release) MODE="$arg" ;;
		--emulator) PRESET="Android Emulator x86_64"; OUT="build/android/snake3d-x86_64.apk" ;;
		--showcase) PRESET="Android Showcase"; OUT="build/android/snake3d-showcase.apk" ;;
		--aab) PRESET="Android Play"; OUT="build/android/snake3d.aab" ;;
		*) echo "usage: $0 [release|debug] [--emulator|--showcase|--aab]" >&2; exit 2 ;;
	esac
done
GODOT="${GODOT:-tools/godot/godot}"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot not found at $GODOT - run tools/setup_godot.sh first (or set GODOT=...)." >&2
	exit 1
fi

find_tool() {
	local name="$1" candidate
	if command -v "$name" >/dev/null 2>&1; then command -v "$name"; return; fi
	for candidate in "${JAVA_HOME:-}/bin/$name" /usr/lib/jvm/default/bin/"$name"; do
		[[ -x "$candidate" ]] && { echo "$candidate"; return; }
	done
	local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
	candidate=$(ls -d "$sdk"/build-tools/*/"$name" 2>/dev/null | sort -V | tail -n1 || true)
	[[ -n "$candidate" ]] && { echo "$candidate"; return; }
	return 1
}

mkdir -p "$(dirname "$OUT")"
touch build/.gdignore
rm -f "$OUT" "$OUT.idsig"

echo "== Importing project resources"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

EXTRA=()
if [[ "$OUT" == *.aab ]]; then
	if [[ ! -f "$(dirname "$GODOT")/editor_data/export_templates/4.7.2.stable/android_source.zip" ]]; then
		echo "The Gradle build needs the Android source template: run tools/setup_godot.sh --gradle" >&2
		exit 1
	fi
	# First Gradle export: let Godot unpack its Android project into android/build.
	[[ -f android/build/build.gradle ]] || EXTRA+=(--install-android-build-template)
fi

if [[ "$MODE" == "debug" ]]; then
	echo "== Exporting DEBUG build"
	"$GODOT" --headless --path . "${EXTRA[@]}" --export-debug "$PRESET" "$OUT"
else
	if [[ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]]; then
		mkdir -p signing
		touch signing/.gdignore
		KS="signing/release.keystore"
		PROPS="signing/release.properties"
		if [[ ! -f "$KS" ]]; then
			KEYTOOL=$(find_tool keytool) || { echo "keytool (JDK) not found" >&2; exit 1; }
			PASS=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)
			echo "== Creating local release keystore $KS"
			"$KEYTOOL" -genkeypair -v -keystore "$KS" -alias snake3d -keyalg RSA -keysize 2048 \
				-validity 10000 -storepass "$PASS" -keypass "$PASS" \
				-dname "CN=3D Snake, O=Studio, C=US" >/dev/null 2>&1
			printf 'alias=snake3d\npassword=%s\n' "$PASS" > "$PROPS"
			chmod 600 "$KS" "$PROPS"
		fi
		export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/$KS"
		export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$(sed -n 's/^alias=//p' "$PROPS")"
		export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(sed -n 's/^password=//p' "$PROPS")"
	fi
	echo "== Exporting RELEASE build"
	"$GODOT" --headless --path . "${EXTRA[@]}" --export-release "$PRESET" "$OUT"
fi

if [[ ! -s "$OUT" ]]; then
	echo "Export failed: $OUT was not produced." >&2
	exit 1
fi

echo "== Verifying signature"
if [[ "$OUT" == *.aab ]]; then
	JARSIGNER=$(find_tool jarsigner) || { echo "jarsigner (JDK) not found" >&2; exit 1; }
	"$JARSIGNER" -verify "$OUT" | grep -q "jar verified" || {
		echo "Signature verification FAILED" >&2
		exit 1
	}
	echo "jar verified (signed with $(sed -n 's/^alias=//p' signing/release.properties 2>/dev/null || echo 'your key'))"
elif APKSIGNER=$(find_tool apksigner); then
	"$APKSIGNER" verify --verbose "$OUT" 2>/dev/null | grep -E '^Verifies|v2 scheme|v3 scheme' || {
		echo "Signature verification FAILED" >&2
		exit 1
	}
else
	echo "(apksigner not found - skipping signature check)"
fi

echo
echo "Ready: $OUT ($(du -h "$OUT" | cut -f1))"
