#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Svartnos.ico
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Comment=Minecraft? More like Mecraft!
#AutoIt3Wrapper_Res_Description=Alert user when his favorite Minecraft server goes online
#AutoIt3Wrapper_Res_Fileversion=0.0.0.20
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Res_File_Add=cog.png, rt_rcdata, SETTINGS
#AutoIt3Wrapper_Res_File_Add=Svartnos.jpg, rt_rcdata, SERVER_DEFAULT
#AutoIt3Wrapper_Res_File_Add=PleaseWait.png, rt_rcdata, AVATAR_WAIT
#AutoIt3Wrapper_Res_File_Add=Error.png, rt_rcdata, AVATAR_ERROR
#AutoIt3Wrapper_Res_File_Add=Default3.png, rt_rcdata, AVATAR_DEFAULT
#AutoIt3Wrapper_Res_File_Add=svartnos_tunga.jpg, rt_rcdata, NAUGHTY_CAT
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/sf /sv /mi=6 /rsln
#Au3Stripper_Ignore_Funcs=_ServerMod, _ServerLog, _ServerPlayer, _ServerIcon, _ServerResults, _ServerFinished, _LogFile, _LogConsole, _AdlibNaughtyCatShow, _AdlibNaughtyCatHide, _ServersConvertINI, _ServersAdd, _ServersDelete, _ServersLoad, _ServersSave, _ServersSetEnabled, _ServersSetProtocol, _ServersSetProtocolCurrent, _ServersSetSRVData, _ServersEnabled
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

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
#Au3Stripper_Off
#include "AutoitObject.au3"
#Au3Stripper_On
#include <GDIPlus.au3>
#include <WinAPI.au3>
#include <GuiButton.au3>
#include <Constants.au3>
#include <GuiComboBoxEx.au3>
#include "JSMN.au3"
#include <GuiImageList.au3>
#include "Icons.au3"
#include <Date.au3>
#include <InetConstants.au3>
#include <FontConstants.au3>
#include "AutoIt Pickler.au3"
#include "SRV_Records.au3"
#include <WinAPIShellEx.au3>

Opt("TrayAutoPause", 0)
Opt("TrayIconDebug", 1)
Opt("GUIResizeMode", $GUI_DOCKALL)

Global Const $iDefaultPort = 25565

Global Enum $eServer, $ePort, $eEnabled, $eProtocol, $eSRVData, $eProtocolCurrent, $eServerlistMaxCol
Global Enum $eProtocolAuto, $eProtocol1, $eProtocol2, $eProtocol3, $eProtocolMax

Global $sMyCLSID = "AutoIt.ServerChecker"
Global $sMyCLSID2 = "AutoIt.ServerCheckerList"

Global $oError = ObjEvent("AutoIt.Error", "_ErrFunc")
Func _ErrFunc()
	If $CmdLine[0] > 1 And $CmdLine[1] = "/ServerScanner" Then
		Local $oObj = ObjGet($sMyCLSID & "." & $CmdLine[2])
		$oObj.Log("COM Error, ScriptLine(" & $oError.scriptline & ") : Number 0x" & Hex($oError.number, 8) & " - " & $oError.windescription)
	Else
		ConsoleWrite("COM Error, ScriptLine(" & $oError.scriptline & ") : Number 0x" & Hex($oError.number, 8) & " - " & $oError.windescription & @CRLF)
	EndIf

	Exit
EndFunc

If $CmdLine[0] > 1 And $CmdLine[1] = "/ServerScanner" Then
	_ServerScanner()
EndIf


_GDIPlus_Startup()
_AutoItObject_StartUp()

Global $hBitmap, $hImage, $hGraphic
$hBitmap = _WinAPI_CreateSolidBitmap(0, 0xFFFFFF, 16, 16)
$hImage = _GDIPlus_BitmapCreateFromHBITMAP($hBitmap)
$hGraphic = _GDIPlus_ImageGetGraphicsContext($hImage)

Global Const $AUT_WM_NOTIFYICON = $WM_USER + 1 ; Application.h
Global Const $AUT_NOTIFY_ICON_ID = 1 ; Application.h

AutoItWinSetTitle("AutoIt window with hopefully a unique title|Ketchup")
Global $TRAY_ICON_GUI = WinGetHandle(AutoItWinGetTitle()) ; Internal AutoIt GUI


Global $iPid, $iServerCount = 0, $iServerTray = ChrW(8734), $sUpdateLink, $avPopups[1][5], $asServerPlayers[1][3], $iListviewFlag = False, $iListviewIndex, $iSkipLabelProc = False, $asServerInfo[1][2]

;Main GUI
Global $hGui, $iGuiY, $aiGuiMin
;Settings GUI
Global $hSettingsGui
;Naughty cat GUI
Global $hNaughtyCatGui
;Controls
Global $idIP, $idAdd, $idScanNow
Global $idServers, $idServerDelete, $idServerShowPopup, $idServerMenuAuto, $idServerMenuOld, $idServerMenuTrue, $idServerMenuNew
Global $cIdHints, $cIdSettings, $idPopupDummy
Global $idServerImage, $idServerProtocol, $idServerPlayers, $idDeleteAvatars
Global $idSeconds, $cIdTimeout, $hTimeout
Global $idFlashWin
Global $idColorizeListview, $hColorizeListview, $idCountTray, $hCountTray, $idCheckForUpdate
Global $cIdNaughtyCat
;Objects
Global $oServers
;Hint-ticker-thing
Global $asHint[] = [0, "Hint 1: Check items to include in scan", "Hint 2: Rightclick item to delete and stuff"]
;Imagelist
Global $idServerPlayersImageListDuplicate, $iListNew, $iListError, $iListDefault
;Inet
Global $aInet


_GUICreate()


GUISetState(@SW_SHOW, $hGui)
GUIRegisterMsg($WM_NOTIFY, "_WM_NOTIFY")
GUIRegisterMsg($WM_COMMAND, "_WM_COMMAND")
GUIRegisterMsg($WM_GETMINMAXINFO, "_WM_GETMINMAXINFO")
OnAutoItExitRegister("_Quitting")

Global $oObject = _ServerObject()
_AutoItObject_RegisterObject($oObject, $sMyCLSID & "." & @AutoItPID)
_AutoItObject_RegisterObject($oServers, $sMyCLSID2 & "." & @AutoItPID)

If IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "LoggingLevel", "MyVeryRandomString") = "MyVeryRandomString" Then
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "LoggingLevel", "Unknown")
EndIf
_AvatarsDelete()

AdlibRegister("_ServerCheck")

_GUIMainLoop()

#Region   ;Server bars

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
	GUISetState(@SW_SHOW, $avPopups[UBound($avPopups) -1][0])

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

#EndRegion

#Region   ;Network stuff

