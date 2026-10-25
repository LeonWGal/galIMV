"""Package an already deployed native Qt build as one Windows GUI EXE."""
from pathlib import Path
import argparse
import hashlib
import zipfile
import importlib.util
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True,
                        help="Deployed directory containing bin/galIMV.exe and Qt")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--exe-only", action="store_true",
                        help="Preserve an existing portable ZIP while rebuilding the EXE")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    bundle = args.bundle.resolve()
    for relative in ("bin/galIMV.exe", "bin/qt.conf", "plugins/platforms/qwindows.dll"):
        if not (bundle / relative).is_file():
            parser.error("Incomplete Qt deployment: " + relative)
    if importlib.util.find_spec("PyInstaller") is None:
        parser.error("Install the packaging dependency: python -m pip install pyinstaller")
    project = (root / "CMakeLists.txt").read_text(encoding="utf-8")
    version = re.search(r"project\(galIMV VERSION ([0-9.]+)", project).group(1)
    parts = tuple(int(value) for value in version.split(".")) + (0,)
    work = args.work.resolve()
    work.mkdir(parents=True, exist_ok=True)
    metadata = work / "version_info.txt"
    metadata.write_text("VSVersionInfo(ffi=FixedFileInfo(filevers=" + repr(parts) +
        ", prodvers=" + repr(parts) + ", mask=0x3f, flags=0, OS=0x40004, "
        "fileType=1, subtype=0, date=(0,0)), kids=[StringFileInfo([StringTable("
        "'040904B0', [StringStruct('CompanyName','LeonWGal'), "
        "StringStruct('FileDescription','galIMV Portable'), "
        "StringStruct('ProductName','galIMV'), StringStruct('FileVersion','" + version +
        "'), StringStruct('ProductVersion','" + version + "')])]), "
        "VarFileInfo([VarStruct('Translation',[1033,1200])])])", encoding="utf-8")
    command = [sys.executable, "-m", "PyInstaller", "--noconfirm", "--clean",
        "--onefile", "--windowed", "--name=galIMV-" + version + "-Windows-x64-Portable",
        "--distpath=" + str(args.output.resolve()), "--workpath=" + str(work / "build"),
        "--specpath=" + str(work / "spec"), "--version-file=" + str(metadata),
        "--icon=" + str(root / "resources/app.ico"),
        "--runtime-tmpdir=%TEMP%/LeonWGal/galIMV",
        "--add-data=" + str(bundle) + ";galIMV", str(root / "src/portable_launcher.py")]
    result = subprocess.run(command).returncode
    if result:
        return result
    output = args.output.resolve()
    name = "galIMV-" + version + "-Windows-x64-Portable"
    archive_path = output / (name + ".zip")
    if not args.exe_only:
        with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED, compresslevel=7) as archive:
            for path in sorted(bundle.rglob("*")):
                if path.is_file():
                    archive.write(path, Path("galIMV") / path.relative_to(bundle))
    checksums = []
    for path in (output / (name + ".exe"), archive_path):
        if not path.is_file():
            continue
        checksums.append(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + path.name)
    (output / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n", encoding="ascii")
    return 0


if __name__ == "__main__":
    sys.exit(main())
