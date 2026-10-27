// Додатково зберігає знімок з буфера обміну PNG-файлом у вибрану папку
// (вмикається в налаштуваннях: «Також зберігати знімки в папку»).

import Cocoa

enum ScreenshotSaver {
    static var isEnabled: Bool {
        get { Preferences.saveToFolder }
        set { Preferences.saveToFolder = newValue }
    }

    static var folder: URL {
        get { Preferences.saveFolder }
        set { Preferences.saveFolder = newValue }
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter
    }()

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
        let base = "Screenshoter \(fileDateFormatter.string(from: Date()))"

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
