@echo off
setlocal
set "VIEWER=%~dp0dist\bin\galIMV.exe"
if exist "%~dp0dist-aurora\bin\galIMV.exe" set "VIEWER=%~dp0dist-aurora\bin\galIMV.exe"
if not exist "%VIEWER%" (
    echo Build and install the app first:
    echo cmake --install "%~dp0build-fixed" --prefix "%~dp0dist-aurora"
    pause
    exit /b 1
)
start "" "%VIEWER%"
