# galIMV (ImageViewer)

<p align="center">
  <strong>High-Performance AI Art Gallery & Deep Metadata Inspector</strong><br>
  <em>Built with C++20, Qt 6.8, and QML featuring Lobe Hub Neo & Aurora Glass styling, multi-threaded thumbnail caching, Danbooru tag search, and 20-language localization.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Language-C%2B%2B20-00599C?style=flat-square&logo=c%2B%2B" alt="C++20"/>
  <img src="https://img.shields.io/badge/Framework-Qt%206.8%20%7C%20QML-41CD52?style=flat-square&logo=qt" alt="Qt 6.8"/>
  <img src="https://img.shields.io/badge/Build-CMake%203.20+-064F8C?style=flat-square&logo=cmake" alt="CMake"/>
  <img src="https://img.shields.io/badge/Design-Lobe%20Neo%20%7C%20Aurora%20Glass-1677ff?style=flat-square" alt="Lobe Neo"/>
  <img src="https://img.shields.io/badge/Languages-20%20Locales-purple?style=flat-square" alt="20 Locales"/>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License MIT"/>
</p>

---

## 🌟 Overview

**galIMV** is a desktop AI gallery and metadata inspector application built for collectors, digital artists, and developers working with generative AI media. Powered by modern C++20 and hardware-accelerated Qt Quick / QML, galIMV smoothly handles massive image folders containing tens of thousands of artworks with zero lag.

---

## ✨ Features

- **🚀 Ultra-Fast C++ Core**: Native multi-threaded thumbnail streaming, asynchronous metadata parsing, and instant memory-mapped cache.
- **🔍 Deep AI Metadata Parsing**:
  - **Automatic1111 / SD.Next / WebUI Forge**: Positive & negative prompts, seed, sampler, steps, CFG, LoRA weights, clip skip, denoise, and model hashes.
  - **ComfyUI**: Parses complex execution graphs, prompt nodes, checkpoints, and latent samplers.
  - **NovelAI & Fooocus**: Complete parameters extraction from PNG text chunks and EXIF user comments.
  - **Midjourney**: Prompt and generation settings parser.
- **🏷️ Danbooru Tag Autocomplete**: Instant search and tag-based filtering powered by pre-indexed tag databases.
- **🎨 Lobe Hub Neo & Aurora Glass UI**: Modern translucent glass cards, dark/light themes, 7 accent palettes, and responsive multi-column grid.
- **🌐 20 Languages (i18n)**: English, Русский, 简体中文, 繁體中文, 日本語, 한국어, Deutsch, Français, Español, Português, Italiano, Polski, Türkçe, Українська, Nederlands, Bahasa Indonesia, Tiếng Việt, ไทย, العربية, and हिन्दी.
- **📦 Windows Packaging**: Ready-to-use Inno Setup installer, standalone portable 7z/zip packages, and lightweight launchers.

---

## 🛠️ Building from Source

### Prerequisites
- **CMake** 3.20 or newer
- **C++20 Compiler**: MinGW-w64 (GCC 13+) or MSVC 2022
- **Qt 6.8+** (with modules: `Core`, `Gui`, `Quick`, `Qml`, `Widgets`, `Svg`, `Concurrent`)
- *(Optional)* **Inno Setup 6** for generating the installer
- *(Optional)* **7-Zip** for creating portable archives

### Build Instructions

```bash
# Clone the repository
git clone https://github.com/your-username/ImageViewer.git
cd ImageViewer

# Configure CMake
cmake -B build -S . -G "Ninja" -DCMAKE_BUILD_TYPE=Release

# Build the project
cmake --build build --config Release

# Install to dist folder
cmake --install build --prefix dist-aurora
```

### Running
Run directly via the included launcher script:
```cmd
run.bat
```

### Creating Release Packages
```cmd
package.bat
```

---

## 📁 Project Structure

```
ImageViewer/
├── CMakeLists.txt              # CMake build configuration
├── package.bat                 # Automated distribution packaging script
├── run.bat                     # Quick launcher
├── src/                        # C++ core source files
│   ├── gallery_model.cpp/h     # Multi-threaded image gallery model
│   ├── metadata_reader.cpp/h   # AI metadata extraction engine
│   ├── tag_autocomplete.cpp/h  # Fast tag lookup & filtering
│   └── main.cpp                # Application entry point
├── qml/                        # Qt Quick / QML user interface
│   └── main.qml                # Unified gallery & inspector UI
├── locales/                    # 20 JSON localization dictionaries
├── resources/                  # Application icons, SVGs, and theme variants
├── installer/                  # Inno Setup packaging script (setup.iss)
├── design/                     # Design mockups, previews, and vector assets
└── tests/                      # C++ unit & regression test suite
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
