; Script generated for galIMV Windows Installer
#define MyAppName "galIMV"
#define MyAppVersion "1.2.0"
#define MyAppPublisher "LeonWGal"
#define MyAppExeName "galIMV.exe"
#define MyLauncherName "galIMV.exe"
#ifndef MyAppRoot
#define MyAppRoot ".."
#endif
#ifndef MyDistDir
#define MyDistDir MyAppRoot + "\dist"
#endif
#ifndef MyOutputDir
#define MyOutputDir MyAppRoot + "\dist-release"
#endif

[Setup]
AppId={{C682A3A1-7EB9-4F54-9E67-0245C4B4E87A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir={#MyOutputDir}
OutputBaseFilename=galIMV-{#MyAppVersion}-Windows-x64-Setup
SetupIconFile={#MyAppRoot}\resources\app.ico
UninstallDisplayIcon={app}\bin\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog commandline
ChangesAssociations=yes
DisableProgramGroupPage=auto

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[CustomMessages]
english.CreateDesktopIcon=Create a &desktop shortcut
russian.CreateDesktopIcon=Создать значок на &Рабочем столе
english.AssociateImages=Associate galIMV with common image files (.png, .jpg, .webp)
russian.AssociateImages=Ассоциировать galIMV с изображениями (.png, .jpg, .webp)
english.OtherTasks=Other tasks:
russian.OtherTasks=Другие задачи:

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "associate_images"; Description: "{cm:AssociateImages}"; GroupDescription: "{cm:OtherTasks}"; Flags: unchecked

[Files]
Source: "{#MyDistDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\bin\{#MyAppExeName}"; WorkingDir: "{app}\bin"; IconFilename: "{app}\bin\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\bin\{#MyAppExeName}"; WorkingDir: "{app}\bin"; IconFilename: "{app}\bin\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; File association for .png
Root: HKA; Subkey: "Software\Classes\.png\OpenWithProgids"; ValueType: string; ValueName: "galIMV.Image"; Flags: uninsdeletevalue; Tasks: associate_images
; File association for .jpg
Root: HKA; Subkey: "Software\Classes\.jpg\OpenWithProgids"; ValueType: string; ValueName: "galIMV.Image"; Flags: uninsdeletevalue; Tasks: associate_images
; File association for .jpeg
Root: HKA; Subkey: "Software\Classes\.jpeg\OpenWithProgids"; ValueType: string; ValueName: "galIMV.Image"; Flags: uninsdeletevalue; Tasks: associate_images
; File association for .webp
Root: HKA; Subkey: "Software\Classes\.webp\OpenWithProgids"; ValueType: string; ValueName: "galIMV.Image"; Flags: uninsdeletevalue; Tasks: associate_images

; ProgID configuration
Root: HKA; Subkey: "Software\Classes\galIMV.Image"; ValueType: string; ValueName: ""; ValueData: "galIMV Image"; Flags: uninsdeletekey; Tasks: associate_images
Root: HKA; Subkey: "Software\Classes\galIMV.Image\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\bin\{#MyAppExeName},0"; Tasks: associate_images
Root: HKA; Subkey: "Software\Classes\galIMV.Image\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\bin\{#MyAppExeName}"" ""%1"""; Tasks: associate_images

[Run]
Filename: "{app}\bin\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent; WorkingDir: "{app}\bin"
