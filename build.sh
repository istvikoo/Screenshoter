#!/bin/zsh
# Збирає Screenshoter.app поруч із цим скриптом.
# ./build.sh          — тільки зібрати
# ./build.sh install  — зібрати й встановити в /Applications
set -e
cd "$(dirname "$0")"

APP="Screenshoter.app"
VERSION="1.3.0"   # версія програми — береться і для установщика
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Універсальна програма: Apple Silicon (arm64) + Intel (x86_64), обидві збираються паралельно.
#   -Osize -wmo  — оптимізація розміру по всьому модулю (програма майже весь час спить,
#                  тож швидкість коду неважлива, а розмір — так)
#   strip -x     — прибрати локальні символи налагодження
BUILD_TMP=$(mktemp -d)
trap 'rm -rf "$BUILD_TMP"' EXIT
PIDS=()
for ARCH in arm64 x86_64; do
    swiftc -Osize -wmo -swift-version 5 -target $ARCH-apple-macos13.0 -Xlinker -dead_strip \
           *.swift -o "$BUILD_TMP/Screenshoter-$ARCH" &
    PIDS+=($!)
done
for PID in $PIDS; do wait $PID; done   # з set -e скрипт зупиниться, якщо хоч одна збірка впала
lipo -create "$BUILD_TMP"/Screenshoter-* -output "$APP/Contents/MacOS/Screenshoter"
strip -x "$APP/Contents/MacOS/Screenshoter"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Screenshoter</string>
    <key>CFBundleIdentifier</key>      <string>local.screenshoter</string>
    <key>CFBundleExecutable</key>      <string>Screenshoter</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>         <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>LSUIElement</key>             <true/>
</dict>
</plist>
PLIST

# Локальний підпис. Явна вимога «designated => identifier …» потрібна, щоб macOS
# упізнавала програму за ідентифікатором, а не за відбитком збірки (cdhash).
# Інакше після кожного перезбирання дозвіл на запис екрана «злітає».
codesign --force --sign - --identifier local.screenshoter \
         --requirements '=designated => identifier "local.screenshoter"' "$APP"

echo "Готово: $(pwd)/$APP"

# ./build.sh install — ще й поставити в «Програми» і запустити звідти.
# Для автозапуску краще, щоб програма жила саме там.
if [[ "$1" == "install" ]]; then
    pkill -x Screenshoter || true
    rm -rf "/Applications/$APP"
    cp -R "$APP" /Applications/
    open "/Applications/$APP"
    echo "Встановлено: /Applications/$APP"
fi
