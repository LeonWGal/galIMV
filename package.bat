@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo Building galIMV Distribution Packages
echo =======================================================

set "ROOT_DIR=%~dp0"
set "BUILD_DIR=%ROOT_DIR%build-fixed"
set "DIST_DIR=%ROOT_DIR%dist"
set "RELEASE_DIR=%ROOT_DIR%dist-release"
set "ISCC=C:\Users\User\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
set "SEVENZIP=C:\Program Files\7-Zip\7z.exe"
set "PATH=C:\Users\User\Qt\6.8.0\mingw_64\bin;C:\Users\User\Qt\Tools\mingw1310_64\bin;%PATH%"

echo [1/5] Building project binaries (Release)...
cmake --build "%BUILD_DIR%" --config Release
if errorlevel 1 (
    echo [ERROR] Build failed.
    exit /b 1
)

echo [2/5] Installing and deploying Qt runtime to dist/...
cmake --install "%BUILD_DIR%" --prefix "%DIST_DIR%"
if errorlevel 1 (
    echo [ERROR] CMake install failed.
    exit /b 1
)

echo [3/5] Building root launcher...
windres -i "%ROOT_DIR%resources\app.rc" -o "%ROOT_DIR%resources\launcher_rc.o" --include-dir "%ROOT_DIR%resources"
g++ -O2 -mwindows -s -static "%ROOT_DIR%src\launcher.cpp" "%ROOT_DIR%resources\launcher_rc.o" -o "%DIST_DIR%\galIMV.exe"
del "%ROOT_DIR%resources\launcher_rc.o" 2>nul

echo [4/5] Compiling Inno Setup installer...
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"
if exist "%ISCC%" (
    "%ISCC%" "%ROOT_DIR%installer\setup.iss"
) else (
    echo [WARNING] ISCC.exe not found at %ISCC%
)

echo [5/5] Creating Portable ZIP and 7Z archives...
if exist "%SEVENZIP%" (
    if exist "%ROOT_DIR%dist-portable" rmdir /s /q "%ROOT_DIR%dist-portable"
    mkdir "%ROOT_DIR%dist-portable\galIMV"
    xcopy /e /i /y "%DIST_DIR%\*" "%ROOT_DIR%dist-portable\galIMV\" >nul
    "%SEVENZIP%" a -tzip -mx=9 -y "%RELEASE_DIR%\galIMV-1.2.0-Portable.zip" "%ROOT_DIR%dist-portable\galIMV" >nul
    "%SEVENZIP%" a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -y "%RELEASE_DIR%\galIMV-1.2.0-Portable.7z" "%ROOT_DIR%dist-portable\galIMV" >nul
    rmdir /s /q "%ROOT_DIR%dist-portable"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT_DIR%scripts\generate_hashes.ps1" -ReleaseDir "%RELEASE_DIR%"

echo =======================================================
echo Distribution build complete!
echo Packages located in: %RELEASE_DIR%
echo =======================================================
dir "%RELEASE_DIR%"