Func _ServerCheck()
	For $iX = 0 To UBound($asServerInfo) -1
		_WinAPI_DeleteObject($asServerInfo[0][1])
	Next
	Global $asServerPlayers[1][3], $asServerInfo[1][2]

	AdlibUnRegister("_ScanningCrashedReset")
	AdlibUnRegister("_ServerCheck")
	AdlibUnRegister("_HintAdd")
	GUICtrlSetData($idScanNow, "Scanning under way")
	GUICtrlSetState($idScanNow, $GUI_DISABLE)
	AdlibRegister("_WorkingAnimation")
	If $asHint[0] <> -1 Then AdlibRegister("_HintRemove", 20)

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
	Local $iSocket, $iFakePort
	Local $oObj = ObjGet($sMyCLSID & "." & $CmdLine[2])
	Local $oList = ObjGet($sMyCLSID2 & "." & $CmdLine[2])

	$avList = $oList.Enabled()

	TCPStartup()

	$iTimeoutSeconds = Int(IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "TimeoutSeconds", "HamburgareIsTasty"))
	If $iTimeoutSeconds = 0 Then $iTimeoutSeconds = 10
	Local $iTimeoutMS = $iTimeoutSeconds * 1000

	For $iY = 0 To UBound($avList) -1
		If $avList[$iY][$eProtocol] < $eProtocolAuto Or $avList[$iY][$eProtocol] >= $eProtocolMax Then
			$oObj.Log("Possible corruption in Servers.dat; unknown protocol (" & $avList[$iY][$eProtocol] & ") for " & $avList[$iY][$eServer] & ":" & $avList[$iY][$ePort])
			ContinueLoop
		EndIf

		$iFakePort = False

		If $avList[$iY][$ePort] = "" Then
			If IsArray($avList[$iY][$eSRVData]) Then
				$avTemp = $avList[$iY][$eSRVData]
				$avList[$iY][$ePort] = $avTemp[0][2]
				$iFakePort = True
			Else
				$avSRV = SRVRecords("_minecraft._tcp." & $avList[$iY][$eServer])

				For $iX = 0 To UBound($avSRV) - 1
					$oObj.Log("SRV Priority:" & $avSRV[$iX][0] & " Weight:" & $avSRV[$iX][1] & " Port:" & $avSRV[$iX][2] & " Target:" & $avSRV[$iX][3])
				Next

				If IsArray($avSRV) Then
					$oList.SetSRVData($avList[$iY][$eServer], $avList[$iY][$ePort], $avSRV)
					$avList[$iY][$ePort] = $avSRV[0][2]
				Else
					$avList[$iY][$ePort] = $iDefaultPort
				EndIf
				$iFakePort = True
			EndIf
		EndIf

		If StringIsDigit(StringReplace($avList[$iY][$eServer], ".", "")) Then
			$iSocket = _TCPConnect($avList[$iY][$eServer], $avList[$iY][$ePort], $iTimeoutMS)
		Else
			$iSocket = _TCPConnect(TCPNameToIP($avList[$iY][$eServer]), $avList[$iY][$ePort], $iTimeoutMS)
		EndIf
		$oObj.Log("Connecting to " & $avList[$iY][$eServer] & ":" & $avList[$iY][$ePort] & " /Socket=" & $iSocket & " /Error=" & @error)

		If $iFakePort Then $avList[$iY][$ePort] = ""

		If $avList[$iY][$eProtocol] = $eProtocolAuto Then
			$avList[$iY][$eProtocolCurrent] -= 1
			If $avList[$iY][$eProtocolCurrent] < $eProtocol1 Then $avList[$iY][$eProtocolCurrent] = $eProtocolMax -1

			$oList.SetProtocolCurrent($avList[$iY][$eServer], $avList[$iY][$ePort], $avList[$iY][$eProtocolCurrent])
		EndIf

		If $avList[$iY][$eProtocol] = $eProtocol1 Or $avList[$iY][$eProtocolCurrent] = $eProtocol1 Then   ;pre 1.4 protocol
			$oObj.Log("pre 1.4 protocol")
			TCPSend($iSocket, Binary("0xFE"))
		ElseIf $avList[$iY][$eProtocol] = $eProtocol3 Or $avList[$iY][$eProtocolCurrent] = $eProtocol3 Then   ;1.7+ protocol
			$oObj.Log("1.7+ protocol")
			$bTemp = Binary("0x0004" & Hex(BinaryLen($avList[$iY][$eServer]), 2)) & Binary($avList[$iY][$eServer]) & Hex($avList[$iY][$ePort], 4) & "01" & "0100"
			$bTemp = Binary("0x" & Hex(BinaryLen($bTemp) -2, 2)) & StringTrimLeft($bTemp, 2)
			;first byte (0x!0E!0004) should be total length
			$bHandshake = Binary("0x0E0004" & Hex(BinaryLen($avList[$iY][$eServer]), 2)) & Binary($avList[$iY][$eServer]) & Hex($avList[$iY][$ePort], 4) & "01"
			$bRequest = "0100"
			TCPSend($iSocket, $bTemp)
		ElseIf $avList[$iY][$eProtocol] = $eProtocol2 Or $avList[$iY][$eProtocolCurrent] = $eProtocol2 Then   ;1.4 - 1.7 protocol
			$oObj.Log("1.4 - 1.7 protocol")
			TCPSend($iSocket, Binary("0xFE01"))
		EndIf

		While 1
			While 1
				Sleep(500)
				$dRet = TCPRecv($iSocket, 1500, 1)
				$error = @error
				$oObj.Log("TCPRecv @error: " & $error)
				If $error <> 0 Then
					TCPCloseSocket($iSocket)
					ExitLoop
				EndIf

				If $dRet <> "" Then

					If $avList[$iY][$eProtocol] = $eProtocol3 Or $avList[$iY][$eProtocolCurrent] = $eProtocol3 Then   ;1.7+ protocol

						Do
							Sleep(100)
							Local $dContinued = TCPRecv($iSocket, 65536, 1)
							$dRet &= $dContinued
							$error = @error
							$oObj.Log("TCPRecv @error: " & $error)
						Until $error <> 0 Or $dContinued = ""

						$oObj.Log("JSON START")
						$oObj.Log(BinaryToString(BinaryMid($dRet, StringInStr($dRet, "7B") / 2), 4))
						$oObj.Log("JSON END")

						$oJSON = Jsmn_Decode(BinaryToString(BinaryMid($dRet, StringInStr($dRet, "7B") / 2), 4))

						$vDescription = Jsmn_ObjGet($oJSON, "description")
						Local $sDescription = ""
						If IsObj($vDescription) Then
							If Jsmn_ObjExists($vDescription, "extra") Then
								$aoExtra = Jsmn_ObjGet($vDescription, "extra")
								For $iX = 0 To UBound($aoExtra) -1
									$sDescription &= Jsmn_ObjGet($aoExtra[$iX], "text")
								Next
							EndIf
							$sDescription &= Jsmn_ObjGet($vDescription, "text")
						Else
							$sDescription &= $vDescription
						EndIf
						$sDescription = StringStripWS($sDescription, $STR_STRIPLEADING + $STR_STRIPTRAILING + $STR_STRIPSPACES)

						$oVersion = Jsmn_ObjGet($oJSON, "version")
						$sVersionName = Jsmn_ObjGet($oVersion, "name")
						$iVersionProtocol = Jsmn_ObjGet($oVersion, "protocol")

						$oPlayers = Jsmn_ObjGet($oJSON, "players")
						$iPlayersMax = Jsmn_ObjGet($oPlayers, "max")
						$iPlayersOnline = Jsmn_ObjGet($oPlayers, "online")

						If Jsmn_ObjExists($oPlayers, "sample") Then
							$aoSample = Jsmn_ObjGet($oPlayers, "sample")
							If UBound($aoSample) >= 1 Then
								Local $asPlayers[UBound($aoSample)][2]
								For $iX = 0 To UBound($aoSample) -1
									$asPlayers[$iX][0] = Jsmn_ObjGet($aoSample[$iX], "name")
									$asPlayers[$iX][1] = Jsmn_ObjGet($aoSample[$iX], "id")
								Next
								$oObj.Player($avList[$iY][$eServer], $avList[$iY][$ePort], $asPlayers)
							EndIf
						EndIf

						If Jsmn_ObjExists($oJSON, "modinfo") Then
							Local $oModinfo = Jsmn_ObjGet($oJSON, "modinfo")
							Local $oModinfoType = Jsmn_ObjGet($oModinfo, "type")

							Local $aoModList = Jsmn_ObjGet($oModinfo, "modList")
							If UBound($aoModList) >= 1 Then
								Local $asMods[UBound($aoModList)][2]
								For $iX = 0 To UBound($aoModList) -1
									$asMods[$iX][0] = Jsmn_ObjGet($aoModList[$iX], "modid")
									$asMods[$iX][1] = Jsmn_ObjGet($aoModList[$iX], "version")
								Next
								$oObj.Mod($avList[$iY][$eServer], $avList[$iY][$ePort], $oModinfoType, $asMods)
							EndIf
						EndIf

						If Jsmn_ObjExists($oJSON, "favicon") Then
							$sFavicon = Jsmn_ObjGet($oJSON, "favicon")
							$dPng = _B64Decode(StringStripWS(StringTrimLeft($sFavicon, StringInStr($sFavicon, ",")), $STR_STRIPALL))
							$oObj.Icon($avList[$iY][$eServer], $avList[$iY][$ePort], $dPng)
						EndIf

						;Server online (1.7+ protocol)
						$oObj.Results($avList[$iY][$eServer], $avList[$iY][$ePort], $sVersionName, $sDescription, $iPlayersOnline, $iPlayersMax, $iVersionProtocol)
						If $avList[$iY][$eProtocol] = $eProtocolAuto Then $oList.SetProtocol($avList[$iY][$eServer], $avList[$iY][$ePort], $eProtocol3)
						TCPCloseSocket($iSocket)
						ExitLoop 2
					Else   ;Pre 1.7 protocols
						$aRet = StringSplit(BinaryToString(BinaryMid($dRet, 4), 3), Chr(0))

						If UBound($aRet) = 7 Then   ;1.4 - 1.7 protocol
							$oObj.Results($avList[$iY][$eServer], $avList[$iY][$ePort], $aRet[3], $aRet[4], $aRet[5], $aRet[6], $aRet[2])   ;Server online (1.4 - 1.7 protocol)
							If StringReplace($aRet[3], ".", "") >= 170 Then
								$oList.SetProtocol($avList[$iY][$eServer], $avList[$iY][$ePort], $eProtocol3)
							ElseIf $avList[$iY][$eProtocol] = $eProtocolAuto Then
								$oList.SetProtocol($avList[$iY][$eServer], $avList[$iY][$ePort], $eProtocol2)
							EndIf
						Else   ;pre 1.4 protocol
							$aRet = StringSplit(BinaryToString(BinaryMid($dRet, 4), 3), "§")
							If UBound($aRet) = 4 Then
								$oObj.Results($avList[$iY][$eServer], $avList[$iY][$ePort], "1.3 or older", $aRet[1], $aRet[2], $aRet[3], "")   ;Server online (pre 1.4 protocol)
								Switch $avList[$iY][$eProtocol]
									Case $eProtocol2, $eProtocolAuto
										$oList.SetProtocol($avList[$iY][$eServer], $avList[$iY][$ePort], $eProtocol1)
								EndSwitch
							Else
								$oObj.Log("Error")
								$oObj.Results($avList[$iY][$eServer], $avList[$iY][$ePort], "Error", "Error", "Error", "Error", "Error")   ;Error
							EndIf
						EndIf

						TCPCloseSocket($iSocket)
						ExitLoop 2
					EndIf
				EndIf
			WEnd

			$oObj.Log("Offline")
			$oObj.Results($avList[$iY][$eServer], $avList[$iY][$ePort], "", "", "", "", "")   ;Server offline
			ExitLoop
		WEnd
	Next

	TCPShutdown()
	$oObj.Finished()

	Exit
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

