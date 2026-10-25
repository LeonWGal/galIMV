# Build the single-file portable EXE

Package a deployed Windows x64 galIMV build, including Qt, into one executable. Users run it directly; the package includes the launcher runtime and requires no Python installation.

## Before you begin

- Build and deploy the native application with CMake and Qt, so the bundle contains `bin/galIMV.exe`, `bin/qt.conf`, `qml`, and `plugins`.
- Install Python and the packaging dependency:

```powershell
python -m pip install pyinstaller
```

## Create the EXE

From the repository root, run:

```powershell
python scripts/build_portable_exe.py --bundle dist --output dist-release --work build-portable-exe
```

The outputs are `dist-release/galIMV-1.2.0-Windows-x64-Portable.exe`, the portable ZIP, and `SHA256SUMS.txt`. `package.bat` uses this packager by default. At launch it extracts the runtime under `%TEMP%/LeonWGal/galIMV`, starts the native Qt application, and waits for it to exit. The bootloader removes its extraction directory after normal exit. Settings keep using `%LOCALAPPDATA%/LeonWGal/galIMV`.

## Verify the package

Run the EXE from a folder containing no Qt DLLs. Confirm that the gallery opens, images load, and the selected accent and language work. Close the window and confirm that the temporary `_MEI` extraction directory has been removed. The portable ZIP remains available for launching without extraction on every run.
