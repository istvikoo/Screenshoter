<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="Screenshoter icon">
</p>

<h1 align="center">Screenshoter</h1>

<p align="center">
  Легкий скріншотер для macOS: гаряча клавіша → знімок одразу в буфер обміну.<br>
  <a href="#english">English below</a>
</p>

## Можливості

- **⌥⇧S** — виділити область мишкою (Пробіл — вибрати вікно, Esc — скасувати)
- **⌥⇧A** — весь екран
- Знімок одразу в буфері обміну — просто **⌘V** куди завгодно, без файлів на диску
- За бажанням — ще й зберігати кожен знімок PNG-файлом у вибрану папку (вмикається в налаштуваннях)
- Свої комбінації клавіш у налаштуваннях
- Мова інтерфейсу: українська / English
- Можна сховати іконку з рядка меню
- За бажанням — лівий клік по іконці одразу знімає область, а меню відкривається правим кліком (вмикається в налаштуваннях)
- Автозапуск при вході в систему (вмикається сам при першому запуску, вимкнути — в налаштуваннях)
- Автооновлення з GitHub з перевіркою цифрового підпису (з версії 1.1.0)
- Займає ~12 МБ пам'яті у фоні, 0% процесора; програма — ~440 КБ
- Універсальна програма: Apple Silicon та Intel

## Встановлення