#EndRegion

#Region   ;ServerObject

Func _ServerObject()
    Local $oClassObject = _AutoItObject_Class()
    $oClassObject.AddMethod("Mod", "_ServerMod")
    $oClassObject.AddMethod("Log", "_ServerLog")
    $oClassObject.AddMethod("Player", "_ServerPlayer")
	$oClassObject.AddMethod("Icon", "_ServerIcon")
    $oClassObject.AddMethod("Results", "_ServerResults")
    $oClassObject.AddMethod("Finished", "_ServerFinished")
    Return $oClassObject.Object
EndFunc   ;==>_ServerObject

Func _ServerMod($oSelf, $sServerAddress, $iServerPort, $sType, $asMods)
	_Log("_ServerMod: Type " & $sType)

	Local $iLength = 0
	For $iX = 0 To UBound($asMods) -1
		If StringLen($asMods[$iX][0]) > $iLength Then $iLength = StringLen($asMods[$iX][0])
	Next

	For $iX = 0 To UBound($asMods) -1
		_Log("ModId=" & StringFormat("%-" & $iLength & "s", $asMods[$iX][0]) & " Version=" & $asMods[$iX][1])
	Next
EndFunc

Func _ServerLog($oSelf, $sMessage)
	_Log($sMessage)
EndFunc

Func _ServerPlayer($oSelf, $sServerAddress, $iServerPort, $asPlayers)
	Local $iUBound = UBound($asServerPlayers)
	ReDim $asServerPlayers[$iUBound + UBound($asPlayers)][3]

	Local $iLength = 0
	For $iX = 0 To UBound($asPlayers) -1
		If StringLen($asPlayers[$iX][0]) > $iLength Then $iLength = StringLen($asPlayers[$iX][0])
	Next

	For $iX = 0 To UBound($asPlayers) -1
		_Log("Name=" & StringFormat("%-" & $iLength & "s", $asPlayers[$iX][0]) & " ID=" & $asPlayers[$iX][1])
		$asServerPlayers[$iUBound - 1 + $iX][0] = $sServerAddress & ":" & $iServerPort
		$asServerPlayers[$iUBound - 1 + $iX][1] = $asPlayers[$iX][0]
		$asServerPlayers[$iUBound - 1 + $iX][2] = $asPlayers[$iX][1]
	Next
EndFunc

Func _ServerIcon($oSelf, $sServerAddress, $iServerPort, $dIcon)
	_Log("_ServerIcon: " & BinaryLen($dIcon))

	Local $hBitmap = _GDIPlus_BitmapCreateFromMemory($dIcon)
	Local $hHBmp = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBitmap)
	_GDIPlus_BitmapDispose($hBitmap)

	Local $iUBound = UBound($asServerInfo)
	ReDim $asServerInfo[$iUBound +1][2]
	$asServerInfo[$iUBound][0] = $sServerAddress & ":" & $iServerPort
	$asServerInfo[$iUBound][1] = $hHBmp
EndFunc

Func _ServerResults($oSelf, $sServerAddress, $iServerPort, $sVersion, $sMOTD, $iCurrentPlayers, $iMaxPlayers, $iProtocol)
	_MCStringClean($sMOTD)

	If $iProtocol <> "" And $iProtocol <> "Error" Then _Log("_ServerResults: Version=" & $sVersion & " Protocol=" & $iProtocol & " Players=" & $iCurrentPlayers & "/" & $iMaxPlayers & " MOTD=" & $sMOTD)

	Local $iIndex = -1
	While 1
		$iIndex = _GUICtrlListView_FindText($idServers, $sServerAddress, $iIndex, False, False)
		If $iIndex <> -1 Then
			If _GUICtrlListView_GetItemText($idServers, $iIndex, 1) = $iServerPort Then
				_GUICtrlListView_SetItemText($idServers, $iIndex, $sVersion, 2)
				If $iCurrentPlayers == "" Then
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

				_GUICtrlListView_SetColumnWidth($idServers, 2, $LVSCW_AUTOSIZE_USEHEADER)
				_GUICtrlListView_SetColumnWidth($idServers, 4, $LVSCW_AUTOSIZE_USEHEADER)

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
		If $iCurrentPlayers == "" Then
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

	_Log("")
EndFunc

Func _ServerFinished($oSelf)
	AdlibUnRegister("_WorkingAnimation")
	$iServerTray = $iServerCount
	$iServerCount = 0
	If _GUICtrlButton_GetCheck($idCountTray) = $BST_CHECKED Then _TraySet($iServerTray)
	AdlibRegister("_ServerCheck", GUICtrlRead($idSeconds) * 1000)
	GUICtrlSetData($idScanNow, "Scan now")
	GUICtrlSetState($idScanNow, $GUI_ENABLE)
EndFunc

#EndRegion

#Region   ;Serverlist

Func _Servers()
	Local $avServers[0][0]

    Local $oClassObject = _AutoItObject_Class()
	$oClassObject.AddProperty("List", $ELSCOPE_READONLY, $avServers)
    $oClassObject.AddMethod("ConvertINI", "_ServersConvertINI")
	$oClassObject.AddMethod("Add", "_ServersAdd")
	$oClassObject.AddMethod("Delete", "_ServersDelete")
    $oClassObject.AddMethod("Load", "_ServersLoad")
    $oClassObject.AddMethod("Save", "_ServersSave")
    $oClassObject.AddMethod("SetEnabled", "_ServersSetEnabled")
    $oClassObject.AddMethod("SetProtocol", "_ServersSetProtocol")
	$oClassObject.AddMethod("SetProtocolCurrent", "_ServersSetProtocolCurrent")
	$oClassObject.AddMethod("SetSRVData", "_ServersSetSRVData")
    $oClassObject.AddMethod("Enabled", "_ServersEnabled")

    Return $oClassObject.Object
EndFunc   ;==>_Servers

Func _ServersConvertINI($oSelf)
	Local $asServers = IniReadSectionNames(@ScriptDir & "\Servers.ini")
	If @error Then Return
	For $iX = 1 To $asServers[0]
		Local $asPorts = IniReadSection(@ScriptDir & "\Servers.ini", $asServers[$iX])
		If @error Then ContinueLoop
		For $iY = 1 To $asPorts[0][0]
			Local $avStuff = _IniServerStuffToServerlistStuff($asPorts[$iY][1])
			$oSelf.Add($asServers[$iX], $asPorts[$iY][0], $avStuff[0], $avStuff[1])
		Next
	Next

	If UBound($oSelf.List) > 0 Then
		Local $avTemp = $oSelf.List

		Pickle($avTemp, @ScriptDir & "\Servers.dat")
		FileMove(@ScriptDir & "\Servers.ini", @ScriptDir & "\Servers_old.ini")
	EndIf
EndFunc

Func _ServersAdd($oSelf, $sServer, $sPort, $bEnabled, $sProtocol)
	Local $avList = $oSelf.List, $iUBound = UBound($avList)
	ReDim $avList[$iUBound +1][$eServerlistMaxCol]
	$avList[$iUBound][$eServer] = $sServer
	$avList[$iUBound][$ePort] = $sPort
	$avList[$iUBound][$eEnabled] = $bEnabled
	$avList[$iUBound][$eProtocol] = $sProtocol

	$oSelf.List = $avList
EndFunc

