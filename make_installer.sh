#!/bin/zsh
# Збирає установщик dist/Screenshoter-<версія>.pkg, який ставить програму в /Applications.
set -e
cd "$(dirname "$0")"

./build.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Screenshoter.app/Contents/Info.plist)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/root" dist
# Копіюємо без розширених атрибутів, щоб у пакет не потрапили службові файли «._*».
export COPYFILE_DISABLE=1
ditto --norsrc --noextattr --noqtn Screenshoter.app "$WORK/root/Screenshoter.app"

# Опис компонента: забороняємо «переїзд», інакше установщик може оновити
# копію програми деінде на диску (напр. на робочому столі) замість /Applications.
pkgbuild --analyze --root "$WORK/root" "$WORK/component.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$WORK/component.plist"

pkgbuild --root "$WORK/root" \
         --component-plist "$WORK/component.plist" \
         --scripts Installer/scripts \
         --identifier local.screenshoter.pkg \
         --version "$VERSION" \
         --install-location /Applications \
         "$WORK/Screenshoter-component.pkg" >/dev/null

cat > "$WORK/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Screenshoter $VERSION</title>
    <welcome file="welcome.html" mime-type="text/html"/>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <domains enable_localSystem="true" enable_anywhere="false" enable_currentUserHome="false"/>
    <allowed-os-versions><os-version min="13.0"/></allowed-os-versions>
    <choices-outline><line choice="default"><line choice="local.screenshoter.pkg"/></line></choices-outline>
    <choice id="default"/>
    <choice id="local.screenshoter.pkg" visible="false"><pkg-ref id="local.screenshoter.pkg"/></choice>
    <pkg-ref id="local.screenshoter.pkg" version="$VERSION" onConclusion="none">Screenshoter-component.pkg</pkg-ref>
</installer-gui-script>
XML

OUT="dist/Screenshoter-$VERSION.pkg"
productbuild --distribution "$WORK/distribution.xml" \
             --package-path "$WORK" \
             --resources Installer/resources \
             "$OUT" >/dev/null

echo "Установщик готовий: $(pwd)/$OUT"
