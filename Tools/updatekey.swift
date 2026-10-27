// Ключі підпису оновлень (Ed25519).
//
//   swift Tools/updatekey.swift generate          — створити пару ключів (один раз)
//   swift Tools/updatekey.swift public            — показати публічний ключ
//   swift Tools/updatekey.swift sign <файл>       — надрукувати підпис файлу (base64)
//   swift Tools/updatekey.swift verify <файл> <підпис-base64>
//
// Приватний ключ лежить у ~/.config/screenshoter/update_signing_key — НЕ в репозиторії.
// Зробіть його резервну копію: без нього не вийде випускати оновлення для вже встановлених програм.

import CryptoKit
import Foundation

let keyURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/screenshoter/update_signing_key")

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

func loadKey() -> Curve25519.Signing.PrivateKey {
    guard let text = try? String(contentsOf: keyURL, encoding: .utf8),
          let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw)
    else { fail("Немає приватного ключа: \(keyURL.path). Спершу: swift Tools/updatekey.swift generate") }
    return key
}

func readFile(_ path: String) -> Data {
    guard let data = FileManager.default.contents(atPath: path) else { fail("Не вдалося прочитати \(path)") }
    return data
}

let args = CommandLine.arguments.dropFirst()
switch args.first {
case "generate":
    if FileManager.default.fileExists(atPath: keyURL.path) { fail("Ключ уже існує: \(keyURL.path)") }
    let key = Curve25519.Signing.PrivateKey()
    try! FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                                             attributes: [.posixPermissions: 0o700])
    try! key.rawRepresentation.base64EncodedString().write(to: keyURL, atomically: true, encoding: .utf8)
    try! FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
    print("Приватний ключ: \(keyURL.path)")
    print("Публічний ключ (вставити в Updater.swift): \(key.publicKey.rawRepresentation.base64EncodedString())")
case "public":
    print(loadKey().publicKey.rawRepresentation.base64EncodedString())
case "sign":
    guard args.count == 2 else { fail("Використання: sign <файл>") }
    let sig = try! loadKey().signature(for: readFile(args[args.startIndex + 1]))
    print(sig.base64EncodedString())
case "verify":
    guard args.count == 3, let sig = Data(base64Encoded: args[args.startIndex + 2]) else { fail("Використання: verify <файл> <підпис>") }
    let ok = loadKey().publicKey.isValidSignature(sig, for: readFile(args[args.startIndex + 1]))
    print(ok ? "Підпис правильний" : "Підпис НЕПРАВИЛЬНИЙ")
    exit(ok ? 0 : 1)
default:
    fail("Команди: generate | public | sign <файл> | verify <файл> <підпис>")
}
