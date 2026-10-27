// Оновлення з GitHub Releases.
//
// 1. Раз на добу (або вручну) питаємо GitHub про останній реліз.
// 2. Якщо версія новіша — пропонуємо оновитися.
// 3. Завантажуємо Screenshoter-<версія>.pkg і Screenshoter-<версія>.pkg.sig.
// 4. Перевіряємо підпис Ed25519 вшитим публічним ключем. Не збігся — нічого не встановлюємо.
// 5. Відкриваємо .pkg у системному установщику (користувач вводить пароль).
//
// Підписують реліз скриптом release.sh (див. Tools/updatekey.swift).

import Cocoa
import CryptoKit

final class Updater {
    /// Публічна частина ключа, яким release.sh підписує установщик.
    private static let publicKeyBase64 = "X0p3HR/Z3rlj86oanXJpkEVSJ2hSEX/BKaX0B+RYfeE="

    private static let defaultAPI = URL(string: "https://api.github.com/repos/istvikoo/Screenshoter/releases/latest")!

    /// Для тестів можна підмінити адресу: defaults write local.screenshoter updateAPIURL <url>.
    /// Підпис перевіряється все одно, тож чужий файл так не підсунути.
    private var apiURL: URL {
        if let s = UserDefaults.standard.string(forKey: Keys.updateAPIURL), let url = URL(string: s) { return url }
        return Updater.defaultAPI
    }

    struct Release {
        let version: String
        let pkgURL: URL
        let sigURL: URL
        let pkgName: String
    }

    enum State {
        case idle
        case checking
        case available(Release)
        case downloading
    }

    private(set) var state: State = .idle { didSet { onStateChange?() } }
    var onStateChange: (() -> Void)?

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private var timer: Timer?

    // MARK: - Автоперевірка