Func _ServersDelete($oSelf, $sServer, $sPort)
	Local $avList = $oSelf.List

	For $iX = 0 To UBound($avList) -1
		If $avList[$iX][$eServer] = $sServer And $avList[$iX][$ePort] = $sPort Then
			_ArrayDelete($avList, $iX)
			ExitLoop
		EndIf
	Next

	$oSelf.List = $avList
EndFunc

Func _ServersLoad($oSelf)
	If UBound($oSelf.List) = 0 And FileExists(@ScriptDir & "\Servers.dat") Then
		$avTemp = LoadPickle(@ScriptDir & "\Servers.dat")
		If $avTemp = 0 Then Return
		$oSelf.List = $avTemp
	EndIf

	Local $avList = $oSelf.List
	ReDim $avList[UBound($avList)][$eServerlistMaxCol]
	$oSelf.List = $avList
EndFunc

Func _ServersSave($oSelf)
	$avTemp = $oSelf.List
	ReDim $avTemp[UBound($avTemp)][4]
	Pickle($avTemp, @ScriptDir & "\Servers.dat")
EndFunc

Func _ServersSetEnabled($oSelf, $sServer, $sPort, $bEnabled)
	For $iX = 0 To UBound($oSelf.List) -1
		If $oSelf.List[$iX][$eServer] = $sServer And $oSelf.List[$iX][$ePort] = $sPort Then
			$avList = $oSelf.List
			$avList[$iX][$eEnabled] = $bEnabled
			$oSelf.List = $avList
			ExitLoop
		EndIf
	Next
EndFunc

Func _ServersSetProtocol($oSelf, $sServer, $sPort, $sProtocol)
	For $iX = 0 To UBound($oSelf.List) -1
		If $oSelf.List[$iX][$eServer] = $sServer And $oSelf.List[$iX][$ePort] = $sPort Then
			$avList = $oSelf.List
			$avList[$iX][$eProtocol] = $sProtocol
			$oSelf.List = $avList
			ExitLoop
		EndIf
	Next
EndFunc

Func _ServersSetProtocolCurrent($oSelf, $sServer, $sPort, $sProtocolCurrent)
	For $iX = 0 To UBound($oSelf.List) -1
		If $oSelf.List[$iX][$eServer] = $sServer And $oSelf.List[$iX][$ePort] = $sPort Then
			$avList = $oSelf.List
			$avList[$iX][$eProtocolCurrent] = $sProtocolCurrent
			$oSelf.List = $avList
			ExitLoop
		EndIf
	Next
EndFunc

Func _ServersSetSRVData($oSelf, $sServer, $sPort, $avTemp)
	For $iX = 0 To UBound($oSelf.List) -1
		If $oSelf.List[$iX][$eServer] = $sServer And $oSelf.List[$iX][$ePort] = $sPort Then
			$avList = $oSelf.List
			$avList[$iX][$eSRVData] = $avTemp
			$oSelf.List = $avList
			ExitLoop
		EndIf
	Next
EndFunc

Func _ServersEnabled($oSelf)
	Local $asRet = $oSelf.List

	For $iX = UBound($asRet) -1 To 0 Step -1
		If Not $asRet[$iX][$eEnabled] Then
			_ArrayDelete($asRet, $iX)
		EndIf
	Next

	Return $asRet
EndFunc

Func _IniServerStuffToServerlistStuff($sText)
	Switch $sText
		Case "False"
			Local $avRet[2] = [False, $eProtocolAuto]
		Case "Old"
			Local $avRet[2] = [True, $eProtocol1]
		Case "True"
			Local $avRet[2] = [True, $eProtocol2]
		Case "New"
			Local $avRet[2] = [True, $eProtocol3]
		Case Else
			_Log("Servers.ini either corrupted or manually edited by a schmuck")
	EndSwitch

	Return $avRet
EndFunc

#EndRegion

#Region   ;GUI

