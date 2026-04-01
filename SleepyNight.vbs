Option Explicit

Dim shell
Dim fso
Dim rootPath
Dim exePath
Dim command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

rootPath = fso.GetParentFolderName(WScript.ScriptFullName)
exePath = rootPath & "\dist\SleepyNight.Desktop\SleepyNight.Desktop.exe"

If fso.FileExists(exePath) Then
    shell.Run """" & exePath & """", 0, False
Else
    command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & rootPath & "\sleepy-night-ui.ps1"""
    shell.Run command, 0, False
End If
