# galIMV 1.2.0

Windows x64 release · 2026-10-25

Browse image collections with a unified interface, improved glass surfaces, and complete interface catalogs for 20 languages.

## Downloads

- **galIMV-1.2.0-Windows-x64-Setup.exe** — installs the application and its Qt runtime. Shortcuts and optional image associations are available in the installer.
- **galIMV-1.2.0-Windows-x64-Portable.zip** — extract the whole archive and run `galIMV.exe` in the `galIMV` folder. Keep the `bin`, `qml`, and plugin folders together.
- **SHA256SUMS.txt** — SHA-256 checksums for the downloadable files.

## Added

- Twelve Lobe accents and window/taskbar icons that follow the selected accent.
- Eight linked background pairs, including charcoal/faded paper and pure black/white.
- Shared contour branding and Tabler icons with galIMVmini.

## Changed

- Glass panels have stronger depth, clipped highlights, and visible Aurora in both themes.
- Settings, cache, and temporary data use LeonWGal application folders.
- English and Russian READMEs include interface screenshots and launch instructions.

## Fixed

- Launching the Windows GUI does not open an extra console window.

- All 20 catalogs have matching keys and preserved format parameters.
- File-operation and tag-dictionary errors use the selected interface language.
- Long settings descriptions wrap; material names retain complete tooltips.

## Проверка и запуск

Оба набора CTest и переключение 20 языков проходят. Для установки запустите Setup.exe. Для portable-версии распакуйте ZIP целиком и откройте `galIMV.exe`; Python и Qt устанавливать отдельно не требуется.
