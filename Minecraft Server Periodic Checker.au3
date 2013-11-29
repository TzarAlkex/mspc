#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Comment=Minecraft? More like Mecraft!
#AutoIt3Wrapper_Res_Description=Alert user when his favorite Minecraft server goes online
#AutoIt3Wrapper_Res_Fileversion=0.0.0.17
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Run_Obfuscator=y
#Obfuscator_Parameters=/sf /sv /om /cs=0 /cn=0
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#Obfuscator_Ignore_Funcs=_ServerResults, _ServerFinished

#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.9.22 (beta)
 Author:         AdmiralAlkex (Alexander Samuelsson)

 Script Function:
	Alert user when his favorite Minecraft server goes online

#ce ----------------------------------------------------------------------------

#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiEdit.au3>
#include <StaticConstants.au3>
#include <GuiListView.au3>
#include <ComboConstants.au3>
#include <Array.au3>
#include "AutoitObject.au3"
#include <GDIPlus.au3>
#include <WinAPI.au3>
#include <GuiButton.au3>
#include <Constants.au3>
#include <GuiComboBoxEx.au3>
#include "JSMN.au3"
#include <GuiImageList.au3>
#include "Icons.au3"

Opt("TrayAutoPause", 0)
Opt("TrayIconDebug", 1)
Opt("GUIResizeMode", $GUI_DOCKALL)

Global $sMyCLSID = "AutoIt.ServerChecker"

Global $oError = ObjEvent("AutoIt.Error", "_ErrFunc")
Func _ErrFunc()
	ConsoleWrite("COM Error, ScriptLine(" & $oError.scriptline & ") : Number 0x" & Hex($oError.number, 8) & " - " & $oError.windescription & @CRLF)
	Exit
EndFunc

If $CmdLine[0] > 1 And $CmdLine[1] = "/ServerScanner" Then
	_ServerScanner()
EndIf


_GDIPlus_Startup()

Global $hBitmap, $hImage, $hGraphic
$hBitmap = _WinAPI_CreateSolidBitmap(0, 0xFFFFFF, 16, 16)
$hImage = _GDIPlus_BitmapCreateFromHBITMAP($hBitmap)
$hGraphic = _GDIPlus_ImageGetGraphicsContext($hImage)

Global Const $tagNOTIFYICONDATA = "dword Size;" & _
        "hwnd Wnd;" & _
        "uint ID;" & _
        "uint Flags;" & _
        "uint CallbackMessage;" & _
        "ptr Icon;" & _
        "wchar Tip[128];" & _
        "dword State;" & _
        "dword StateMask;" & _
        "wchar Info[256];" & _
        "uint Timeout;" & _
        "wchar InfoTitle[64];" & _
        "dword InfoFlags;" & _
        "dword Data1;word Data2;word Data3;byte Data4[8];" & _
        "ptr BalloonIcon"

Global Const $NIM_ADD = 0
Global Const $NIM_MODIFY = 1

Global Const $NIF_MESSAGE = 1
Global Const $NIF_ICON = 2

Global Const $AUT_WM_NOTIFYICON = $WM_USER + 1 ; Application.h
Global Const $AUT_NOTIFY_ICON_ID = 1 ; Application.h

AutoItWinSetTitle("AutoIt window with hopefully a unique title|Ketchup")
Global $TRAY_ICON_GUI = WinGetHandle(AutoItWinGetTitle()) ; Internal AutoIt GUI


Global $iDefaultPort = 25565, $iPid, $iServerCount = 0, $iServerTray = ChrW(8734), $sUpdateLink, $avPopups[1][5], $asServerPlayers[1][3], $iListviewFlag = False, $iListviewIndex, $iSkipLabelProc = False

Local $iGuiX = 832, $iGuiY = 480

$hGui = GUICreate(StringTrimRight(@ScriptName, 4), $iGuiX, $iGuiY, -1, -1)

Local $aiGuiMin = WinGetPos($hGui)

GUICtrlCreateGroup("Add server", 5, 5, 375, 70)
$idIP = GUICtrlCreateInput("", 20, 30, 200, 25)
GUICtrlSendMsg($idIP, $EM_SETCUEBANNER, True, "Server Address")
$idPort = GUICtrlCreateInput("", 230, 30, 80, 25, BitOR($GUI_SS_DEFAULT_INPUT, $ES_NUMBER))
GUICtrlSendMsg($idPort, $EM_SETCUEBANNER, True, "Server Port")
GUICtrlSetTip(-1, "If leaved empty, the default Minecraft port (25565) will be used")
$idAdd = GUICtrlCreateButton("Add", 320, 30, 50, 25)

GUICtrlCreateGroup("Scan/Timeout (in seconds)", 390, 5, 235, 70)
$idScanNow = GUICtrlCreateButton("Scan now", 400, 30, 150, 25)

$cIdTimeout = GUICtrlCreateCombo("", 560, 30, 50, 25)
Global $hTimeout = GUICtrlGetHandle(-1)
$iTimeoutSeconds = Int(IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "TimeoutSeconds", "HamburgareIsTasty"))
If $iTimeoutSeconds Then
	GUICtrlSetData(-1, $iTimeoutSeconds, $iTimeoutSeconds)
Else
	GUICtrlSetData(-1, 10, 10)
EndIf


$idServers = GUICtrlCreateListView("Server Address|Server Port|Version|Current/Max Players|MOTD", 5, 80, 630, $iGuiY - 195, $LVS_SHOWSELALWAYS, BitOR($LVS_EX_CHECKBOXES, $LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_INFOTIP))
$idServerContext = GUICtrlCreateContextMenu($idServers)
$idServerDelete = GUICtrlCreateMenuItem("Delete selected server(s)", $idServerContext)
$idServerShowPopup = GUICtrlCreateMenuItem("Show server bar", $idServerContext)

_IniClean()
$asServers = IniReadSectionNames(@ScriptDir & "\Servers.ini")
If Not @error Then
	For $iX = 1 To $asServers[0]
		$asPorts = IniReadSection(@ScriptDir & "\Servers.ini", $asServers[$iX])
		If @error Then ContinueLoop
		For $iY = 1 To $asPorts[0][0]
			GUICtrlCreateListViewItem($asServers[$iX] & "|" & $asPorts[$iY][0], $idServers)
			GUICtrlSetBkColor(-1, 0xFFFFFF)
			GUICtrlSetColor(-1, 0)
			If $asPorts[$iY][1] = "True" Or $asPorts[$iY][1] = "Old" Or $asPorts[$iY][1] = "New" Then _GUICtrlListView_SetItemChecked($idServers, _GUICtrlListView_GetItemCount($idServers) -1)
		Next
		_GUICtrlListView_SetColumnWidth($idServers, 0, $LVSCW_AUTOSIZE)
		_GUICtrlListView_SetColumnWidth($idServers, 1, $LVSCW_AUTOSIZE_USEHEADER)
	Next
EndIf

Local $sSecondsBetweenScans
Local $sMinutesBetweenScans = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "MinutesBetweenScans", "IsglassIsTasty")
If $sMinutesBetweenScans <> "IsglassIsTasty" Then
	$sSecondsBetweenScans = $sMinutesBetweenScans * 60
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "SecondsBetweenScans", $sSecondsBetweenScans)
	IniDelete(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "MinutesBetweenScans")