    func start() {
        // Перша перевірка — трохи після запуску, далі щогодини дивимося, чи минула доба.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.checkIfDue() }
        let timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in self?.checkIfDue() }
        timer.tolerance = 600   // система може зсунути пробудження й об'єднати його з іншими — економія енергії
        self.timer = timer
    }

    private func checkIfDue() {
        guard Preferences.autoCheckUpdates else { return }
        let last = UserDefaults.standard.object(forKey: Keys.lastUpdateCheck) as? Date ?? .distantPast
        if Date().timeIntervalSince(last) > 24 * 3600 { check(userInitiated: false) }
    }

    // MARK: - Перевірка

    func check(userInitiated: Bool) {
        if case .checking = state { return }
        if case .downloading = state { return }
        let previous = state
        state = .checking

        var request = URLRequest(url: apiURL, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Screenshoter/\(Updater.currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleCheck(data: data, response: response, error: error,
                                  userInitiated: userInitiated, previous: previous)
            }
        }.resume()
    }

    private struct GHRelease: Decodable {
        let tag_name: String
        let draft: Bool?
        let prerelease: Bool?
        let assets: [GHAsset]
    }

    private struct GHAsset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    private func handleCheck(data: Data?, response: URLResponse?, error: Error?,
                             userInitiated: Bool, previous: State) {
        // Невдала перевірка (немає інтернету, збій GitHub) не рахується: спробуємо знову
        // за годину, а вже знайдене оновлення лишається в меню.
        if let error {
            state = previous
            if userInitiated { alert(Text.updateCheckFailed.format(error.localizedDescription)) }
            return
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let data, let gh = try? JSONDecoder().decode(GHRelease.self, from: data),
              gh.draft != true, gh.prerelease != true
        else {
            state = previous
            if userInitiated { alert(Text.updateCheckFailed.format("HTTP \(status)")) }
            return
        }
        state = .idle
        UserDefaults.standard.set(Date(), forKey: Keys.lastUpdateCheck)

        let version = gh.tag_name.hasPrefix("v") ? String(gh.tag_name.dropFirst()) : gh.tag_name
        guard Updater.isNewer(version, than: Updater.currentVersion) else {
            if userInitiated { alert(Text.upToDate.format(Updater.currentVersion)) }
            return
        }
        guard let pkg = gh.assets.first(where: { $0.name.hasSuffix(".pkg") }),
              let sig = gh.assets.first(where: { $0.name == pkg.name + ".sig" })
        else {
            if userInitiated { alert(Text.updateNoInstaller.s) }
            return
        }

        let release = Release(version: version, pkgURL: pkg.browser_download_url,
                              sigURL: sig.browser_download_url, pkgName: pkg.name)
        state = .available(release)

        // Автоперевірка не набридає версією, яку користувач вирішив пропустити.
        if !userInitiated && UserDefaults.standard.string(forKey: Keys.skippedUpdateVersion) == version { return }
        offer(release)
    }

    /// Порівняння версій «1.0.10» > «1.0.9».
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - Пропозиція оновитися

    /// Показати діалог «Доступна версія …». Викликається і з меню.
    func offer(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = Text.updateAvailableTitle.format(release.version)
        alert.informativeText = Text.updateAvailableBody.format(Updater.currentVersion)
        alert.addButton(withTitle: Text.updateInstall.s)
        alert.addButton(withTitle: Text.updateLater.s)
        alert.addButton(withTitle: Text.updateSkip.s)
        NSApp.activate(ignoringOtherApps: true)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            UserDefaults.standard.removeObject(forKey: Keys.skippedUpdateVersion)
            install(release)
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(release.version, forKey: Keys.skippedUpdateVersion)
        default:
            break
        }
    }

    // MARK: - Завантаження й встановлення

    private func install(_ release: Release) {
        state = .downloading

        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("local.screenshoter/Updates", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)   // старі завантаження більше не потрібні
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pkgFile = dir.appendingPathComponent(release.pkgName)

        download(release.sigURL) { [weak self] sigResult in
            guard let self else { return }
            guard case .success(let sigTemp) = sigResult else { return self.downloadFailed(sigResult) }
            self.download(release.pkgURL) { pkgResult in
                // Тимчасові файли прибираємо за будь-якого результату.
                defer {
                    try? FileManager.default.removeItem(at: sigTemp)
                    if case .success(let pkgTemp) = pkgResult { try? FileManager.default.removeItem(at: pkgTemp) }
                }
                guard case .success(let pkgTemp) = pkgResult else { return self.downloadFailed(pkgResult) }
                do {
                    try FileManager.default.moveItem(at: pkgTemp, to: pkgFile)
                    let sigText = try String(contentsOf: sigTemp, encoding: .utf8)
                    guard Updater.verify(file: pkgFile, signatureBase64: sigText) else {
                        try? FileManager.default.removeItem(at: pkgFile)
                        self.state = .available(release)
                        self.alert(Text.updateBadSignature.s)
                        return
                    }
                    self.state = .available(release)
                    // Установщик сам закриє цю програму (preinstall) і запустить нову (postinstall).
                    NSWorkspace.shared.open(pkgFile)
                } catch {
                    self.state = .available(release)
                    self.alert(Text.updateDownloadFailed.format(error.localizedDescription))
                }
            }
        }
    }

    private func download(_ url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.setValue("Screenshoter/\(Updater.currentVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.downloadTask(with: request) { temp, response, error in
            // Тимчасовий файл видаляється після повернення з цього блоку — переносимо його.
            var result: Result<URL, Error>
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let error {
                result = .failure(error)
            } else if let temp, status == 200 {
                let keep = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                do {
                    try FileManager.default.moveItem(at: temp, to: keep)
                    result = .success(keep)
                } catch {
                    result = .failure(error)
                }
            } else {
                result = .failure(NSError(domain: "Screenshoter", code: status,
                                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(status)"]))
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private func downloadFailed(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            alert(Text.updateDownloadFailed.format(error.localizedDescription))
        }
        if case .downloading = state { state = .idle }
    }

    /// Перевірка підпису Ed25519 вшитим публічним ключем.
    static func verify(file: URL, signatureBase64: String) -> Bool {
        guard let keyData = Data(base64Encoded: publicKeyBase64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              let sig = Data(base64Encoded: signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
              let data = try? Data(contentsOf: file)
        else { return false }
        return key.isValidSignature(sig, for: data)
    }

    // MARK: -

    private func alert(_ text: String) {
        let alert = NSAlert()
        alert.messageText = Text.appName.s
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
