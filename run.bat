@echo off
setlocal
set "VIEWER=%~dp0dist\bin\ImageViewer.exe"
if exist "%~dp0dist-ui\bin\ImageViewer.exe" set "VIEWER=%~dp0dist-ui\bin\ImageViewer.exe"
if exist "%~dp0dist-aurora\bin\ImageViewer.exe" set "VIEWER=%~dp0dist-aurora\bin\ImageViewer.exe"
if not exist "%VIEWER%" (
    echo Build and install the app first:
    echo cmake --install "%~dp0build-fixed" --prefix "%~dp0dist-aurora"
    pause
    exit /b 1
)
start "" "%VIEWER%"