Func _GUICreate()
	Local $iGuiX = 832
	$iGuiY = 480

	$hGui = GUICreate(StringTrimRight(@ScriptName, 4), $iGuiX, $iGuiY, -1, -1)

	$aiGuiMin = WinGetPos($hGui)


	GUICtrlCreateGroup("Add server", 5, 5, 375, 70)
	$idIP = GUICtrlCreateInput("", 20, 30, 290, 25)
	GUICtrlSendMsg($idIP, $EM_SETCUEBANNER, True, "Server address")
	GUICtrlSetTip(-1, "Accepts all formats Minecraft understands")
	$idAdd = GUICtrlCreateButton("Add", 320, 30, 50, 25)

	GUICtrlCreateGroup("Scan", 390, 5, 215, 70)
	$idScanNow = GUICtrlCreateButton("Scan now", 400, 30, 150, 25)


	$idServers = GUICtrlCreateListView("Server Address|Port|Version|Players|MOTD", 5, 80, 600, $iGuiY - 125, $LVS_SHOWSELALWAYS, BitOR($LVS_EX_CHECKBOXES, $LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_INFOTIP))
	Local $idServerContext = GUICtrlCreateContextMenu($idServers)
	$idServerDelete = GUICtrlCreateMenuItem("Delete selected server(s)", $idServerContext)
	$idServerShowPopup = GUICtrlCreateMenuItem("Show server bar", $idServerContext)
	GUICtrlCreateMenuItem("", $idServerContext)
	GUICtrlCreateMenuItem("Select protocol:", $idServerContext)
	GUICtrlSetState(-1, $GUI_DISABLE)
	$idServerMenuAuto = GUICtrlCreateMenuItem("Find for me (might require multiple scans)", $idServerContext, -1, 1)
	$idServerMenuOld = GUICtrlCreateMenuItem("Beta 1.8 to 1.3", $idServerContext, -1, 1)
	$idServerMenuTrue = GUICtrlCreateMenuItem("1.4 to 1.6", $idServerContext, -1, 1)
	$idServerMenuNew = GUICtrlCreateMenuItem("1.7 and later", $idServerContext, -1, 1)

	_IniClean()

	$oServers = _Servers()
	$oServers.ConvertINI()
	$oServers.Load()

	For $iX = 0 To UBound($oServers.List) -1
		GUICtrlCreateListViewItem($oServers.List[$iX][$eServer] & "|" & $oServers.List[$iX][$ePort], $idServers)
		GUICtrlSetBkColor(-1, 0xFFFFFF)
		GUICtrlSetColor(-1, 0)
		If $oServers.List[$iX][$eEnabled] Then _GUICtrlListView_SetItemChecked($idServers, _GUICtrlListView_GetItemCount($idServers) -1)
	Next

	If _GUICtrlListView_GetItemCount($idServers) > 0 Then
		_GUICtrlListView_SetColumnWidth($idServers, 0, $LVSCW_AUTOSIZE)
		_GUICtrlListView_SetColumnWidth($idServers, 1, $LVSCW_AUTOSIZE_USEHEADER)
	EndIf


	Local $sSecondsBetweenScans
	Local $sMinutesBetweenScans = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "MinutesBetweenScans", "IsglassIsTasty")
	If $sMinutesBetweenScans <> "IsglassIsTasty" Then
		$sSecondsBetweenScans = $sMinutesBetweenScans * 60
		IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "SecondsBetweenScans", $sSecondsBetweenScans)
		IniDelete(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "MinutesBetweenScans")
	EndIf

	$cIdHints = GUICtrlCreateLabel("Welcome!!", 10, $iGuiY - 35, 485, 25, $SS_CENTERIMAGE)

	$cIdSettings = GUICtrlCreateCheckbox("Settings " & ChrW(0x25B2), 500, $iGuiY - 35, 105, 25, $BS_PUSHLIKE)
	Local $hSettingsImageList = _GUIImageList_Create(32, 32, 5, 3, 1)
	If @Compiled Then
		_ImageList_AddImageFromResource($hSettingsImageList, "SETTINGS")
	Else
		_ImageList_AddImage($hSettingsImageList, @ScriptDir & "\cog.png")
	EndIf
	_GUICtrlButton_SetImageList($cIdSettings, $hSettingsImageList, 0)

	$idPopupDummy = GUICtrlCreateDummy()


	GUICtrlCreateGroup("1.7+ only", 615, 5, 207, $iGuiY - 15)

	$idServerImage = GUICtrlCreatePic("", 625, 25, 64, 64)
	If @Compiled Then
		Local $hBmp = _GDIPlus_BitmapCreateFromMemory(Binary(_ResourceGetAsRaw(@ScriptFullPath, 10, "SERVER_DEFAULT")), True)
		_WinAPI_DeleteObject(GUICtrlSendMsg($idServerImage, 0x0172, 0, $hBmp))
		_WinAPI_DeleteObject($hBmp)
	Else
		GUICtrlSetImage($idServerImage, @ScriptDir & "\Svartnos.jpg")
	EndIf

	$idServerProtocol = GUICtrlCreateLabel("Protocol= to be implemented", 725, 25, 85, 64, $BS_MULTILINE)
	GUICtrlSetState(-1, $GUI_HIDE)

	$idServerPlayers = GUICtrlCreateListView("Name", 625, 95, $iGuiX - 645, $iGuiY - 115, BitOR($LVS_SHOWSELALWAYS, $LVS_NOCOLUMNHEADER), BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_GRIDLINES, $LVS_EX_INFOTIP))
	_GUICtrlListView_SetExtendedListViewStyle($idServerPlayers, $LVS_EX_ONECLICKACTIVATE, $LVS_EX_ONECLICKACTIVATE)
	Local $idServerPlayersImageList = _GUIImageList_Create(32, 32)
	If @Compiled Then
		$iListNew = _ImageList_AddImageFromResource($idServerPlayersImageList, "AVATAR_WAIT")
		$iListError = _ImageList_AddImageFromResource($idServerPlayersImageList, "AVATAR_ERROR")
		$iListDefault = _ImageList_AddImageFromResource($idServerPlayersImageList, "AVATAR_DEFAULT")
	Else
		$iListNew = _ImageList_AddImage($idServerPlayersImageList, @ScriptDir & "\PleaseWait.png")
		$iListError = _ImageList_AddImage($idServerPlayersImageList, @ScriptDir & "\Error.png")
		$iListDefault = _ImageList_AddImage($idServerPlayersImageList, @ScriptDir & "\Default3.png")
	EndIf
	$idServerPlayersImageListDuplicate = _GUIImageList_Duplicate($idServerPlayersImageList)
	_GUICtrlListView_SetImageList($idServerPlayers, $idServerPlayersImageList, 0)
	_GUICtrlListView_SetView($idServerPlayers, 1)

	$idDeleteAvatars = GUICtrlCreateButton("Delete cached avatars", 655, $iGuiY - 45, $iGuiX - 675, 25)
	GUICtrlSetState(-1, $GUI_HIDE)


	Local $asSettingsSize[] = [200, 235]
	$hSettingsGui = GUICreate(StringTrimRight(@ScriptName, 4), $asSettingsSize[0], $asSettingsSize[1], 440, 205, BitOR($WS_POPUP, $WS_BORDER), $WS_EX_MDICHILD, $hGui)


	GUICtrlCreateGroup("Scan", 5, 5, $asSettingsSize[0] -10, 75)

	GUICtrlCreateLabel("Timer", 15, 20, 50, 25, $SS_CENTERIMAGE)
	$idSeconds = GUICtrlCreateCombo("", 70, 20, 50, 25)
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
		GUICtrlSetData(-1, $sCombo, 60)
	EndIf
	GUICtrlCreateLabel("(Seconds)", 130, 20, 60, 25, $SS_CENTERIMAGE)

	GUICtrlCreateLabel("Timeout", 15, 50, 50, 25, $SS_CENTERIMAGE)
	$cIdTimeout = GUICtrlCreateCombo("", 70, 50, 50, 25)
	$hTimeout = GUICtrlGetHandle(-1)
	Local $iTimeoutSeconds = Int(IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "TimeoutSeconds", "HamburgareIsTasty"))
	If $iTimeoutSeconds Then
		GUICtrlSetData(-1, $iTimeoutSeconds, $iTimeoutSeconds)
	Else
		GUICtrlSetData(-1, 10, 10)
	EndIf
	GUICtrlCreateLabel("(Seconds)", 130, 50, 60, 25, $SS_CENTERIMAGE)


	GUICtrlCreateGroup("When server goes online", 5, 85, $asSettingsSize[0] -10, 60)

	$idFlashWin = GUICtrlCreateCheckbox("Flash window", 15, 100, $asSettingsSize[0] -30, 20)
	Local $sFlashWindow = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "FlashWindow", "PizzaIsTasty")
	If $sFlashWindow = "1" Or $sFlashWindow = "PizzaIsTasty" Then GUICtrlSetState(-1, $GUI_CHECKED)

	GUICtrlCreateCheckbox("Notify in tray bar", 15, 120, $asSettingsSize[0] -30, 20)
	GUICtrlSetState(-1, $GUI_HIDE)


	GUICtrlCreateGroup("Misc", 5, 150, $asSettingsSize[0] -10, 80)

	$idColorizeListview = GUICtrlCreateCheckbox("Colorize listview", 15, 165, $asSettingsSize[0] -30, 20)
	$hColorizeListview = GUICtrlGetHandle(-1)
	Local $sColorizeListview = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "ColorizeListview", "MatIsTasty")
	If $sColorizeListview = "1" Or $sColorizeListview = "MatIsTasty" Then GUICtrlSetState(-1, $GUI_CHECKED)

	$idCountTray = GUICtrlCreateCheckbox("Count in tray icon", 15, 185, $asSettingsSize[0] -30, 20)
	$hCountTray = GUICtrlGetHandle(-1)
	Local $sCountTray = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "CountTray", "JulmustIsTasty")
	If $sCountTray = "1" Or $sCountTray = "JulmustIsTasty" Then
		GUICtrlSetState(-1, $GUI_CHECKED)
		Opt("TrayIconHide", 0)
		_TraySet($iServerTray)
	EndIf

	$idCheckForUpdate = GUICtrlCreateCheckbox("Check for updates", 15, 205, $asSettingsSize[0] -30, 20)
	Local $sCheckForUpdate = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "CheckForUpdate", "K" & Chr(0xF6) & "ttbullarIsTasty")
	If $sCheckForUpdate = "1" Or $sCheckForUpdate = "K" & Chr(0xF6) & "ttbullarIsTasty" Then
		GUICtrlSetState(-1, $GUI_CHECKED)
		$aInet = InetGet("https://dl.dropbox.com/u/18344147/SoftwareUpdates/MSPC.txt", @TempDir & "\MSPC.txt", 1 + 2 + 16, 1)
		AdlibRegister("_CheckForUpdateMaster", 100)
		$asHint[0] = -1
	EndIf


	Local $iNaughtyCatX = 290, $iNaughtyCatY = 340

	$hNaughtyCatGui = GUICreate("Naughty - " & StringTrimRight(@ScriptName, 4), $iNaughtyCatX, $iNaughtyCatY, $iGuiX / 2 - $iNaughtyCatX / 2, $iGuiY / 2 - $iNaughtyCatY / 2, BitOR($WS_POPUP, $WS_BORDER), $WS_EX_MDICHILD, $hGui)

	$cIdNaughtyCat = GUICtrlCreatePic("", 0, 0, $iNaughtyCatX, $iNaughtyCatY)
	If @Compiled Then
		Local $hBmp = _GDIPlus_BitmapCreateFromMemory(Binary(_ResourceGetAsRaw(@ScriptFullPath, 10, "NAUGHTY_CAT")), True)
		_WinAPI_DeleteObject(GUICtrlSendMsg(-1, 0x0172, 0, $hBmp))
		_WinAPI_DeleteObject($hBmp)
	Else
		GUICtrlSetImage(-1, @ScriptDir & "\svartnos_tunga.jpg")
	EndIf
EndFunc

