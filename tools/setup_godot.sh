#!/usr/bin/env bash
# One-time local toolchain setup (Linux x86_64):
#   * downloads the Godot 4.7.2 editor into tools/godot/ (self-contained mode, git-ignored)
#   * downloads only the Android export templates (~230 MB instead of the 1.3 GB bundle)
#   * creates an Android debug keystore
#   * points the editor at your Android SDK and JDK
#
#   tools/setup_godot.sh
#
# Environment overrides: ANDROID_HOME (default ~/Android/Sdk), JAVA_HOME (default: auto-detected).
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="4.7.2"
DIR="tools/godot"
DATA="$DIR/editor_data"
SETTINGS="$DATA/editor_settings-4.7.tres"
TEMPLATES="$DATA/export_templates/$VERSION.stable"

mkdir -p "$DIR"
if [[ ! -x "$DIR/godot" ]]; then
	ZIP="Godot_v${VERSION}-stable_linux.x86_64.zip"
	echo "== Downloading $ZIP"
	curl -fL --progress-bar -o "$DIR/$ZIP" \
		"https://github.com/godotengine/godot/releases/download/${VERSION}-stable/$ZIP"
	unzip -o -q "$DIR/$ZIP" -d "$DIR"
	mv "$DIR/Godot_v${VERSION}-stable_linux.x86_64" "$DIR/godot"
	rm -f "$DIR/$ZIP"
	chmod +x "$DIR/godot"
fi
# "._sc_" next to the binary = self-contained mode: settings/templates live in editor_data/.
touch "$DIR/._sc_"
mkdir -p "$DATA/keystores"
"$DIR/godot" --version

if [[ ! -f "$TEMPLATES/android_release.apk" ]]; then
	echo "== Fetching Android export templates"
	python3 tools/fetch_android_templates.py "$VERSION" "$TEMPLATES"
fi

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
if [[ ! -d "$SDK/platform-tools" || ! -d "$SDK/build-tools" ]]; then
	echo "WARNING: Android SDK not found at $SDK (needs platform-tools and build-tools)." >&2
	echo "         Install it (Android Studio or cmdline-tools) and re-run with ANDROID_HOME=..." >&2
fi

JDK="${JAVA_HOME:-}"
if [[ -z "$JDK" ]]; then
	if command -v javac >/dev/null 2>&1; then
		JDK=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")
	elif command -v java >/dev/null 2>&1; then
		JDK=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
	fi
fi
[[ -z "$JDK" ]] && echo "WARNING: no JDK found; install JDK 17+ and set JAVA_HOME." >&2

KEYSTORE="$PWD/$DATA/keystores/debug.keystore"
if [[ ! -f "$KEYSTORE" ]]; then
	KEYTOOL="${JDK:+$JDK/bin/}keytool"
	echo "== Creating debug keystore"
	"$KEYTOOL" -genkeypair -v -keystore "$KEYSTORE" -alias androiddebugkey -keyalg RSA -keysize 2048 \
		-validity 10000 -storepass android -keypass android \
		-dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi

echo "== Writing editor settings ($SETTINGS)"
python3 - "$SETTINGS" "$SDK" "$JDK" "$KEYSTORE" <<'EOF'
import os, re, sys
path, sdk, jdk, keystore = sys.argv[1:5]
wanted = {
    "export/android/android_sdk_path": sdk,
    "export/android/java_sdk_path": jdk,
    "export/android/debug_keystore": keystore,
    "export/android/debug_keystore_user": "androiddebugkey",
    "export/android/debug_keystore_pass": "android",
    # Otherwise every headless export ends with "adb kill-server", which drops
    # wireless-debugging connections to phones.
    "export/android/shutdown_adb_on_exit": "false",
}
text = open(path).read() if os.path.exists(path) else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
for key, value in wanted.items():
    line = f'{key} = {value}' if value in ("true", "false") else f'{key} = "{value}"'
    pattern = re.compile(rf"^{re.escape(key)} = .*$", re.M)
    text = pattern.sub(line, text) if pattern.search(text) else text.rstrip("\n") + "\n" + line + "\n"
open(path, "w").write(text)
EOF

echo
echo "Done. Next: tools/run_tests.sh  and  tools/build_android.sh"