EndIf

GUICtrlCreateGroup("Settings", 5, $iGuiY - 110, 630, 65)
GUICtrlCreateLabel("Seconds between scans=", 20, $iGuiY - 95, 150, 20)
$idSeconds = GUICtrlCreateCombo("", 180, $iGuiY - 95, 50, 25)
If $sSecondsBetweenScans = "" Then
	$sSecondsBetweenScans = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "SecondsBetweenScans", "PyttipannaIsTasty")
EndIf
Local $sCombo = "60|180|300|"
If $sSecondsBetweenScans <> "PyttipannaIsTasty" Then
	If StringInStr($sCombo, $sSecondsBetweenScans & "|") = 0 Then
		$sCombo &= $sSecondsBetweenScans & "|"
	EndIf
	GUICtrlSetData(-1, $sCombo, $sSecondsBetweenScans)
Else
	GUICtrlSetData(-1, $sCombo, 1)
EndIf
GUICtrlCreateLabel("(you can type your own value)", 240, $iGuiY - 95, 150, 20)

Local $idColorizeListview = GUICtrlCreateCheckbox("Colorize listview (green = success, red = fail)", 400, $iGuiY - 95, 230, 20)
Global $hColorizeListview = GUICtrlGetHandle(-1)
Local $sColorizeListview = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "ColorizeListview", "MatIsTasty")
If $sColorizeListview = "1" Or $sColorizeListview = "MatIsTasty" Then GUICtrlSetState(-1, $GUI_CHECKED)

$idFlashWin = GUICtrlCreateCheckbox("Flash window when server goes online", 20, $iGuiY - 75, 210, 20)
Local $sFlashWindow = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "FlashWindow", "PizzaIsTasty")
If $sFlashWindow = "1" Or $sFlashWindow = "PizzaIsTasty" Then GUICtrlSetState(-1, $GUI_CHECKED)

Local $idCountTray = GUICtrlCreateCheckbox("Count in tray icon", 240, $iGuiY - 75, 150, 20)
Global $hCountTray = GUICtrlGetHandle(-1)
Local $sCountTray = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "CountTray", "JulmustIsTasty")
If $sCountTray = "1" Or $sCountTray = "JulmustIsTasty" Then
	GUICtrlSetState(-1, $GUI_CHECKED)
	Opt("TrayIconHide", 0)
	_TraySet($iServerTray)
EndIf

Local $idCheckForUpdate = GUICtrlCreateCheckbox("Check if a newer version is available at start", 400, $iGuiY - 75, 230, 20)
Global $idUpdateLabel = -1
Local $sCheckForUpdate = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "CheckForUpdate", "K" & Chr(246) & "ttbullarIsTasty")
If $sCheckForUpdate = "1" Or $sCheckForUpdate = "K" & Chr(246) & "ttbullarIsTasty" Then
	GUICtrlSetState(-1, $GUI_CHECKED)
	$idUpdateLabel = GUICtrlCreateLabel("Checking for update", 210, $iGuiY - 30, 220, 25, $SS_CENTER)
	Global $aInet = InetGet("https://dl.dropbox.com/u/18344147/SoftwareUpdates/MSPC.txt", @TempDir & "\MSPC.txt", 1 + 2 + 16, 1)
	AdlibRegister("_CheckForUpdate", 100)
EndIf

GUICtrlCreateLabel("Tip 1: Check items to include in scan", 5, $iGuiY - 30, 200, 25)
GUICtrlCreateLabel("Tip 2: Rightclick item to delete and stuff", 435, $iGuiY - 30, 200, 25, $SS_RIGHT)

$idPopupDummy = GUICtrlCreateDummy()


GUICtrlCreateGroup("More info", 645, 5, 177, $iGuiY - 15)

$idServerImage = GUICtrlCreatePic(@ScriptDir & "\Emma Watson.jpg", 655, 25, 64, 64)

$idServerProtocol = GUICtrlCreateLabel("Protocol= to be implemented", 655, 95, $iGuiX - 670, 25, $SS_CENTERIMAGE)

$idServerPlayers = GUICtrlCreateListView("Name", 655, 125, $iGuiX - 675, $iGuiY - 145, $LVS_SHOWSELALWAYS, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES))
Local $idServerPlayersImageList = _GUIImageList_Create(32, 32)
Global $iListNew = _ImageList_AddImage($idServerPlayersImageList, @ScriptDir & "\PleaseWait.png")
Global $iListError = _ImageList_AddImage($idServerPlayersImageList, @ScriptDir & "\Error.png")
_GUICtrlListView_SetImageList($idServerPlayers, $idServerPlayersImageList, 0)
_GUICtrlListView_SetView($idServerPlayers, 1)


WinMove($hGui, "", $aiGuiMin[0], $aiGuiMin[1], $aiGuiMin[2] -187, $aiGuiMin[3])

GUISetState()
GUIRegisterMsg($WM_NOTIFY, "_WM_NOTIFY")
GUIRegisterMsg($WM_COMMAND, "_WM_COMMAND")
GUIRegisterMsg($WM_GETMINMAXINFO, "_WM_GETMINMAXINFO")
OnAutoItExitRegister("_Quitting")

_AutoItObject_StartUp()
Global $oObject = _SomeObject()
Global $hObj = _AutoItObject_RegisterObject($oObject, $sMyCLSID & "." & @AutoItPID)

AdlibRegister("_ServerCheck")

While 1
	Switch GUIGetMsg()
		Case $GUI_EVENT_CLOSE
			For $iX = 1 To UBound($avPopups) -1
				_WinAPI_SetWindowLong(GUICtrlGetHandle($avPopups[$iX][4]), $GWL_WNDPROC, $avPopups[$iX][3])
				DllCallbackFree($avPopups[$iX][2])
			Next
			Exit
		Case $idAdd
			Local $sIP = GUICtrlRead($idIP), $sPort = GUICtrlRead($idPort)
			If $sPort = "" Then $sPort = $iDefaultPort
			If $sIP = "" Then
				MsgBox(48, StringTrimRight(@ScriptName, 4), "Server Address must be filled in", 0, $hGui)
				ContinueLoop
			EndIf
			Local $iIndex = -1
			While 1
				$iIndex = _GUICtrlListView_FindText($idServers, $sIP, $iIndex, False, False)
				If $iIndex <> -1 Then
					If _GUICtrlListView_GetItemText($idServers, $iIndex, 1) = $sPort Then
						MsgBox(48, StringTrimRight(@ScriptName, 4), "You already have a server with this address and port added!", 0, $hGui)
						ContinueLoop 2
					Else
						ContinueLoop
					EndIf
				Else
					ExitLoop
				EndIf
			WEnd

			GUICtrlCreateListViewItem($sIP & "|" & $sPort, $idServers)
			GUICtrlSetBkColor(-1, 0xFFFFFF)
			GUICtrlSetColor(-1, 0)
			_GUICtrlListView_SetColumnWidth($idServers, 0, $LVSCW_AUTOSIZE)
			_GUICtrlListView_SetColumnWidth($idServers, 1, $LVSCW_AUTOSIZE_USEHEADER)
			IniWrite(@ScriptDir & "\Servers.ini", $sIP, $sPort, "False")
		Case $idScanNow
			_ServerCheck()
		Case $idServerDelete
			_ServerDelete()
		Case $idServerShowPopup
			_ServerPopupShow()
		Case $idUpdateLabel
			If $sUpdateLink <> "" Then ShellExecute($sUpdateLink)
		Case $idPopupDummy
			$iSkipLabelProc = True
			$iCurrent = GUICtrlRead($idPopupDummy)
			_WinAPI_SetWindowLong(GUICtrlGetHandle($avPopups[$iCurrent][4]), $GWL_WNDPROC, $avPopups[$iCurrent][3])
			DllCallbackFree($avPopups[$iCurrent][2])
			GUIDelete($avPopups[$iCurrent][0])
			_ArrayDelete($avPopups, $iCurrent)
			$iSkipLabelProc = False
	EndSwitch
