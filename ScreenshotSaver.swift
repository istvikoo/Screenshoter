// Додатково зберігає знімок з буфера обміну PNG-файлом у вибрану папку
// (вмикається в налаштуваннях: «Також зберігати знімки в папку»).

import Cocoa

enum ScreenshotSaver {
    private static let enabledKey = "saveToFolder"
    private static let folderKey = "saveFolderPath"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }   // за замовчуванням вимкнено
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// За замовчуванням — ~/Pictures/Screenshoter.
    static var folder: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: folderKey) {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            return FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Screenshoter", isDirectory: true)
        }
        set { UserDefaults.standard.set(newValue.path, forKey: folderKey) }
    }

    /// Шлях для показу: /Users/імʼя/Pictures/… → ~/Pictures/…
    static var folderDisplayPath: String { (folder.path as NSString).abbreviatingWithTildeInPath }

    /// Зберегти те, що зараз у буфері. completion(nil) — успіх, інакше текст помилки.
    static func saveClipboard(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        // Беремо дані одразу (на головному потоці), а важку конвертацію — у фон.
        let png = pasteboard.data(forType: .png)
        let tiff = png == nil ? pasteboard.data(forType: .tiff) : nil
        let target = folder

        DispatchQueue.global(qos: .userInitiated).async {
            let result: String?
            do {
                guard let data = png ?? tiff.flatMap({ NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:]) })
                else { throw NSError(domain: "Screenshoter", code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: "no image in clipboard"]) }
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                try data.write(to: uniqueFile(in: target), options: .withoutOverwriting)
                result = nil
            } catch {
                result = error.localizedDescription
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// «Screenshoter 2026-10-27 17-45-12.png», а якщо такий уже є — «… (2).png».
    private static func uniqueFile(in folder: URL) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let base = "Screenshoter \(formatter.string(from: Date()))"

        var url = folder.appendingPathComponent(base + ".png")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) (\(n)).png")
            n += 1
        }
        return url
    }

    static func openFolderInFinder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }
}
