@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo Building galIMV Distribution Packages
echo =======================================================

set "ROOT_DIR=%~dp0"
set "BUILD_DIR=%ROOT_DIR%build-fixed"
set "DIST_DIR=%ROOT_DIR%dist"
set "RELEASE_DIR=%ROOT_DIR%dist-release"
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

echo [4/5] Building single-file portable EXE and ZIP...
python "%ROOT_DIR%scripts\build_portable_exe.py" --bundle "%DIST_DIR%" --output "%RELEASE_DIR%" --work "%ROOT_DIR%build-portable-exe"
if errorlevel 1 (
    echo [ERROR] Portable packaging failed.
    exit /b 1
)

echo [5/5] Portable checksums created by the packager.

echo =======================================================
echo Distribution build complete!
echo Packages located in: %RELEASE_DIR%
echo =======================================================
dir "%RELEASE_DIR%"