WEnd

Func _ServerDelete()
	$aiListviewSelected = _GUICtrlListView_GetSelectedIndices($idServers, True)
	If $aiListviewSelected[0] = 0 Then
		MsgBox(48, StringTrimRight(@ScriptName, 4), "No server selected", 0, $hGui)
		Return
	EndIf

	For $iX = $aiListviewSelected[0] To 1 Step -1
		IniDelete(@ScriptDir & "\Servers.ini", _GUICtrlListView_GetItemText($idServers, $aiListviewSelected[$iX]), _GUICtrlListView_GetItemText($idServers, $aiListviewSelected[$iX], 1))
		_GUICtrlListView_DeleteItem($idServers, $aiListviewSelected[$iX])
	Next
EndFunc

Func _ServerPopupShow()
	$aiListviewSelected = _GUICtrlListView_GetSelectedIndices($idServers, True)
	If $aiListviewSelected[0] = 0 Then
		MsgBox(48, StringTrimRight(@ScriptName, 4), "No server selected", 0, $hGui)
		Return
	EndIf

	Local $iY = -1

	For $iX = $aiListviewSelected[0] To 1 Step -1
		_ServerPopupAdd(_GUICtrlListView_GetItemText($idServers, $aiListviewSelected[$iX]), _GUICtrlListView_GetItemText($idServers, $aiListviewSelected[$iX], 1), $iY)
		$aiPos = WinGetPos($avPopups[UBound($avPopups) -1][0])
		$iY = $aiPos[1] + $aiPos[3]
	Next
EndFunc

