Option Explicit

Dim shell
Dim fso
Dim rootPath
Dim command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

rootPath = fso.GetParentFolderName(WScript.ScriptFullName)
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & rootPath & "\sleepy-night-ui.ps1"""

shell.Run command, 0, False
