#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string>

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    (void)hInstance;
    (void)hPrevInstance;
    (void)lpCmdLine;
    (void)nCmdShow;

    wchar_t exePath[MAX_PATH];
    if (!GetModuleFileNameW(NULL, exePath, MAX_PATH)) {
        return 1;
    }

    // Strip filename to obtain base directory
    wchar_t *p = wcsrchr(exePath, L'\\');
    if (p) *p = L'\0';

    std::wstring binDir = std::wstring(exePath) + L"\\bin";
    std::wstring targetExe = binDir + L"\\galIMV.exe";

    // Build command line: quote executable path and append original command line arguments
    std::wstring cmdLine = L"\"" + targetExe + L"\"";
    LPWSTR pCmd = GetCommandLineW();
    if (pCmd) {
        if (*pCmd == L'\"') {
            pCmd++;
            while (*pCmd && *pCmd != L'\"') pCmd++;
            if (*pCmd == L'\"') pCmd++;
        } else {
            while (*pCmd && *pCmd != L' ') pCmd++;
        }
        while (*pCmd == L' ') pCmd++;
        if (*pCmd) {
            cmdLine += L" ";
            cmdLine += pCmd;
        }
    }

    STARTUPINFOW si;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = (WORD)nCmdShow;

    PROCESS_INFORMATION pi;
    ZeroMemory(&pi, sizeof(pi));

    if (CreateProcessW(
            targetExe.c_str(),
            &cmdLine[0],
            NULL,
            NULL,
            FALSE,
            0,
            NULL,
            binDir.c_str(),
            &si,
            &pi)) {
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        return 0;
    }

    MessageBoxW(NULL, L"Failed to start galIMV.exe from bin directory.", L"galIMV", MB_ICONERROR | MB_OK);
    return 1;
}
