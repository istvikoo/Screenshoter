#!/bin/zsh
# Робить AppIcon.icns з AppIcon.png (квадратна картинка без полів).
# Запускати, коли змінюєте картинку іконки:  ./Resources/make_icon.sh
set -e
cd "$(dirname "$0")"

# Стандартна сітка macOS: сама іконка 824×824 по центру полотна 1024×1024.
swift - <<'SWIFT'
import AppKit
let src = NSImage(contentsOfFile: "AppIcon.png")!
let canvas = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
NSGraphicsContext.current?.imageInterpolation = .high
src.draw(in: NSRect(x: 100, y: 100, width: 824, height: 824))
NSGraphicsContext.restoreGraphicsState()
try! canvas.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "icon_1024.png"))
SWIFT

rm -rf AppIcon.iconset && mkdir AppIcon.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size icon_1024.png --out AppIcon.iconset/icon_${size}x${size}.png >/dev/null
  sips -z $((size*2)) $((size*2)) icon_1024.png --out AppIcon.iconset/icon_${size}x${size}@2x.png >/dev/null
done
iconutil -c icns AppIcon.iconset -o AppIcon.icns
rm -rf AppIcon.iconset icon_1024.png
echo "Готово: $(pwd)/AppIcon.icns"