Func _ServerPopupAdd($sServerAddress, $sPort, $iY)
	ReDim $avPopups[UBound($avPopups) +1][5]
	Local $iGuiX = 400, $iGuiY = 23
	$avPopups[UBound($avPopups) -1][0] = GUICreate(Random(), $iGuiX, $iGuiY, -1, $iY, $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
	GUICtrlCreateLabel("[Drag]", 0, 0, 50, $iGuiY, BitOR($SS_CENTER, $SS_CENTERIMAGE), $GUI_WS_EX_PARENTDRAG)
	$avPopups[UBound($avPopups) -1][1] = GUICtrlCreateListView("Server Address|Server Port|Version|Current/Max Players|MOTD", 50, 0, $iGuiX -100, $iGuiY, $LVS_NOCOLUMNHEADER, $LVS_EX_GRIDLINES)
	GUICtrlCreateListViewItem($sServerAddress & "|" & $sPort, -1)
	_GUICtrlListView_SetColumnWidth($avPopups[UBound($avPopups) -1][1], 0, $LVSCW_AUTOSIZE)
	_GUICtrlListView_SetColumnWidth($avPopups[UBound($avPopups) -1][1], 1, $LVSCW_AUTOSIZE)
	_GUICtrlListView_SetColumnWidth($avPopups[UBound($avPopups) -1][1], 2, $LVSCW_AUTOSIZE)
	_GUICtrlListView_SetColumnWidth($avPopups[UBound($avPopups) -1][1], 3, $LVSCW_AUTOSIZE)
	_GUICtrlListView_SetColumnWidth($avPopups[UBound($avPopups) -1][1], 4, $LVSCW_AUTOSIZE)
	$avPopups[UBound($avPopups) -1][4] = GUICtrlCreateLabel("[Close]", $iGuiX -50, 0, 50, $iGuiY, BitOR($SS_CENTER, $SS_CENTERIMAGE))
	GUISetState()

	$avPopups[UBound($avPopups) -1][2] = DllCallbackRegister("_LabelProc", "int", "hwnd;uint;wparam;lparam")
	$avPopups[UBound($avPopups) -1][3] = _WinAPI_SetWindowLong(GUICtrlGetHandle($avPopups[UBound($avPopups) -1][4]), $GWL_WNDPROC, DllCallbackGetPtr($avPopups[UBound($avPopups) -1][2]))
EndFunc

Func _LabelProc($hWnd, $iMsg, $iwParam, $ilParam)
	If $iSkipLabelProc Then Return 0

	Local $iCurrent = 0
	For $iX = 1 To UBound($avPopups) -1
		If $hWnd = GUICtrlGetHandle($avPopups[$iX][4]) Then
			$iCurrent = $iX   ;$iCurrent is not used anywhere after this, remove?
			ExitLoop
		EndIf
	Next

    Switch $iMsg
		Case $WM_LBUTTONDOWN
			GUICtrlSendToDummy($idPopupDummy, $iX)

			Return 0
	EndSwitch

	Return _WinAPI_CallWindowProc($avPopups[$iX][3], $hWnd, $iMsg, $iwParam, $ilParam)
EndFunc

Func _ServerCheck()
	Global $asServerPlayers[1][3]
	AdlibUnRegister("_ScanningCrashedReset")
	AdlibUnRegister("_ServerCheck")
	GUICtrlSetData($idScanNow, "Scanning under way")
	GUICtrlSetState($idScanNow, $GUI_DISABLE)
	AdlibRegister("_WorkingAnimation")
	If @Compiled Then
		$iPid = Run(FileGetShortName(@AutoItExe) & " /ServerScanner " & @AutoItPID)
	Else
		$iPid = Run(@AutoItExe & ' "' & @ScriptFullPath & '" /ServerScanner ' & @AutoItPID)
	EndIf
EndFunc

Func _WorkingAnimation()
	Static Local $sAnimation = "qpbd"
	If ProcessExists($iPid) Then
		$sCurrent = StringLeft($sAnimation, 1)
		GUICtrlSetData($idScanNow, "Scanning under way " & $sCurrent)
		$sAnimation = StringTrimLeft($sAnimation, 1) & $sCurrent
	Else
		_ServerFinished("boobs")
		GUICtrlSetData($idScanNow, "! Scanning crashed !")
		AdlibRegister("_ScanningCrashedReset", 3750)
	EndIf
EndFunc

Func _ScanningCrashedReset()
	GUICtrlSetData($idScanNow, "Scan now")
	AdlibUnRegister("_ScanningCrashedReset")
EndFunc

Func _ServerScanner()
	Local $iSocket
	Local $oObj = ObjGet($sMyCLSID & "." & $CmdLine[2])

	TCPStartup()

	$iTimeoutSeconds = Int(IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "TimeoutSeconds", "HamburgareIsTasty"))
	If $iTimeoutSeconds = 0 Then $iTimeoutSeconds = 10
	$iTimeoutSeconds *= 1000

	$asServers = IniReadSectionNames(@ScriptDir & "\Servers.ini")
	If Not @error Then
		For $iX = 1 To $asServers[0]
			$asPorts = IniReadSection(@ScriptDir & "\Servers.ini", $asServers[$iX])
			If @error Then ContinueLoop

			For $iY = 1 To $asPorts[0][0]
				If $asPorts[$iY][1] = "False" Then ContinueLoop
				If StringIsDigit(StringReplace($asServers[$iX], ".", "")) Then
					$iSocket = _TCPConnect($asServers[$iX], $asPorts[$iY][0], $iTimeoutSeconds)
				Else
					$iSocket = _TCPConnect(TCPNameToIP($asServers[$iX]), $asPorts[$iY][0], $iTimeoutSeconds)
				EndIf
				$oObj.Log("Connecting to " & $asServers[$iX] & ":" & $asPorts[$iY][0] & " /Socket=" & $iSocket & " /Error=" & @error)
				If $asPorts[$iY][1] = "Old" Then   ;pre 1.4 protocol
					TCPSend($iSocket, Binary("0xFE"))
				ElseIf $asPorts[$iY][1] = "New" Then   ;1.7+ protocol
					$bTemp = Binary("0x0004" & Hex(BinaryLen($asServers[$iX]), 2)) & Binary($asServers[$iX]) & Hex($asPorts[$iY][0], 4) & "01" & "0100"
					$bTemp = Binary("0x" & Hex(BinaryLen($bTemp) -2, 2)) & StringTrimLeft($bTemp, 2)
					$bHandshake = Binary("0x0E0004" & Hex(BinaryLen($asServers[$iX]), 2)) & Binary($asServers[$iX]) & Hex($asPorts[$iY][0], 4) & "01"   ;first byte (0x!0E!0004) should be total length
					$bRequest = "0100"
					TCPSend($iSocket, $bTemp)
				Else   ;1.4 - 1.7 protocol
					TCPSend($iSocket, Binary("0xFE01"))
				EndIf

				While 1
					While 1
						Sleep(1500)
						$dRet = TCPRecv($iSocket, 1500, 1)
						If @error Then
							TCPCloseSocket($iSocket)
							ExitLoop
						EndIf

						If $dRet <> "" Then

							If $asPorts[$iY][1] = "New" Then   ;1.7+ protocol
								$oObj.Log("Online (1.7+ protocol)")

								Do
									$dRet &= TCPRecv($iSocket, 1500, 1)
								Until @error <> 0
								$oObj.Log($dRet)

								$oJSON = Jsmn_Decode(BinaryToString(BinaryMid($dRet, StringInStr($dRet, "7B") / 2)))

								$oVersion = Jsmn_ObjGet($oJSON, "version")
								$sVersionName = Jsmn_ObjGet($oVersion, "name")
								$iVersionProtocol = Jsmn_ObjGet($oVersion, "protocol")

								$oPlayers = Jsmn_ObjGet($oJSON, "players")
								$iPlayersMax = Jsmn_ObjGet($oPlayers, "max")
								$iPlayersOnline = Jsmn_ObjGet($oPlayers, "online")

								$sDescription = Jsmn_ObjGet($oJSON, "description")

								If Jsmn_ObjExists($oPlayers, "sample") Then
									$oSample = Jsmn_ObjGet($oPlayers, "sample")
									$oSampleKeys = Jsmn_ObjTo2DArray($oSample)
									For $iZ = 0 To UBound($oSampleKeys) -1
										$aPlayer = $oSampleKeys[0]
										$oObj.Player($asServers[$iX], $asPorts[$iY][0], $aPlayer[2][1], $aPlayer[1][1])
									Next
								EndIf

								$SFavicon = Jsmn_ObjGet($oJSON, "favicon")

								$hPNG = FileOpen(@ScriptDir & "\TemporaryFiles\" & $asServers[$iX] & " " & $asPorts[$iY][0] & ".png", 2+8+16)
								FileWrite($hPNG, _B64Decode(StringStripWS(StringTrimLeft($SFavicon, StringInStr($sFavicon, ",")), $STR_STRIPALL)))
								FileClose($hPNG)

								$oObj.Results($asServers[$iX], $asPorts[$iY][0], $sVersionName, $sDescription, $iPlayersOnline, $iPlayersMax, $iVersionProtocol)   ;Server online (1.7+ protocol)
								ExitLoop 2
							Else   ;Pre 1.7 protocols
								$aRet = StringSplit(BinaryToString(BinaryMid($dRet, 4), 3), Chr(0))

								If UBound($aRet) = 7 Then
									$oObj.Log("Online (1.4 - 1.7 protocol)")
									$oObj.Results($asServers[$iX], $asPorts[$iY][0], $aRet[3], $aRet[4], $aRet[5], $aRet[6], $aRet[2])   ;Server online (1.4 - 1.7 protocol)
								Else
									$aRet = StringSplit(BinaryToString(BinaryMid($dRet, 4), 3), "§")
									If UBound($aRet) = 4 Then
										If $asPorts[$iY][1] = "True" Then IniWrite(@ScriptDir & "\Servers.ini", $asServers[$iX], $asPorts[$iY][0], "Old")
										$oObj.Log("Online (old protocol)")
										$oObj.Results($asServers[$iX], $asPorts[$iY][0], "1.3 or older", $aRet[1], $aRet[2], $aRet[3], "")   ;Server online (pre 1.4 protocol)
									Else
										$oObj.Log("Error")
										$oObj.Results($asServers[$iX], $asPorts[$iY][0], "Error", "Error", "Error", "Error", "Error")   ;Error
									EndIf
								EndIf

								TCPCloseSocket($iSocket)
								ExitLoop 2
							EndIf
						EndIf
						Sleep(100)
					WEnd

					$oObj.Log("Offline")
					$oObj.Results($asServers[$iX], $asPorts[$iY][0], "", "", "", "", "")   ;Server offline
					ExitLoop
				WEnd
			Next
		Next
	EndIf

	TCPShutdown()
	$oObj.Finished()

	Exit
EndFunc

Func _IniClean();_IniClean($oObj)
	$asServers = IniReadSectionNames(@ScriptDir & "\Servers.ini")
	If Not @error Then
		For $iX = 1 To $asServers[0]
			$asPorts = IniReadSection(@ScriptDir & "\Servers.ini", $asServers[$iX])
			If @error Then
				IniDelete(@ScriptDir & "\Servers.ini", $asServers[$iX])
				ContinueLoop
			EndIf

			IniDelete(@ScriptDir & "\Servers.ini", $asServers[$iX], "")
		Next
	EndIf
EndFunc

;By Beege http://www.autoitscript.com/forum/topic/155546-base64-machine-code-functions-source/
Func _B64Decode($sSource)
	Local Static $Opcode, $tMem, $tRevIndex, $fStartup = True

	If $fStartup Then
		If @AutoItX64 Then
			$Opcode = '0xC800000053574D89C74C89C74889D64889CB4C89C89948C7C10400000048F7F148C7C10300000048F7E14989C242807C0EFF3D750E49FFCA42807C0EFE3D750349FFCA4C89C89948C7C10800000048F7F14889C148FFC1488B064989CD48C7C108000000D7C0C0024188C349C1E30648C1E808E2EF49C1E308490FCB4C891F4883C7064883C6084C89E9E2CB4C89D05F5BC9C3'
		Else
			$Opcode = '0xC8080000FF75108B7D108B5D088B750C8B4D148B06D7C0C00288C2C1E808C1E206D7C0C00288C2C1E808C1E206D7C0C00288C2C1E808C1E206D7C0C00288C2C1E808C1E2060FCA891783C70383C604E2C2807EFF3D75084F807EFE3D75014FC6070089F85B29D8C9C21000'
		EndIf

		Local $aMemBuff = DllCall("kernel32.dll", "ptr", "VirtualAlloc", "ptr", 0, "ulong_ptr", BinaryLen($Opcode), "dword", 4096, "dword", 64)
		$tMem = DllStructCreate('byte[' & BinaryLen($Opcode) & ']', $aMemBuff[0])
		DllStructSetData($tMem, 1, $Opcode)

		Local $aRevIndex[128]
		Local $aTable = StringToASCIIArray('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/')
		For $i = 0 To UBound($aTable) - 1
			$aRevIndex[$aTable[$i]] = $i
		Next
		$tRevIndex = DllStructCreate('byte[' & 128 & ']')
		DllStructSetData($tRevIndex, 1, StringToBinary(StringFromASCIIArray($aRevIndex)))

		$fStartup = False
	EndIf

	Local $iLen = StringLen($sSource)
	Local $tOutput = DllStructCreate('byte[' & $iLen + 8 & ']')
	DllCall("kernel32.dll", "bool", "VirtualProtect", "struct*", $tOutput, "dword_ptr", DllStructGetSize($tOutput), "dword", 0x00000004, "dword*", 0)

	Local $tSource = DllStructCreate('char[' & $iLen + 8 & ']')
	DllStructSetData($tSource, 1, $sSource)

	Local $aRet = DllCallAddress('uint', DllStructGetPtr($tMem), 'struct*', $tRevIndex, 'struct*', $tSource, 'struct*', $tOutput, 'uint', (@AutoItX64 ? $iLen : $iLen / 4))

	Return BinaryMid(DllStructGetData($tOutput, 1), 1, $aRet[0])
EndFunc   ;==>_B64Decode

Func _SomeObject()
    Local $oClassObject = _AutoItObject_Class()
    $oClassObject.AddMethod("Log", "_ServerLog")
    $oClassObject.AddMethod("Player", "_ServerPlayer")
    $oClassObject.AddMethod("Results", "_ServerResults")
    $oClassObject.AddMethod("Finished", "_ServerFinished")
    Return $oClassObject.Object
EndFunc   ;==>_SomeObject

Func _ServerLog($oSelf, $sMessage)
	ConsoleWrite($sMessage & @LF)
EndFunc

Func _ServerPlayer($oSelf, $sServerAddress, $iServerPort, $sPlayer, $nId)
	ConsoleWrite("_ServerPlayer: " & $sPlayer & "/" & $nId & @LF)

	Local $iUBound = UBound($asServerPlayers)
	ReDim $asServerPlayers[$iUBound +1][3]
	$asServerPlayers[$iUBound][0] = $sServerAddress & ":" & $iServerPort
	$asServerPlayers[$iUBound][1] = $sPlayer
	$asServerPlayers[$iUBound][2] = $nId
EndFunc

Func _ServerResults($oSelf, $sServerAddress, $iServerPort, $sVersion, $sMOTD, $iCurrentPlayers, $iMaxPlayers, $iProtocol)
	If $iProtocol <> "" And $iProtocol <> "Error" Then ConsoleWrite("_ServerResults: Version=" & $sVersion & " Protocol=" & $iProtocol & " Players=" & $iCurrentPlayers & "/" & $iMaxPlayers & " MOTD=" & $sMOTD & @LF)

	Local $iIndex = -1
	While 1
		$iIndex = _GUICtrlListView_FindText($idServers, $sServerAddress, $iIndex, False, False)
		If $iIndex <> -1 Then
			If _GUICtrlListView_GetItemText($idServers, $iIndex, 1) = $iServerPort Then
				_GUICtrlListView_SetItemText($idServers, $iIndex, $sVersion, 2)
				If $iCurrentPlayers = "" Then
					_GUICtrlListView_SetItemText($idServers, $iIndex, 0 & "/" & -1, 3)
					If BitAnd(GUICtrlRead($idColorizeListview), $GUI_CHECKED) Then GUICtrlSetBkColor(_GUICtrlListView_GetItemParam($idServers, $iIndex), 0xFF0000)
				Else
					$iServerCount += 1
					If _GUICtrlListView_GetItemText($idServers, $iIndex, 3) = "" Then
						If BitAnd(GUICtrlRead($idFlashWin), $GUI_CHECKED) Then
							WinFlash($hGui)
						EndIf
					EndIf
					_GUICtrlListView_SetItemText($idServers, $iIndex, $iCurrentPlayers & "/" & $iMaxPlayers, 3)
					If BitAnd(GUICtrlRead($idColorizeListview), $GUI_CHECKED) Then
						If $iCurrentPlayers > 0 Then
							GUICtrlSetBkColor(_GUICtrlListView_GetItemParam($idServers, $iIndex), 0x00FF00)
						Else
							GUICtrlSetBkColor(_GUICtrlListView_GetItemParam($idServers, $iIndex), 0xFFFF33)
						EndIf
					EndIf
				EndIf
				_GUICtrlListView_SetItemText($idServers, $iIndex, $sMOTD, 4)

				_GUICtrlListView_SetColumnWidth($idServers, 4, $LVSCW_AUTOSIZE)

				ExitLoop
			Else
				ContinueLoop
			EndIf
		Else
			ExitLoop
		EndIf
	WEnd

	For $iX = 1 To UBound($avPopups) -1
		If _GUICtrlListView_GetItemText($avPopups[$iX][1], 0, 0) <> $sServerAddress Or _GUICtrlListView_GetItemText($avPopups[$iX][1], 0, 1) <> $iServerPort Then ContinueLoop

		_GUICtrlListView_SetItemText($avPopups[$iX][1], 0, $sVersion, 2)
		If $iCurrentPlayers = "" Then
			_GUICtrlListView_SetItemText($avPopups[$iX][1], 0, "", 3)
			GUICtrlSetBkColor(_GUICtrlListView_GetItemParam($avPopups[$iX][1], 0), 0xFF0000)
		Else
			_GUICtrlListView_SetItemText($avPopups[$iX][1], 0, $iCurrentPlayers & "/" & $iMaxPlayers, 3)
			If $iCurrentPlayers > 0 Then
				GUICtrlSetBkColor(_GUICtrlListView_GetItemParam($avPopups[$iX][1], 0), 0x00FF00)
			Else
				GUICtrlSetBkColor(_GUICtrlListView_GetItemParam($avPopups[$iX][1], 0), 0xFFFF33)
			EndIf
		EndIf
		_GUICtrlListView_SetItemText($avPopups[$iX][1], 0, $sMOTD, 4)

		_GUICtrlListView_SetColumnWidth($avPopups[$iX][1], 2, $LVSCW_AUTOSIZE)
		_GUICtrlListView_SetColumnWidth($avPopups[$iX][1], 3, $LVSCW_AUTOSIZE)
		_GUICtrlListView_SetColumnWidth($avPopups[$iX][1], 4, $LVSCW_AUTOSIZE)
	Next

	ConsoleWrite("------------------------------" & @LF)
EndFunc

Func _ServerFinished($oSelf)
	AdlibUnRegister("_WorkingAnimation")
	$iServerTray = $iServerCount
	$iServerCount = 0
	_TraySet($iServerTray)
	AdlibRegister("_ServerCheck", GUICtrlRead($idSeconds) * 1000)
	GUICtrlSetData($idScanNow, "Scan now")
	GUICtrlSetState($idScanNow, $GUI_ENABLE)
EndFunc

#region
Func _ServerInfoShow($iIndex)
	Local $iFlag = False
	_GUICtrlListView_DeleteAllItems(GUICtrlGetHandle($idServerPlayers))

	Local $sServer = _GUICtrlListView_GetItemText($idServers, $iIndex)
	Local $iPort = _GUICtrlListView_GetItemText($idServers, $iIndex, 1)

	If FileExists(@ScriptDir & "\TemporaryFiles\" & $sServer & " " & $iPort & ".png") Then
		_SetImage($idServerImage, @ScriptDir & "\TemporaryFiles\" & $sServer & " " & $iPort & ".png")
		$iFlag = True
	Else
		GUICtrlSetImage($idServerImage, @ScriptDir & "\Emma Watson.jpg")
	EndIf

	For $iX = 0 To UBound($asServerPlayers) -1
		If $asServerPlayers[$iX][0] <> $sServer & ":" & $iPort Then ContinueLoop

		_GUICtrlListView_AddItem($idServerPlayers, $asServerPlayers[$iX][1], $iListNew)
		$iFlag = True
	Next
	If $iFlag Then
		Local $aiGui = WinGetPos($hGui)
		WinMove($hGui, "", $aiGui[0], $aiGui[1], $aiGuiMin[2], $aiGuiMin[3])
	Else
		Local $aiGui = WinGetPos($hGui)
		WinMove($hGui, "", $aiGui[0], $aiGui[1], $aiGuiMin[2] -187, $aiGuiMin[3])
	EndIf
	AdlibRegister("_DownloadPlayerImages")
EndFunc

Func _DownloadPlayerImages()
	AdlibUnRegister("_DownloadPlayerImages")
	For $iX = 0 To _GUICtrlListView_GetItemCount($idServerPlayers) -1
		If _GUICtrlListView_GetItemImage($idServerPlayers, $iX) <> 0 Then ContinueLoop

		$sFileName = _GUICtrlListView_GetItemText($idServerPlayers, $iX) & ".png"
		$sFileNameHEAD = @ScriptDir & "\TemporaryFiles\" & _GUICtrlListView_GetItemText($idServerPlayers, $iX) & "HEAD.png"

		If FileExists($sFileNameHEAD) Then
			_GUICtrlListView_SetItemImage($idServerPlayers, $iX, _ListView_AddImage($idServerPlayers, $sFileNameHEAD))
			AdlibRegister("_DownloadPlayerImages")
		Else
			DirCreate(@ScriptDir & "\TemporaryFiles")
			$avInet = InetGet("http://s3.amazonaws.com/MinecraftSkins/" & $sFileName, @ScriptDir & "\TemporaryFiles\" & $sFileName)
			If $avInet = 0 Then
				_GUICtrlListView_SetItemImage($idServerPlayers, $iX, $iListError)
			Else
				$hImage = _GDIPlus_ImageLoadFromFile(@ScriptDir & "\TemporaryFiles\" & $sFileName)

				$hWnd = _WinAPI_GetDesktopWindow()
				$hDC = _WinAPI_GetDC($hWnd)
				$hBMP = _WinAPI_CreateCompatibleBitmap($hDC, 32, 32)
				_WinAPI_ReleaseDC($hWnd, $hDC)

				$hImageCropped = _GDIPlus_BitmapCreateFromHBITMAP ($hBMP)
				$hGraphic = _GDIPlus_ImageGetGraphicsContext ($hImageCropped)
				_GDIPlus_GraphicsSetInterpolationMode($hGraphic, 5)
				_GDIPlus_GraphicsDrawImageRectRect($hGraphic, $hImage, 7.5, 7.5, 8, 8, 0, 0, 32, 32)
				$CLSID = _GDIPlus_EncodersGetCLSID("PNG")

				_GDIPlus_ImageSaveToFileEx($hImageCropped, $sFileNameHEAD, $CLSID)
				_GDIPlus_ImageDispose($hImageCropped)
				_GDIPlus_ImageDispose($hImage)
				_GDIPlus_GraphicsDispose ($hGraphic)
				_WinAPI_DeleteObject($hBMP)

				FileDelete(@ScriptDir & "\TemporaryFiles\" & $sFileName)

				_GUICtrlListView_SetItemImage($idServerPlayers, $iX, _ListView_AddImage($idServerPlayers, $sFileNameHEAD))
			EndIf
			AdlibRegister("_DownloadPlayerImages")
		EndIf
		ExitLoop
	Next
EndFunc

Func _ListView_AddImage($hListview, $sFile)
	Return _ImageList_AddImage(_GUICtrlListView_GetImageList($hListview, 0), $sFile)
EndFunc

Func _ImageList_AddImage($hImageList, $sFile)
	Local $hBitmap = _GDIPlus_BitmapCreateFromFile($sFile)
	Local $gc_PNG = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBitmap)
	Local $iIndex = _GUIImageList_Add($hImageList, $gc_PNG)
	_WinAPI_DeleteObject($gc_PNG)
	_GDIPlus_BitmapDispose($hBitmap)
	Return $iIndex
EndFunc
#endregion

; #FUNCTION# ====================================================================================================================
; Name...........: _TCPConnect
; Description ...: Triess to establishes a TCP-connection in a specified time limit
; Syntax.........: _TCPConnect($sIPAddr, $iPort, $iTimeOut = -1)
; Parameters ....: $sIpAddr - IP address to connect to (IPv4)
; $iPort - Port to use
; $iTimeOut - Timeout for connection in milliseconds (default: -1)
; |Values < 0: default timeout
; |Values 0, Keyword Default: use time from Opt("TCPTimeout")
; |Values > 0: timeout in milliseconds
; Return values .: Success - Socket to use with TCP-functions
; Failure - -1, sets @error
; |1 - $sIpAddr incorrect
; |2 - could not get port
; |3 - could not create socket
; |4 - could not connect
; |5 - could not get WSAError
; |and errors from WSAGetLastError
; Author ........: ProgAndy
; Modified.......: JScript
; Remarks .......:
; Related .......: TCPConnect, TCPCloseSocket, TCPSend, TCPRecv
; Link ..........:
; Example .......:
; ===============================================================================================================================
Func _TCPConnect($sIPAddr, $iPort, $iTimeOut = -1)
	Local $hWs2 = DllOpen("Ws2_32.dll")
	Local $iDllErr, $fError = False, $aRes
	Local $hSock = DllCall($hWs2, "uint", "socket", "int", 2, "int", 1, "int", 6)
	If @error Then
		$iDllErr = 3
	ElseIf $hSock[0] = 4294967295 Or $hSock[0] = -1 Then
		$fError = True
	Else
		$hSock = $hSock[0]
		$aRes = DllCall($hWs2, "ulong", "inet_addr", "str", $sIPAddr)
		If @error Or $aRes[0] = -1 Or $aRes[0] = 4294967295 Then
			$iDllErr = 1
		Else
			$iPort = DllCall($hWs2, "ushort", "htons", "ushort", $iPort)
			If @error Then
				$iDllErr = 2
			Else
				$iPort = $iPort[0]
			EndIf
		EndIf
		If 0 = $iDllErr Then
			Local $tSockAddr = DllStructCreate("short sin_family;ushort sin_port; ulong sin_addr;char sin_zero[8];")
			DllStructSetData($tSockAddr, 1, 2)
			DllStructSetData($tSockAddr, 2, $iPort)
			DllStructSetData($tSockAddr, 3, $aRes[0])

			If IsKeyword($iTimeOut) Or $iTimeOut = 0 Then $iTimeOut = Opt("TCPTimeout")

			If $iTimeOut > -1 Then DllCall($hWs2, "int", "ioctlsocket", "int", $hSock, "long", 0x8004667e, "uint*", 1)
			$aRes = DllCall($hWs2, "int", "connect", "int", $hSock, "ptr", DllStructGetPtr($tSockAddr), "int", DllStructGetSize($tSockAddr))

			Select
				Case @error
					$iDllErr = 4
				Case $aRes[0] <> 0
					$aRes = DllCall($hWs2, "int", "WSAGetLastError")
					If Not @error And $aRes[0] = 10035 Then ContinueCase
					$fError = True
				Case $iTimeOut > -1
					If IsKeyword($iTimeOut) Or $iTimeOut = 0 Then $iTimeOut = Opt("TCPTimeout")
					Local $t = DllStructCreate("uint;int")
					DllStructSetData($t, 1, 1)
					DllStructSetData($t, 2, $hSock)
					Local $to = DllStructCreate("long;long")
					DllStructSetData($to, 1, Floor($iTimeOut / 1000))
					DllStructSetData($to, 2, Mod($iTimeOut, 1000))
					$aRes = DllCall($hWs2, "int", "select", "int", $hSock, "ptr", DllStructGetPtr($t), "ptr", DllStructGetPtr($t), "ptr", 0, "ptr", DllStructGetPtr($to))
					If Not @error And $aRes[0] = 0 Then
						$aRes = DllCall($hWs2, "int", "WSAGetLastError")
						If Not @error And $aRes[0] = 0 Then
							$iDllErr = 10060
						Else
							$fError = True
						EndIf
					Else
						DllCall($hWs2, "int", "ioctlsocket", "int", $hSock, "long", 0x8004667e, "uint*", 0)
					EndIf
			EndSelect
		EndIf
	EndIf
	If $iDllErr Then
		TCPCloseSocket($hSock)
		$hSock = -1
	ElseIf $fError Then
		$iDllErr = DllCall($hWs2, "int", "WSAGetLastError")
		If Not @error Then $iDllErr = $iDllErr[0]
		If $iDllErr = 0 Then $iDllErr = 5
		TCPCloseSocket($hSock)
		$hSock = -1
	EndIf
	DllClose($hWs2)
	Return SetError($iDllErr, 0, $hSock)
EndFunc   ;==>_TCPConnect

;Thx to Mat for code to use a bitmap instead of a file for tray icon http://www.autoitscript.com/forum/topic/115222-set-the-tray-icon-as-a-hicon/
Func _TraySet($sText)
	_GDIPlus_GraphicsClear($hGraphic, 0xFFFFFFFF)

	$hFamily = _GDIPlus_FontFamilyCreate('Arial')
	$hFont = _GDIPlus_FontCreate($hFamily, 16, 1, 2)
	$tLayout = _GDIPlus_RectFCreate(0, 0, 0, 0)
	$hFormat = _GDIPlus_StringFormatCreate()
	$hBrush = _GDIPlus_BrushCreateSolid(0xFF000000)
	$aData = _GDIPlus_GraphicsMeasureString($hGraphic, $sText, $hFont, $tLayout, $hFormat)
	$tLayout = $aData[0]
	DllStructSetData($tLayout, 1, (_GDIPlus_ImageGetWidth($hImage) - DllStructGetData($tLayout, 3)) / 2)
	DllStructSetData($tLayout, 2, (_GDIPlus_ImageGetHeight($hImage) - DllStructGetData($tLayout, 4)) / 2)
	_GDIPlus_GraphicsDrawStringEx($hGraphic, $sText, $hFont, $aData[0], $hFormat, $hBrush)
	_GDIPlus_StringFormatDispose($hFormat)
	_GDIPlus_FontFamilyDispose($hFamily)
	_GDIPlus_FontDispose($hFont)
	_GDIPlus_BrushDispose($hBrush)

	$hIcon = _GDIPlus_BitmapCreateHICONFromBitmap($hImage)
	$vRet = _Tray_SetHIcon($hIcon)
	_WinAPI_DestroyIcon($hIcon)
EndFunc

Func _GDIPlus_BitmapCreateHICONFromBitmap($hBitmap)
    Local $hIcon = DllCall($ghGDIPDll, "int", "GdipCreateHICONFromBitmap", "hwnd", $hBitmap, "int*", 0)
    If @error Or Not $hIcon[0] Then Return SetError(@error, @extended, $hIcon[2])

    Return $hIcon[2]
EndFunc   ;==>_GDIPlus_BitmapCreateHICONFromBitmap

Func _Tray_SetHIcon($hIcon)
    Local $tNOTIFY = DllStructCreate($tagNOTIFYICONDATA)
    DllStructSetData($tNOTIFY, "Size", DllStructGetSize($tNOTIFY))
    DllStructSetData($tNOTIFY, "Wnd", $TRAY_ICON_GUI)
    DllStructSetData($tNOTIFY, "ID", $AUT_NOTIFY_ICON_ID)
    DllStructSetData($tNOTIFY, "Icon", $hIcon)
    DllStructSetData($tNOTIFY, "Flags", BitOR($NIF_ICON, $NIF_MESSAGE))
    DllStructSetData($tNOTIFY, "CallbackMessage", $AUT_WM_NOTIFYICON)

    Local $aRet = DllCall("shell32.dll", "int", "Shell_NotifyIconW", "dword", $NIM_MODIFY, "struct*", $tNOTIFY)
    If (@error) Then Return SetError(1, 0, 0)

    Return $aRet[0] <> 0
EndFunc   ;==>_Tray_SetHIcon

Func _Quitting()
	AdlibUnRegister("_ServerCheck")
	AdlibUnRegister("_CheckForUpdate")
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "SecondsBetweenScans", GUICtrlRead($idSeconds))
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "FlashWindow", BitAnd(GUICtrlRead($idFlashWin), $GUI_CHECKED))
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "CountTray", BitAnd(GUICtrlRead($idCountTray), $GUI_CHECKED))
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "CheckForUpdate", BitAnd(GUICtrlRead($idCheckForUpdate), $GUI_CHECKED))
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "ColorizeListview", BitAnd(GUICtrlRead($idColorizeListview), $GUI_CHECKED))
	ConsoleWrite("bye" & @LF)
