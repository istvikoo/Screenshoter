#!/bin/zsh
# Публікує новий реліз на GitHub, з якого програми користувачів оновляться самі.
#
#   1. Підніміть VERSION у build.sh і закомітьте зміни.
#   2. ./release.sh                  — опис релізу GitHub складе зі списку комітів
#      ./release.sh notes.md         — або взяти опис з файлу
#
# Скрипт збирає установщик, підписує його ключем оновлень, ставить тег,
# відправляє код і створює реліз з файлами .pkg і .pkg.sig.
set -e
cd "$(dirname "$0")"

REPO="istvikoo/Screenshoter"
VERSION=$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' build.sh)
TAG="v$VERSION"
NOTES_FILE="$1"

fail() { echo "✗ $1" >&2; exit 1; }

# --- Перевірки, перш ніж щось публікувати ---
[[ -n "$VERSION" ]] || fail "Не знайшов VERSION у build.sh"
[[ "$(git branch --show-current)" == "main" ]] || fail "Публікувати треба з гілки main"
git diff --quiet && git diff --cached --quiet || fail "Є незакомічені зміни — спершу закомітьте їх"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && fail "Тег $TAG уже існує — підніміть VERSION у build.sh"
gh auth status >/dev/null 2>&1 || fail "gh не авторизований: gh auth login"
[[ -z "$NOTES_FILE" || -f "$NOTES_FILE" ]] || fail "Немає файлу з описом: $NOTES_FILE"

# Публічний ключ у програмі має відповідати приватному ключу на цьому Mac.
APP_KEY=$(sed -n 's/.*publicKeyBase64 = "\([^"]*\)".*/\1/p' Updater.swift)
MY_KEY=$(swift Tools/updatekey.swift public)
[[ "$APP_KEY" == "$MY_KEY" ]] || fail "Ключ в Updater.swift не збігається з вашим ключем оновлень"

echo "→ Реліз $TAG"

# --- Збірка й підпис ---
./make_installer.sh
PKG="dist/Screenshoter-$VERSION.pkg"
swift Tools/updatekey.swift sign "$PKG" > "$PKG.sig"
swift Tools/updatekey.swift verify "$PKG" "$(cat "$PKG.sig")"
SHA=$(shasum -a 256 "$PKG" | cut -d' ' -f1)

# --- Опис релізу ---
NOTES=$(mktemp)
trap 'rm -f "$NOTES"' EXIT
if [[ -n "$NOTES_FILE" ]]; then
    cat "$NOTES_FILE" > "$NOTES"
else
    PREV=$(git describe --tags --abbrev=0 2>/dev/null || true)
    echo "**Зміни / Changes**" > "$NOTES"
    git log --format='- %s' ${PREV:+$PREV..}HEAD >> "$NOTES"
fi
cat >> "$NOTES" <<EOF

---
Програма, починаючи з 1.1.0, оновиться сама. Або завантажте \`Screenshoter-$VERSION.pkg\` нижче.
Установщик не підписаний Apple Developer ID — якщо macOS не дає відкрити, клікніть правою кнопкою → «Відкрити».

SHA-256 \`Screenshoter-$VERSION.pkg\`: \`$SHA\`
EOF

# --- Публікація ---
git tag -a "$TAG" -m "Screenshoter $VERSION"
git push origin main "$TAG"
gh release create "$TAG" "$PKG" "$PKG.sig" --repo "$REPO" \
    --title "Screenshoter $VERSION" --notes-file "$NOTES" --verify-tag --latest

echo "✓ Опубліковано: https://github.com/$REPO/releases/tag/$TAG"
