#define AppName "顶栖（TopNest）"
#define AppVersion "1.0.0"
#define AppExeName "TopNest.exe"

[Setup]
AppId={{D08F1E7B-3C85-48E5-97A7-44E51D71C988}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\TopNest
DefaultGroupName={#AppName}
OutputDir=..\dist
OutputBaseFilename=TopNest-Setup-{#AppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
PrivilegesRequired=lowest

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标："

[Run]
Filename: "{app}\{#AppExeName}"; Description: "启动{#AppName}"; Flags: nowait postinstall skipifsilent
