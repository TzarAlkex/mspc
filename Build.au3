#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseX64=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.1 (stable) (might work a few versions back too)
 Author:         AdmiralAlkex (Alexander Samuelsson)

 Script Function:
	Run after compiling. Compresses and uploads archive + cleans folder

#ce ----------------------------------------------------------------------------

;Delete old release
FileDelete(@UserProfileDir & "\Dropbox\Public\SoftwareUpdates\Minecraft Server Periodic Checker.zip")

;Creates and uploads new archive
RunWait('"' & @ProgramFilesDir & '\WinRAR\rar.exe" a "' & @UserProfileDir & '\Dropbox\Public\SoftwareUpdates\Minecraft Server Periodic Checker.zip" "Changelog.txt" "Minecraft Server Periodic Checker.exe" "ToDo.txt" "ReadMe.txt" "TemporaryFiles" "PleaseWait.png" "Error.png" "Default3.png"', @ScriptDir)

;Clean folder
FileDelete(@ScriptDir & "\Minecraft Server Periodic Checker.au3.tmp")
FileDelete(@ScriptDir & "\Minecraft Server Periodic Checker_Obfuscated.au3")
FileDelete(@ScriptDir & "\Minecraft Server Periodic Checker.exe")