1. Завантажте `Screenshoter-<версія>.pkg` зі сторінки [Releases](https://github.com/istvikoo/Screenshoter/releases).
2. Відкрийте його й натисніть «Встановити» — програма з'явиться в «Програмах» і запуститься.
3. При першому знімку дозвольте **запис екрана**: Системні параметри → Конфіденційність і безпека → Запис екрана.

> Установщик не підписаний сертифікатом Apple Developer. Якщо macOS не дає його відкрити —
> клікніть правою кнопкою → «Відкрити» або дозвольте в «Конфіденційність і безпека».

Налаштування відкриваються з меню іконки камери або повторним запуском `Screenshoter.app`
(зручно, коли іконку сховано).

## Збірка з коду

Потрібні macOS 13+ та Xcode або Command Line Tools (`xcode-select --install`).

```bash
./build.sh              # зібрати Screenshoter.app
./build.sh install      # зібрати й встановити в /Applications
./make_installer.sh     # зібрати установщик dist/Screenshoter-<версія>.pkg
./release.sh            # опублікувати реліз на GitHub (див. нижче)
```

Версія задається в `build.sh` (`VERSION=...`). Іконка — `Resources/AppIcon.png`,
після її зміни запустіть `./Resources/make_icon.sh`.

## Оновлення

Програма раз на добу (або через «Перевірити оновлення…» в меню) питає GitHub про останній реліз.
Якщо є новіша версія, вона завантажує `Screenshoter-<версія>.pkg` і `.pkg.sig`, перевіряє підпис
**Ed25519** вшитим публічним ключем і лише тоді відкриває установщик. Файл з неправильним підписом
відкидається. Автоперевірку можна вимкнути в налаштуваннях.

**Як випустити нову версію:**

1. Підніміть `VERSION` у `build.sh` і закомітьте зміни.
2. Запустіть `./release.sh` (або `./release.sh notes.md` зі своїм описом).
   Скрипт збере установщик, підпише його, поставить тег і створить реліз на GitHub.

Приватний ключ підпису лежить у `~/.config/screenshoter/update_signing_key` і **не** зберігається
в репозиторії (`swift Tools/updatekey.swift` — створити, підписати, перевірити).
Зробіть його резервну копію: без нього не вийде випустити оновлення для вже встановлених програм.

## Як це працює

- Гарячі клавіші реєструються через Carbon `RegisterEventHotKey` — дозвіл «Універсальний доступ» не потрібен.
- Знімок робить системна утиліта `screencapture -c` (одразу в буфер).
- Автозапуск — через `SMAppService` (Об'єкти входу).
- Оновлення — GitHub Releases API + підпис Ed25519 (CryptoKit).

| Файл | Що в ньому |
|---|---|
| `main.swift` | меню в рядку меню, знімок |
| `Shortcuts.swift` | комбінації клавіш: збереження, назви, реєстрація |
| `SettingsWindow.swift` | вікно налаштувань |
| `Preferences.swift` | налаштування (усі ключі в одному місці) й автозапуск |
| `Localization.swift` | переклади українською та англійською |
| `ScreenshotSaver.swift` | збереження знімків у папку |
| `Updater.swift` | перевірка, завантаження й перевірка підпису оновлень |
| `Tools/updatekey.swift` | ключі підпису оновлень |
| `release.sh` | публікація релізу на GitHub |
| `Installer/` | скрипти й екран привітання установщика |

---

<a name="english"></a>

## English

A lightweight macOS screenshot tool: press a hotkey and the screenshot goes straight to the clipboard.
It lives in the menu bar, takes no space in the Dock and does nothing in the background until you need it.

### Features

- **⌥⇧S**: select an area with the mouse (Space picks a window, Esc cancels)
- **⌥⇧A**: capture the full screen
- The screenshot lands in the clipboard. Just press **⌘V** anywhere, no files left on disk
- Optionally also save every screenshot as a PNG to a folder of your choice (off by default)
- Set your own shortcuts in Settings
- Interface in Ukrainian or English (follows the system language until you pick one)
- Hide the menu bar icon if you want; the shortcuts keep working
- Optionally make a left click on the icon capture an area right away, with the menu on right-click (off by default)
- Launch at login, enabled automatically on first launch and easy to turn off in Settings
- Auto-update from GitHub with digital signature verification (since 1.1.0)
- About 12 MB of RAM and 0% CPU when idle; the app itself is about 440 KB
- Universal app: Apple Silicon and Intel, macOS 13 or later

### Installation

1. Download `Screenshoter-<version>.pkg` from the [Releases](https://github.com/istvikoo/Screenshoter/releases) page.
2. Open it and click **Install**. The app is installed to Applications and launched; its icon appears in the menu bar.
3. On the first capture, allow **Screen Recording**:
   System Settings → Privacy & Security → Screen & System Audio Recording.

> The installer is not signed with an Apple Developer ID. If macOS refuses to open it,
> right-click it → **Open**, or allow it in **Privacy & Security**.

**Upgrading from 1.0:** version 1.0 was identified by macOS by its build hash, so the Screen Recording
permission didn't survive an update. After installing a newer version, remove Screenshoter from the
Screen Recording list (the **−** button) or run `tccutil reset ScreenCapture local.screenshoter`,
then allow it again on the next capture. This is needed only once.

### Usage

| Action | Default shortcut |
|---|---|
| Capture an area | **⌥⇧S**, then drag with the mouse. **Space** switches to window mode, **Esc** cancels |
| Capture the full screen | **⌥⇧A** |
| Paste the screenshot | **⌘V** in any app |

The menu bar icon briefly turns into a checkmark when the screenshot is in the clipboard.
A cancelled capture (Esc) doesn't change the clipboard and isn't saved.

**Settings** open from the camera icon's menu → *Settings…* (⌘,), or by launching `Screenshoter.app`
again while it's running (handy when the icon is hidden). There you can:

- **Change the language** (Українська / English). The change applies immediately.
- **Assign shortcuts.** Click a field and press a new combination. Esc cancels, ⌫ clears it.
  A shortcut needs at least one modifier (⌘ ⌥ ⌃ ⇧); only F1–F20 work on their own.
  You'll get a warning if the combination is already used by the other action or taken by another app.
- **Show or hide the menu bar icon.** While it's hidden, shortcuts still work and the *Quit*
  button is available in Settings.
- **Left-click the icon to capture an area.** Off by default. When it's on, a left click starts the
  area selection right away, and the menu opens with a right-click or ⌃-click. Hovering the icon
  shows a reminder.
- **Launch at login.** If macOS asks for approval, Settings shows a button that opens Login Items.
- **Also save screenshots to a folder.** The default is `~/Pictures/Screenshoter`; pick another one
  with *Choose…*. Files are named `Screenshoter 2026-10-27 17-45-12.png` and never overwrite each
  other. The menu then also shows *Open Screenshots Folder*.
- **Check for updates automatically**, see the current version, or *Check Now*.
- **Reset to Defaults** restores the default shortcuts.

**Choosing shortcuts.** Few two-key combinations on macOS are truly free. Good options are
**fn+F5 / fn+F6** (or F13–F19 on an external keyboard), **⌥`** and **⌃`** (the latter opens the
terminal in VS Code). Avoid ⌘+letter and **⌘`** (macOS uses it to cycle an app's windows),
⌥+letter (types special characters) and ⌃+letter (cursor movement in text fields and Terminal).

### Updates

Once a day (or via *Check for Updates…* in the menu), the app asks GitHub for the latest release.
If a newer version exists, it offers **Update**, **Later** or **Skip This Version**. On *Update* it
downloads `Screenshoter-<version>.pkg` together with `.pkg.sig`, verifies the **Ed25519** signature
with the public key built into the app, and only then opens the standard installer (you'll be asked
for your password). A file with a wrong signature is deleted and never installed.

A failed check (for example, no internet) is retried an hour later. Automatic checks can be turned
off in Settings.

### Building from source

Requires macOS 13+ and Xcode or the Command Line Tools (`xcode-select --install`).

```bash
./build.sh              # build Screenshoter.app
./build.sh install      # build and install to /Applications
./make_installer.sh     # build the installer dist/Screenshoter-<version>.pkg
./release.sh            # publish a release on GitHub (see below)
```

The build is universal (arm64 and x86_64 compiled in parallel), size-optimized (`-Osize -wmo`,
`dead_strip`, `strip -x`) and ad-hoc signed with the requirement `identifier "local.screenshoter"`,
so the Screen Recording permission survives rebuilds and updates.

The version is set in `build.sh` (`VERSION=...`). The icon is `Resources/AppIcon.png`;
after changing it, run `./Resources/make_icon.sh`.

### Publishing a new version

1. Bump `VERSION` in `build.sh` and commit your changes.
2. Run `./release.sh` (or `./release.sh notes.md` to use your own release notes).
   The script checks that everything is committed and the tag is new, builds the installer,
   signs it, creates the tag, pushes and publishes the GitHub release with `.pkg` and `.pkg.sig`.

The private signing key lives in `~/.config/screenshoter/update_signing_key` and is **not** stored
in the repository. `swift Tools/updatekey.swift` can generate a key, sign and verify files.
**Back it up:** without it, already installed copies can't accept any further updates.

### How it works

- Hotkeys are registered with Carbon `RegisterEventHotKey`, so no Accessibility permission is needed.
- Screenshots are taken by the system `screencapture -c` utility, straight to the clipboard.
- Saving to a folder writes the clipboard image as PNG on a background thread.
- Launch at login uses `SMAppService` (Login Items).
- Updates use the GitHub Releases API plus an Ed25519 signature (CryptoKit).

| File | Contents |
|---|---|
| `main.swift` | menu bar menu, capturing |
| `Shortcuts.swift` | shortcuts: storage, key names, registration |
| `SettingsWindow.swift` | the Settings window |
| `Preferences.swift` | settings (all keys in one place) and launch at login |
| `Localization.swift` | Ukrainian and English strings |
| `ScreenshotSaver.swift` | saving screenshots to a folder |
| `Updater.swift` | checking, downloading and verifying updates |
| `Tools/updatekey.swift` | update signing keys |
| `release.sh` | publishing a GitHub release |
| `Installer/` | installer scripts and welcome screen |

## License

[MIT](LICENSE)
