#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseX64=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.1 (stable) (might work a few versions back too)
 Author:         AdmiralAlkex (Alexander Samuelsson)

 Script Function:
	Run after compiling. Compresses and uploads archive + cleans folder

#ce ----------------------------------------------------------------------------

#include <Constants.au3>

;Delete old release
FileDelete(@ScriptDir & "\Minecraft Server Periodic Checker.zip")

;Creates and uploads new archive
Local $iPID = Run('"' & @ProgramFilesDir & '\WinRAR\rar.exe" a -x*.png "' & @ScriptDir & '\Minecraft Server Periodic Checker.zip" "Changelog.txt" "Minecraft Server Periodic Checker.exe" "ToDo.txt" "Credits.txt" "TemporaryFiles"', @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
ProcessWaitClose($iPID)
Local $sOutput = StdoutRead($iPID)
ConsoleWrite($sOutput & @LF)