Func _GUIMainLoop()
	While 1
		Local $iMessage = GUIGetMsg(1)
		Switch $iMessage[0]
			Case $GUI_EVENT_CLOSE
				For $iX = 1 To UBound($avPopups) -1
					_WinAPI_SetWindowLong(GUICtrlGetHandle($avPopups[$iX][4]), $GWL_WNDPROC, $avPopups[$iX][3])
					DllCallbackFree($avPopups[$iX][2])
				Next
				Exit
			Case $GUI_EVENT_PRIMARYDOWN
				If _GUICtrlButton_GetCheck($cIdSettings) = $GUI_CHECKED And _WinAPI_PtInRectEx($iMessage[3], $iMessage[4], 500, $iGuiY - 35, 605, $iGuiY - 10) = 0 And $iMessage[1] = $hGui Then
					GUICtrlSetData($cIdSettings, "Settings " & ChrW(0x25B2))
					GUISetState(@SW_HIDE, $hSettingsGui)
					_GUICtrlButton_SetCheck($cIdSettings, $BST_UNCHECKED)
				EndIf
			Case $idAdd
				Local $asAddress = StringSplit(GUICtrlRead($idIP), ":", $STR_NOCOUNT)
				If $asAddress[0] = "" Then
					ContinueLoop
				ElseIf UBound($asAddress) = 1 Then
					ReDim $asAddress[2]
					$asAddress[1] = ""
				EndIf

				Local $iIndex = -1
				While 1
					$iIndex = _GUICtrlListView_FindText($idServers, $asAddress[0], $iIndex, False, False)
					If $iIndex <> -1 Then
						If _GUICtrlListView_GetItemText($idServers, $iIndex, 1) = $asAddress[1] Then
							MsgBox(48, StringTrimRight(@ScriptName, 4), "You already have a server with this address and port added!", 0, $hGui)
							ContinueLoop 2
						Else
							ContinueLoop
						EndIf
					Else
						ExitLoop
					EndIf
				WEnd

				GUICtrlCreateListViewItem($asAddress[0] & "|" & $asAddress[1], $idServers)
				GUICtrlSetBkColor(-1, 0xFFFFFF)
				GUICtrlSetColor(-1, 0)
				_GUICtrlListView_SetColumnWidth($idServers, 0, $LVSCW_AUTOSIZE)
				_GUICtrlListView_SetColumnWidth($idServers, 1, $LVSCW_AUTOSIZE_USEHEADER)
				$oServers.Add($asAddress[0], $asAddress[1], False, "Auto")
				GUICtrlSetState(-1, $GUI_CHECKED)
			Case $idScanNow
				_ServerCheck()
			Case $idServerDelete
				_ServerDelete()
			Case $idServerShowPopup
				_ServerPopupShow()
			Case $idServerMenuAuto
				_ServerVersionSet($eProtocolAuto)
			Case $idServerMenuOld
				_ServerVersionSet($eProtocol1)
			Case $idServerMenuTrue
				_ServerVersionSet($eProtocol2)
			Case $idServerMenuNew
				_ServerVersionSet($eProtocol3)
			Case $cIdHints
				If $sUpdateLink <> "" Then ShellExecute($sUpdateLink)
			Case $cIdSettings
				If _GUICtrlButton_GetCheck($cIdSettings) = $GUI_CHECKED Then
					GUICtrlSetData($cIdSettings, "Settings " & ChrW(0x25BC))
					GUISetState(@SW_SHOWNOACTIVATE, $hSettingsGui)
				Else
					GUICtrlSetData($cIdSettings, "Settings " & ChrW(0x25B2))
					GUISetState(@SW_HIDE, $hSettingsGui)
				EndIf
			Case $idPopupDummy
				$iSkipLabelProc = True
				$iCurrent = GUICtrlRead($idPopupDummy)
				_WinAPI_SetWindowLong(GUICtrlGetHandle($avPopups[$iCurrent][4]), $GWL_WNDPROC, $avPopups[$iCurrent][3])
				DllCallbackFree($avPopups[$iCurrent][2])
				GUIDelete($avPopups[$iCurrent][0])
				_ArrayDelete($avPopups, $iCurrent)
				$iSkipLabelProc = False
			Case $idDeleteAvatars
				_AvatarsDeleteALL()
				_ServerInfoShow(_GUICtrlListView_GetSelectedIndices($idServers))
			Case $cIdNaughtyCat
				GUISetState(@SW_HIDE, $hNaughtyCatGui)
		EndSwitch
	WEnd
EndFunc

#EndRegion

#Region   ;GUI stuff

Func _ServerInfoShow($iIndex)
	Local $iFlag = False

	_GUICtrlListView_DeleteAllItems(GUICtrlGetHandle($idServerPlayers))
	_GUIImageList_Destroy(_GUICtrlListView_GetImageList($idServerPlayers, 0))
	_GUICtrlListView_SetImageList($idServerPlayers, _GUIImageList_Duplicate($idServerPlayersImageListDuplicate), 0)

	Local $sServer = _GUICtrlListView_GetItemText(GUICtrlGetHandle($idServers), $iIndex)
	Local $iPort = _GUICtrlListView_GetItemText(GUICtrlGetHandle($idServers), $iIndex, 1)

	For $iX = 1 To UBound($asServerInfo) -1
		If $asServerInfo[$iX][0] <> $sServer & ":" & $iPort Then ContinueLoop

		$iFlag = True
		_SetHImage($idServerImage, $asServerInfo[$iX][1])
		ExitLoop
	Next
	If $iFlag = False Then
		If @Compiled Then
			Local $hBmp = _GDIPlus_BitmapCreateFromMemory(Binary(_ResourceGetAsRaw(@ScriptFullPath, 10, "SERVER_DEFAULT")), True)
			_WinAPI_DeleteObject(GUICtrlSendMsg($idServerImage, 0x0172, 0, $hBmp))
			_WinAPI_DeleteObject($hBmp)
		Else
			GUICtrlSetImage($idServerImage, @ScriptDir & "\Svartnos.jpg")
		EndIf
	EndIf

	Local $iSetViewDetails = False, $iNeedDetails = 0, $sCleanName = "", $sID = ""
	For $iX = 0 To UBound($asServerPlayers) -1
		If $asServerPlayers[$iX][0] <> $sServer & ":" & $iPort Then ContinueLoop

		$sCleanName = $asServerPlayers[$iX][1]
		$sID = $asServerPlayers[$iX][2]
		If _MCStringClean($sCleanName) > 0 Or $sID = "00000000-0000-0000-0000-000000000000" Then $iNeedDetails += 1
		$sCleanName = StringStripWS($sCleanName, $STR_STRIPLEADING + $STR_STRIPTRAILING + $STR_STRIPSPACES)

		_GUICtrlListView_AddItem($idServerPlayers, $sCleanName, $iListNew)
	Next
	If $iNeedDetails > _GUICtrlListView_GetItemCount($idServerPlayers) -1 Then
		_GUICtrlListView_SetView($idServerPlayers, 1)
		_GUICtrlListView_SetColumnWidth($idServerPlayers, 0, $LVSCW_AUTOSIZE)
	Else
		_GUICtrlListView_SetView($idServerPlayers, 0)
		AdlibRegister("_DownloadPlayerImages", 100)
	EndIf
EndFunc

Func _DownloadPlayerImages()
	AdlibUnRegister("_DownloadPlayerImages")

	Local $iTimeOut = TimerInit()
	Local $iCount = _GUICtrlListView_GetItemCount($idServerPlayers) -1
	For $iX = 0 To $iCount
		If _GUICtrlListView_GetItemImage($idServerPlayers, $iX) <> 0 Then ContinueLoop

		$sFileName = _GUICtrlListView_GetItemText($idServerPlayers, $iX)
		If $sFileName = "" Then
			_GUICtrlListView_SetItemImage($idServerPlayers, $iX, $iListDefault)
			ContinueLoop
		EndIf

		For $iY = 0 To UBound($asServerPlayers) -1
			If $sFileName = $asServerPlayers[$iY][1] Then $sFileName = StringReplace($asServerPlayers[$iY][2], "-", "")
			ExitLoop
		Next

		$sFileNameHEAD = @ScriptDir & "\TemporaryFiles\" & $sFileName & ".png"

		If FileExists($sFileNameHEAD) Then
			_GUICtrlListView_SetItemImage($idServerPlayers, $iX, _ListView_AddImage($idServerPlayers, $sFileNameHEAD))
		Else
			DirCreate(@ScriptDir & "\TemporaryFiles")

			$iInet = InetGet("https://minotar.net/avatar/" & $sFileName & "/32", $sFileNameHEAD, $INET_FORCERELOAD)
			If @error = 13 Then
				_GUICtrlListView_SetItemImage($idServerPlayers, $iX, $iListDefault)
			ElseIf $iInet <> 0 Then
				_GUICtrlListView_SetItemImage($idServerPlayers, $iX, _ListView_AddImage($idServerPlayers, $sFileNameHEAD))
			Else
				_GUICtrlListView_SetItemImage($idServerPlayers, $iX, $iListError)
			EndIf
		EndIf
		If TimerDiff($iTimeOut) > 100 Then
			AdlibRegister("_DownloadPlayerImages")
			Return
		EndIf
	Next

	Local $iNeedDetails = 0
	For $iX = 0 To $iCount
		If _GUICtrlListView_GetItemImage($idServerPlayers, $iX) = $iListDefault Then $iNeedDetails += 1
	Next

	If $iNeedDetails > $iCount Then
		_GUICtrlListView_SetView($idServerPlayers, 1)
		_GUICtrlListView_SetColumnWidth($idServerPlayers, 0, $LVSCW_AUTOSIZE)
	EndIf
EndFunc

Func _ServerDelete()
	$aiListviewSelected = _GUICtrlListView_GetSelectedIndices($idServers, True)
	If $aiListviewSelected[0] = 0 Then
		MsgBox(48, StringTrimRight(@ScriptName, 4), "No server selected", 0, $hGui)
		Return
	EndIf

	For $iX = $aiListviewSelected[0] To 1 Step -1
		$oServers.Delete(_GUICtrlListView_GetItemText($idServers, $aiListviewSelected[$iX]), _GUICtrlListView_GetItemText($idServers, $aiListviewSelected[$iX], 1))
		_GUICtrlListView_DeleteItem($idServers, $aiListviewSelected[$iX])
	Next