EndFunc

;Thx to Yashied for Code/Idea on how to handle listview checkboxes http://www.autoitscript.com/forum/topic/110391-listview-get-change-in-checking-items/#entry775483
Func _WM_NOTIFY($hWnd, $iMsg, $iwParam, $ilParam)
	#forceref $hWnd, $iMsg, $iwParam
	Local $iIDFrom, $iCode, $tNMHDR, $tInfo, $iIndex
	Static Local $iState

	$tNMHDR = DllStructCreate($tagNMHDR, $ilParam)
	$iIDFrom = DllStructGetData($tNMHDR, "IDFrom")
	$iCode = DllStructGetData($tNMHDR, "Code")

	If $iIDFrom <> $idServers Then Return $GUI_RUNDEFMSG

	Switch $iCode
		Case $LVN_ITEMCHANGING
			$tInfo = DllStructCreate($tagNMITEMACTIVATE, $ilParam)
			$iIndex = DllStructGetData($tInfo, "Index")
			$iState = _GUICtrlListView_GetItemChecked($idServers, $iIndex)

			If $iListviewFlag Then
				$iListviewIndex = $iIndex
				$iListviewFlag = False
			EndIf
		Case $LVN_ITEMCHANGED
			$tInfo = DllStructCreate($tagNMITEMACTIVATE, $ilParam)
			$iIndex = DllStructGetData($tInfo, "Index")
			If $iState <> _GUICtrlListView_GetItemChecked($idServers, $iIndex) Then
				IniWrite(@ScriptDir & "\Servers.ini", _GUICtrlListView_GetItemText($idServers, $iIndex), _GUICtrlListView_GetItemText($idServers, $iIndex, 1), (Not $iState))
			EndIf

			If $iListviewIndex <> -1 Then
				If $iListviewIndex <> $iIndex Then
					_ServerInfoShow($iIndex)
					$iListviewIndex = -1
				EndIf
			EndIf
		Case $LVN_KEYDOWN
			$iListviewFlag = True
		Case $NM_CLICK
			$tInfo = DllStructCreate($tagNMITEMACTIVATE, $ilParam)
			$aiHit = _GUICtrlListView_HitTest(GUICtrlGetHandle($idServers))
			If IsArray($aiHit) And $aiHit[3] = False Then Return $GUI_RUNDEFMSG

			$iIndex = DllStructGetData($tInfo, "Index")
			_ServerInfoShow($iIndex)
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>_WM_NOTIFY

