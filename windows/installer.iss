#define MyAppName "Getman"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

[Setup]
AppId={{564AA80D-73A8-4A30-8638-9BDFF5602DD5}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\Getman
DefaultGroupName=Getman
OutputDir=..\build\installer
OutputBaseFilename=getman-{#MyAppVersion}-windows-x64-setup
SetupIconFile=runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
AppMutex=GetmanSingleInstanceMutex
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Getman"; Filename: "{app}\getman.exe"
Name: "{commondesktop}\Getman"; Filename: "{app}\getman.exe"

[Run]
Filename: "{app}\getman.exe"; Description: "Launch Getman"; Flags: nowait postinstall skipifsilent