EndFunc

Func _ServerVersionSet($sValue)
	$aiListviewSelected = _GUICtrlListView_GetSelectedIndices($idServers, True)
	If $aiListviewSelected[0] = 0 Then
		MsgBox(48, StringTrimRight(@ScriptName, 4), "No server selected", 0, $hGui)
		Return
	EndIf

	Local $sServer, $sPort

	For $iX = $aiListviewSelected[0] To 1 Step -1
		_GUICtrlListView_SetItemChecked($idServers, $aiListviewSelected[$iX])

		$sServer = _GUICtrlListView_GetItemText($idServers, $aiListviewSelected[$iX])
		$sPort = _GUICtrlListView_GetItemText($idServers, $aiListviewSelected[$iX], 1)
		$oServers.SetProtocol($sServer, $sPort, $sValue)
	Next
EndFunc

Func _AvatarsDeleteALL()
	FileDelete(@ScriptDir & "\TemporaryFiles\*.png")
EndFunc

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

	$hIcon = _GDIPlus_HICONCreateFromBitmap($hImage)

	Local $tNOTIFY = DllStructCreate($tagNOTIFYICONDATA)
	$tNOTIFY.Size = DllStructGetSize($tNOTIFY)
	$tNOTIFY.hWnd = $TRAY_ICON_GUI
	$tNOTIFY.ID = $AUT_NOTIFY_ICON_ID
	$tNOTIFY.hIcon = $hIcon
	$tNOTIFY.Flags = BitOR($NIF_ICON, $NIF_MESSAGE)
	$tNOTIFY.CallbackMessage = $AUT_WM_NOTIFYICON

	_WinAPI_ShellNotifyIcon($NIM_MODIFY, $tNOTIFY)
	_WinAPI_DestroyIcon($hIcon)
EndFunc

#Region   ;GUI stuff internals

;==================================================================================================================================
; Author ........: UEZ
; Modified.......: progandy, AdmiralAlkex
;===================================================================================================================================
Func _GDIPlus_ImageCreateFromMemory($bImage)
	If Not IsBinary($bImage) Then Return SetError(1, 0, 0)
	Local $aResult = 0
	Local Const $memBitmap = Binary($bImage) ;load image saved in variable (memory) and convert it to binary
	Local Const $iLen = BinaryLen($memBitmap) ;get binary length of the image
	Local Const $GMEM_MOVEABLE = 0x0002
	$aResult = DllCall("kernel32.dll", "handle", "GlobalAlloc", "uint", $GMEM_MOVEABLE, "ulong_ptr", $iLen) ;allocates movable memory ($GMEM_MOVEABLE = 0x0002)
	If @error Then Return SetError(4, 0, 0)
	Local Const $hData = $aResult[0]
	$aResult = DllCall("kernel32.dll", "ptr", "GlobalLock", "handle", $hData)
	If @error Then Return SetError(5, 0, 0)
	Local $tMem = DllStructCreate("byte[" & $iLen & "]", $aResult[0]) ;create struct
	DllStructSetData($tMem, 1, $memBitmap) ;fill struct with image data
	DllCall("kernel32.dll", "bool", "GlobalUnlock", "handle", $hData) ;decrements the lock count associated with a memory object that was allocated with GMEM_MOVEABLE
	If @error Then Return SetError(6, 0, 0)
	Local Const $hStream = _WinAPI_CreateStreamOnHGlobal($hData) ;creates a stream object that uses an HGLOBAL memory handle to store the stream contents
	If @error Then Return SetError(2, 0, 0)
	Local Const $hImage = _GDIPlus_ImageLoadFromStream($hStream) ;creates a Bitmap object based on an IStream COM interface
	If @error Then Return SetError(3, 0, 0)
	DllCall("oleaut32.dll", "long", "DispCallFunc", "ptr", $hStream, "ulong_ptr", 8 * (1 + @AutoItX64), "uint", 4, "ushort", 23, "uint", 0, "ptr", 0, "ptr", 0, "str", "") ;release memory from $hStream to avoid memory leak
	Return $hImage
EndFunc   ;==>_GDIPlus_BitmapCreateFromMemory

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

Func _ImageList_AddImageFromResource($hImageList, $sName)
	Local $gc_PNG = _GDIPlus_BitmapCreateFromMemory(Binary(_ResourceGetAsRaw(@ScriptFullPath, 10, $sName)), True)
	Local $iIndex = _GUIImageList_Add($hImageList, $gc_PNG)
	_WinAPI_DeleteObject($gc_PNG)
	Return $iIndex
EndFunc

Func _AdlibNaughtyCatShow()
	AdlibUnRegister(_AdlibNaughtyCatShow)

	GUISetState(@SW_SHOW, $hNaughtyCatGui)
	AdlibRegister(_AdlibNaughtyCatHide, 5000)
EndFunc

Func _AdlibNaughtyCatHide()
	AdlibUnRegister(_AdlibNaughtyCatHide)
	GUISetState(@SW_HIDE, $hNaughtyCatGui)
EndFunc

;Thx to Yashied for Code/Idea on how to handle listview checkboxes http://www.autoitscript.com/forum/topic/110391-listview-get-change-in-checking-items/#entry775483
;Thx to GaryFrost for Code/Idea on how to handle listview hover event http://www.autoitscript.com/forum/topic/41345-hover-detection-with-listview-is-it-posiible/?p=307598
Func _WM_NOTIFY($hWnd, $iMsg, $iwParam, $ilParam)
	#forceref $hWnd, $iMsg, $iwParam
	Local $iIDFrom, $iCode, $tNMHDR, $tInfo, $iIndex
	Static Local $iState

	$tNMHDR = DllStructCreate($tagNMHDR, $ilParam)
	$iIDFrom = DllStructGetData($tNMHDR, "IDFrom")
	$iCode = DllStructGetData($tNMHDR, "Code")

	Switch $iIDFrom
		Case $idServers
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
						$oServers.SetEnabled(_GUICtrlListView_GetItemText($idServers, $iIndex), _GUICtrlListView_GetItemText($idServers, $iIndex, 1), (Not $iState))
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
				Case $NM_RCLICK
					GUICtrlSetState($idServerMenuAuto, $GUI_UNCHECKED)
					GUICtrlSetState($idServerMenuOld, $GUI_UNCHECKED)
					GUICtrlSetState($idServerMenuTrue, $GUI_UNCHECKED)
					GUICtrlSetState($idServerMenuNew, $GUI_UNCHECKED)

					$tInfo = DllStructCreate($tagNMITEMACTIVATE, $ilParam)
					$iIndex = DllStructGetData($tInfo, "Index")
					For $iX = 0 To UBound($oServers.List) -1
						If _GUICtrlListView_GetItemText($idServers, $iIndex) = $oServers.List[$iX][$eServer] And _GUICtrlListView_GetItemText($idServers, $iIndex, 1) = $oServers.List[$iX][$ePort] Then
							Switch $oServers.List[$iX][$eProtocol]
								Case $eProtocolAuto
									GUICtrlSetState($idServerMenuAuto, $GUI_CHECKED)
									Switch $oServers.List[$iX][$eProtocolCurrent]
										Case $eProtocol1
											GUICtrlSetState($idServerMenuOld, $GUI_CHECKED)
										Case $eProtocol2
											GUICtrlSetState($idServerMenuTrue, $GUI_CHECKED)
										Case Else
											GUICtrlSetState($idServerMenuNew, $GUI_CHECKED)
									EndSwitch
								Case $eProtocol1
									GUICtrlSetState($idServerMenuOld, $GUI_CHECKED)
								Case $eProtocol2
									GUICtrlSetState($idServerMenuTrue, $GUI_CHECKED)
								Case $eProtocol3
									GUICtrlSetState($idServerMenuNew, $GUI_CHECKED)
							EndSwitch
							Return $GUI_RUNDEFMSG
						EndIf
					Next
			EndSwitch
		Case $idServerPlayers
			Switch $iCode
				Case $LVN_HOTTRACK
					AdlibUnRegister(_AdlibNaughtyCatShow)
					$tInfo = DllStructCreate($tagNMLISTVIEW, $ilParam)
					$iIndex = DllStructGetData($tInfo, "Item")
					If $iIndex = -1 Then Return $GUI_RUNDEFMSG
					If _NaughtyList(_GUICtrlListView_GetItemText($idServerPlayers, DllStructGetData($tInfo, "Item"))) Then AdlibRegister(_AdlibNaughtyCatShow, 2000)
			EndSwitch
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>_WM_NOTIFY

Func _NaughtyList($sName)
	Local $asList[] = ["Pc_Girl"]

	For $iX = 0 To UBound($asList) -1
		If $asList[$iX] = $sName Then Return 1
	Next

	Return 0
