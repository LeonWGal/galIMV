"""Launch the native Qt application from a self-contained Windows EXE."""
import ctypes
import os
from pathlib import Path
import subprocess
import sys


def main():
    bundle = Path(sys._MEIPASS)
    executable = bundle / "galIMV" / "bin" / "galIMV.exe"
    if not executable.is_file():
        raise FileNotFoundError("The bundled galIMV executable is missing.")
    environment = os.environ.copy()
    # The bootloader extracts under TEMP/LeonWGal/galIMV. The native app uses
    # that same directory for temporary files, avoiding a duplicated suffix.
    environment["TEMP"] = str(bundle.parent)
    environment["TMP"] = str(bundle.parent)
    # PyInstaller's Python DLL search directory must not affect native Qt.
    ctypes.windll.kernel32.SetDllDirectoryW(None)
    process = subprocess.Popen([str(executable), *sys.argv[1:]],
                               cwd=executable.parent, env=environment)
    return process.wait()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        ctypes.windll.user32.MessageBoxW(None, str(error), "galIMV", 0x10)
        sys.exit(1)