Func _WM_COMMAND($hWnd, $Msg, $wParam, $lParam)
	#forceref $hWnd, $Msg
	Local $nNotifyCode = BitShift($wParam, 16)
	Local $hCtrl = $lParam

	Switch $hCtrl
		Case $hTimeout
			Switch $nNotifyCode
				Case $CBN_EDITCHANGE, $CBN_SELCHANGE
					IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "TimeoutSeconds", GUICtrlRead($cIdTimeout))
			EndSwitch
		Case $hCountTray
			Switch $nNotifyCode
				Case $BN_CLICKED
					If _GUICtrlButton_GetCheck($hCtrl) Then
						Opt("TrayIconHide", 0)
						_TraySet($iServerTray)
					Else
						Opt("TrayIconHide", 1)
					EndIf
			EndSwitch
		Case $hColorizeListview
			Switch $nNotifyCode
				Case $BN_CLICKED
					If _GUICtrlButton_GetCheck($hCtrl) Then
						For $iX = 0 To _GUICtrlListView_GetItemCount($idServers) -1
							If _GUICtrlListView_GetItemChecked($idServers, $iX) Then
								If _GUICtrlListView_GetItemText($idServers, $iX, 2) <> "" Then
									$asSplit = StringSplit(_GUICtrlListView_GetItemText($idServers, $iX, 3), "/")
									If $asSplit[1] > 0 Then
										GUICtrlSetBkColor(_GUICtrlListView_GetItemParam($idServers, $iX), 0x00FF00)
									Else
										GUICtrlSetBkColor(_GUICtrlListView_GetItemParam($idServers, $iX), 0xFFFF33)
									EndIf
								Else
									GUICtrlSetBkColor(_GUICtrlListView_GetItemParam($idServers, $iX), 0xFF0000)
								EndIf
							EndIf
						Next
					Else
						For $iX = 0 To _GUICtrlListView_GetItemCount($idServers) -1
							GUICtrlSetBkColor(_GUICtrlListView_GetItemParam($idServers, $iX), 0xFFFFFF)
						Next
					EndIf
			EndSwitch
	EndSwitch

	Return $GUI_RUNDEFMSG