EndFunc

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
					If _GUICtrlButton_GetCheck($hCtrl) = $BST_CHECKED Then
						Opt("TrayIconHide", 0)
						_TraySet($iServerTray)
					Else
						Opt("TrayIconHide", 1)
					EndIf
			EndSwitch
		Case $hColorizeListview
			Switch $nNotifyCode
				Case $BN_CLICKED
					If _GUICtrlButton_GetCheck($hCtrl) = $BST_CHECKED Then
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

#EndRegion
#EndRegion

#Region   ;Hints and Updates

Func _HintRemove()
	Local $sText = GUICtrlRead($cIdHints)

	If StringLen($sText) = 0 Then
		AdlibUnRegister("_HintRemove")
		$asHint[0] += 1
		If $asHint[0] = UBound($asHint) Then $asHint[0] = 1
		If $asHint[$asHint[0]] = "Update found, click to open website" Then
			GUICtrlSetCursor($cIdHints, 0)
			GUICtrlSetColor($cIdHints, 0x0000EE)
			GUICtrlSetFont($cIdHints, Default, $FW_DONTCARE, $GUI_FONTUNDER)
		Else
			GUICtrlDelete($cIdHints)
			GUISwitch($hGui)
			$cIdHints = GUICtrlCreateLabel("", 10, $iGuiY - 35, 485, 25, $SS_CENTERIMAGE)
		EndIf
		_HintAdd()
		AdlibRegister("_HintAdd", 20)
		Return
	EndIf

	GUICtrlSetData($cIdHints, StringTrimRight($sText, 1))
EndFunc

Func _HintAdd()
	Local $iLength = StringLen(GUICtrlRead($cIdHints))

	If $iLength = StringLen($asHint[$asHint[0]]) Then
		AdlibUnRegister("_HintAdd")
		Return
	EndIf

	GUICtrlSetData($cIdHints, StringLeft($asHint[$asHint[0]], $iLength +1))
EndFunc

Func _CheckForUpdateMaster()
	$iCheck = _CheckForUpdate()
	If $iCheck Then
		_UpdateHint("Update found, click to open website")
	ElseIf $iCheck = False Then
		_UpdateHint("No update found")
	EndIf
EndFunc

Func _CheckForUpdate()
	Local $asInfo = InetGetInfo($aInet)
	If $asInfo[2] <> True Then Return Null

	AdlibUnRegister("_CheckForUpdateMaster")
	InetClose($aInet)
	$sFile = FileRead(@TempDir & "\MSPC.txt")
	FileDelete(@TempDir & "\MSPC.txt")

	If $asInfo[3] <> True Then Return False
	$aRet = StringSplit($sFile, "|")
	If @error Then Return False
	If $aRet[0] <> 2 Then Return False
	If $aRet[1] <= 20 Then Return False   ;Version

	$sUpdateLink = $aRet[2]
	Return True
EndFunc

Func _UpdateHint($sText)
	_ArrayAdd2($asHint, $sText)
	$asHint[0] = UBound($asHint) -2
	AdlibRegister("_HintRemove", 20)
EndFunc

Func _ArrayAdd2(ByRef $avArray, $vValue)
	Local $iUBound = UBound($avArray)
	ReDim $avArray[$iUBound + 1]
	$avArray[$iUBound] = $vValue
EndFunc   ;==>_ArrayAdd

#EndRegion

#Region   ;Internal functions

;Unknown author, function found in post here http://www.autoitscript.com/forum/topic/51103-resources-udf/?p=921164
Func _ResourceGetAsRaw($sModule, $vResType, $vResName, $iResLang = 0)

    Local $hResDll = _WinAPI_LoadLibraryEx($sModule, $LOAD_LIBRARY_AS_DATAFILE)
    If @error Then Return SetError(1, 0, 0)

    Local $sTypeType = "wstr"
    If IsNumber($vResType) Then $sTypeType = "int"

    Local $sNameType = "wstr"
    If IsNumber($vResName) Then $sNameType = "int"

    Local $aCall = DllCall("kernel32.dll", "handle", "FindResourceExW", _
            "handle", $hResDll, _
            $sTypeType, $vResType, _
            $sNameType, $vResName, _
            "int", $iResLang)
    If @error Or Not $aCall[0] Then
        _WinAPI_FreeLibrary($hResDll)
        Return SetError(2, 0, 0)
    EndIf

    Local $hResource = $aCall[0]

    $aCall = DllCall("kernel32.dll", "int", "SizeofResource", "handle", $hResDll, "handle", $hResource)
    If @error Or Not $aCall[0] Then
        _WinAPI_FreeLibrary($hResDll)
        Return SetError(3, 0, 0)
    EndIf

    Local $iSizeOfResource = $aCall[0]

    $aCall = DllCall("kernel32.dll", "handle", "LoadResource", "handle", $hResDll, "handle", $hResource)
    If @error Or Not $aCall[0] Then
        _WinAPI_FreeLibrary($hResDll)
        Return SetError(4, 0, 0)
    EndIf

    $hResource = $aCall[0]

    $aCall = DllCall("kernel32.dll", "ptr", "LockResource", "handle", $hResource)
    If @error Or Not $aCall[0] Then
        _WinAPI_FreeLibrary($hResDll)
        Return SetError(5, 0, 0)
    EndIf

    Local $pResource = $aCall[0]

    Local $tBinary = DllStructCreate("byte[" & $iSizeOfResource & "]", $pResource)
    Local $bBinary = DllStructGetData($tBinary, 1)

    _WinAPI_FreeLibrary($hResDll)

    Return $bBinary

EndFunc   ;==>_ResourceGetAsRaw

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

Func _MCStringClean(ByRef $sText, $dRemoveColors = True)
	Local $iReplacements = 0

	$sText = StringReplace($sText, "Â", "")
	$iReplacements += @extended

	If $dRemoveColors Then
		$sText = StringRegExpReplace($sText, "(§.)", "")
		$iReplacements += @extended
	EndIf

	$sText = StringReplace($sText, @CR, "")
	$iReplacements += @extended
	$sText = StringReplace($sText, @LF, "")
	$iReplacements += @extended

	Return $iReplacements
EndFunc

Func _AvatarsDelete()
	Local $sTempFolder = @ScriptDir & "\TemporaryFiles\"
	Local $hSearch = FileFindFirstFile($sTempFolder & "*.png")
	If $hSearch = -1 Then Return

	Local $sFileName, $sStartDate, $sEndDate = _NowCalc()

	While 1
		$sFileName = FileFindNextFile($hSearch)
		If @error Then ExitLoop
		If @extended Then ContinueLoop

		$asStartDate = FileGetTime($sTempFolder & $sFileName)
		If @error Then ContinueLoop
		$iDateCalc = _DateDiff("D", $asStartDate[0] & "/" & $asStartDate[1] & "/" & $asStartDate[2], $sEndDate)
		If @error Then ContinueLoop

		If $iDateCalc >= 7 Then FileDelete($sTempFolder & $sFileName)
	WEnd

	FileClose($hSearch)
EndFunc

Func _Log($sMessage, $iLineNumber = @ScriptLineNumber)
	Local $sText = StringFormat("%04i", $iLineNumber) & " | " & @HOUR & ":" & @MIN & " " & @SEC & ":" & @MSEC & " | " & $sMessage & @CRLF
	Static Local $vFunc = @Compiled ? _LogFile : _LogConsole
	$vFunc($sText)
EndFunc

Func _LogFile($sText)
	Static Local $sLoggingLevel = IniRead(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "LoggingLevel", "Unknown")
	If $sLoggingLevel <> "Unknown" Then
		Static Local $hLog = FileOpen(@ScriptDir & "\Log.txt", $FO_OVERWRITE)
		If $hLog <> -1 Then FileWrite($hLog, $sText)
	EndIf
EndFunc

Func _LogConsole($sText)
	ConsoleWrite($sText)
EndFunc

Func _Quitting()
	AdlibUnRegister("_ServerCheck")
	AdlibUnRegister("_CheckForUpdateMaster")
	$oServers.Save()
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "SecondsBetweenScans", GUICtrlRead($idSeconds))
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "FlashWindow", BitAnd(GUICtrlRead($idFlashWin), $GUI_CHECKED))
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "CountTray", BitAnd(GUICtrlRead($idCountTray), $GUI_CHECKED))
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "CheckForUpdate", BitAnd(GUICtrlRead($idCheckForUpdate), $GUI_CHECKED))
	IniWrite(@ScriptDir & "\Minecraft Server Periodic Checker.ini", "General", "ColorizeListview", BitAnd(GUICtrlRead($idColorizeListview), $GUI_CHECKED))
	_Log("bye")
EndFunc

#EndRegion
