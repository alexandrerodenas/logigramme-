#!/usr/bin/env bash
# Construit l'APK Android signé de Logigramme, sans Android SDK ni Gradle.
#
#   tools/build_apk.sh
#
# Variables optionnelles :
#   KEYSTORE      keystore de signature (défaut : build/keys/logigramme.keystore, créé s'il manque)
#   KS_ALIAS      alias de la clé (défaut : logigramme)
#   KS_PASS       mot de passe du keystore et de la clé (défaut : logigramme)
#   TOOLS_DIR     dossier des outils téléchargés (défaut : ~/.cache/logigramme-tools)
#
# Garder le même keystore d'une version à l'autre : Android refuse de mettre à jour
# une application signée par une autre clé.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT_VERSION="4.3-stable"
GODOT_TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION/-/.}"
UBER_VERSION="1.3.0"
TOOLS_DIR="${TOOLS_DIR:-$HOME/.cache/logigramme-tools}"
KEYSTORE="${KEYSTORE:-$ROOT/build/keys/logigramme.keystore}"
KS_ALIAS="${KS_ALIAS:-logigramme}"
KS_PASS="${KS_PASS:-logigramme}"
GH="https://github.com"

mkdir -p "$TOOLS_DIR" build
GODOT="$TOOLS_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"

# 1. Godot et modèles d'export Android (depuis les releases GitHub de Godot).
if [ ! -x "$GODOT" ]; then
  curl -fsSL -o "$TOOLS_DIR/godot.zip" "$GH/godotengine/godot/releases/download/$GODOT_VERSION/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -o -q "$TOOLS_DIR/godot.zip" -d "$TOOLS_DIR"
fi
if [ ! -f "$GODOT_TEMPLATES_DIR/android_release.apk" ]; then
  curl -fsSL -o "$TOOLS_DIR/templates.tpz" "$GH/godotengine/godot/releases/download/$GODOT_VERSION/Godot_v${GODOT_VERSION}_export_templates.tpz"
  mkdir -p "$GODOT_TEMPLATES_DIR"
  unzip -o -q -j "$TOOLS_DIR/templates.tpz" 'templates/android_*' 'templates/version.txt' -d "$GODOT_TEMPLATES_DIR"
fi

# 2. Signataire APK autonome (zipalign + signatures v1/v2/v3).
UBER="$TOOLS_DIR/uber-apk-signer-$UBER_VERSION.jar"
if [ ! -f "$UBER" ]; then
  curl -fsSL -o "$UBER" "$GH/patrickfav/uber-apk-signer/releases/download/v$UBER_VERSION/uber-apk-signer-$UBER_VERSION.jar"
fi

# 3. Faux Android SDK : l'export non signé de Godot vérifie seulement la présence
#    de adb et apksigner, sans les utiliser.
SHIM="$ROOT/build/sdk-shim"
mkdir -p "$SHIM/platform-tools" "$SHIM/build-tools/34.0.0"
printf '#!/bin/sh\nexit 0\n' > "$SHIM/platform-tools/adb"
printf '#!/bin/sh\nexit 0\n' > "$SHIM/build-tools/34.0.0/apksigner"
chmod +x "$SHIM/platform-tools/adb" "$SHIM/build-tools/34.0.0/apksigner"

SETTINGS="$HOME/.config/godot/editor_settings-4.3.tres"
if [ ! -f "$SETTINGS" ]; then
  "$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
fi
sed -i '/^export\/android\/android_sdk_path/d' "$SETTINGS"
echo "export/android/android_sdk_path = \"$SHIM\"" >> "$SETTINGS"

# 4. Import, tests du générateur, export.
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --script tools/test_generator.gd | grep -E "ECHECS|déterministe"
"$GODOT" --headless --export-release "Android" build/logigramme-unsigned.apk 2>&1 | grep -E "ERROR|export: end" || true
[ -f build/logigramme-unsigned.apk ] || { echo "Export Godot échoué" >&2; exit 1; }

# 5. Signature.
if [ ! -f "$KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -genkeypair -keystore "$KEYSTORE" -storepass "$KS_PASS" -keypass "$KS_PASS" -alias "$KS_ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Logigramme, C=FR"
fi
rm -rf build/out
java -jar "$UBER" -a build/logigramme-unsigned.apk -o build/out \
  --ks "$KEYSTORE" --ksAlias "$KS_ALIAS" --ksPass "$KS_PASS" --ksKeyPass "$KS_PASS" | grep -E "verified|success|error"
VERSION="$(grep -oP '^version/name="\K[^"]+' export_presets.cfg)"
cp build/out/logigramme-aligned-signed.apk "build/logigramme-$VERSION.apk"
rm build/logigramme-unsigned.apk
echo "APK prêt : build/logigramme-$VERSION.apk"