EndFunc   ;==>_WM_COMMAND

Func _WM_GETMINMAXINFO($hwnd, $Msg, $wParam, $lParam)
    $tagMaxinfo = DllStructCreate("int;int;int;int;int;int;int;int;int;int", $lParam)
    DllStructSetData($tagMaxinfo, 7, $aiGuiMin[2]) ; min X
    DllStructSetData($tagMaxinfo, 8, $aiGuiMin[3]) ; min Y
    Return 0
EndFunc   ;==>WM_GETMINMAXINFO

Func _CheckForUpdate()
	Local $asInfo = InetGetInfo($aInet)
	If $asInfo[1] <> 0 Then GUICtrlSetData($idUpdateLabel, "Checking for update (" & $asInfo[0] / $asInfo[1] * 100 & "%)")
	If $asInfo[2] <> True Then Return
	AdlibUnRegister("_CheckForUpdate")
	InetClose($aInet)
	$sFile = FileRead(@TempDir & "\MSPC.txt")
	FileDelete(@TempDir & "\MSPC.txt")
	AdlibRegister("_UpdateFailed")
	If $asInfo[3] <> True Then Return
	$aRet = StringSplit($sFile, "|")
	If @error Then Return
	If $aRet[0] <> 2 Then Return
	If $aRet[1] <= 17 Then Return   ;Version
	$sUpdateLink = $aRet[2]
	GUICtrlSetData($idUpdateLabel, "Update found, click to open website")
	GUICtrlSetCursor($idUpdateLabel, 0)
EndFunc

Func _UpdateFailed()
	AdlibUnRegister("_UpdateFailed")
	If GUICtrlRead($idUpdateLabel) <> "Update found, click to open website" Then GUICtrlSetData($idUpdateLabel, "No update")
EndFunc