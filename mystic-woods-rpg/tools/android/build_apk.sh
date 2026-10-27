#!/bin/bash
# Builds the Android APK headless: installs the Godot export templates, a minimal "Android SDK"
# (apksigner made from tools/android/ApkSignerTool.java + apksig, a stub adb) and exports the
# "Android" preset signed with the release keystore.
# Usage: tools/android/build_apk.sh <godot binary> <keystore> <alias> <password> [out.apk]
# PROJ=<dir> exports another Godot project of this repository (e.g. PROJ=mmorpg).
set -e
GODOT=$1; KS=$2; ALIAS=$3; PASS=$4; OUT=${5:-$HOME/build/MysticWoodsRPG.apk}
VER=4.7.2
HERE=$(cd "$(dirname "$0")" && pwd); PROJ=$(cd "${PROJ:-$HERE/../..}" && pwd)
SDK=$HOME/android_sdk; BT=$SDK/build-tools/34.0.0
TPL=$HOME/.local/share/godot/export_templates/$VER.stable
if [ ! -f "$TPL/android_release.apk" ]; then
	mkdir -p "$TPL" /tmp/godot_tpl && cd /tmp/godot_tpl
	curl -sSfL -o t.tpz "https://github.com/godotengine/godot/releases/download/$VER-stable/Godot_v$VER-stable_export_templates.tpz"
	unzip -o -q t.tpz templates/android_debug.apk templates/android_release.apk templates/version.txt
	mv templates/* "$TPL/" && rm -rf /tmp/godot_tpl
fi
if [ ! -x "$BT/apksigner" ]; then
	mkdir -p "$BT" "$SDK/platform-tools" "$SDK/platforms/android-34" /tmp/apksig_build/cls
	curl -sSfL -o "$BT/uber-apk-signer.jar" https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar
	javac -cp "$BT/uber-apk-signer.jar" -d /tmp/apksig_build/cls "$HERE/ApkSignerTool.java"
	(cd /tmp/apksig_build/cls && jar cf "$BT/signer.jar" .)
	printf '#!/bin/sh\nD=$(dirname "$0")\nexec java -cp "$D/uber-apk-signer.jar:$D/signer.jar" ApkSignerTool "$@"\n' > "$BT/apksigner"
	printf '#!/bin/sh\necho "Android Debug Bridge version 1.0.41"\n' > "$SDK/platform-tools/adb"
	chmod +x "$BT/apksigner" "$SDK/platform-tools/adb"
fi
CFG=$HOME/.config/godot/editor_settings-4.7.tres
mkdir -p "$(dirname "$CFG")"
[ -f "$CFG" ] || printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$CFG"
grep -q android_sdk_path "$CFG" && sed -i "s|export/android/android_sdk_path = .*|export/android/android_sdk_path = \"$SDK\"|" "$CFG" || echo "export/android/android_sdk_path = \"$SDK\"" >> "$CFG"
JDK=$(dirname "$(dirname "$(readlink -f "$(which java)")")")
grep -q java_sdk_path "$CFG" || echo "export/android/java_sdk_path = \"$JDK\"" >> "$CFG"
mkdir -p "$(dirname "$OUT")"
cd "$PROJ"
# every build gets a higher version code so the phone installs it over the previous one
CODE=$(( $(sed -n 's/^version\/code=//p' export_presets.cfg) + 1 ))
sed -i "s/^version\/code=.*/version\/code=$CODE/" export_presets.cfg
echo "version code $CODE"
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$KS GODOT_ANDROID_KEYSTORE_RELEASE_USER=$ALIAS GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$PASS \
	"$GODOT" --headless --path . --export-release "Android" "$OUT"
"$BT/apksigner" verify "$OUT"
