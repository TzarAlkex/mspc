#cs
	Originally was a script to get MX records written by trancexx
	http://www.autoitscript.com/forum/topic/78465-mx-records-for-a-specific-domain/

	Now modified to get SRV records by AdmiralAlkex
#ce

#include-once
#include <StringConstants.au3>
#include <Array.au3>

Func SRVRecords($domain)
	Local $binary_data = SRVQueryServer($domain)
	If $binary_data = -1 Then Return -1

	Local $output = ExtractSRVServerData($binary_data)

	_ArraySort($output, 0, 0, 0, 0)

	Local $iStart = -1
	For $iX = 1 To UBound($output) - 1
		If $output[$iX][0] = $output[$iX - 1][0] And $iStart = -1 Then
			$iStart = $iX - 1
		ElseIf $output[$iX][0] <> $output[$iX - 1][0] And $iStart <> -1 Then
			_ArraySort($output, 1, $iStart, $iX - 1, 1)
			$iStart = -1
		EndIf
	Next
	If $iStart <> -1 Then
		_ArraySort($output, 1, $iStart, $iX - 1, 1)
	EndIf

	Return $output
EndFunc   ;==>SRVRecords


Func SRVQueryServer($domain)
	Local $domain_array
	$domain_array = StringSplit($domain, ".", 1)

	Local $binarydom
	For $el = 1 To $domain_array[0]
		$binarydom &= Hex(BinaryLen($domain_array[$el]), 2) & StringTrimLeft(StringToBinary($domain_array[$el]), 2)
	Next
	$binarydom &= "00" ; for example, 'gmail.com' will be '05676D61696C03636F6D00' and 'autoit.com' will be '066175746F697403636F6D00'

	Local $identifier = Hex(Random(0, 1000, 1), 2) ; random hex number serving as a handle for the data that will be received
	Local $server_bin = "0x00" & $identifier & "01000001000000000000" & $binarydom & "00210001" ; this is our query
	Local $num_time, $data

	Local $asQueryServers = _GetDnsServerAddress()
	Local $asPublicServers = StringSplit("8.8.8.8|8.8.4.4|4.2.2.1|67.138.54.100|208.67.222.222|4.2.2.2|4.2.2.3|208.67.220.220|4.2.2.4|4.2.2.5|4.2.2.6", "|", $STR_NOCOUNT)
	Local $iSize = _ArrayConcatenate($asQueryServers, $asPublicServers)

	For $num_time = 0 To $iSize - 1
		; this kind of server is not what we want
		If StringLeft($asQueryServers[$num_time], 3) = "192" Then ContinueLoop
		If $asQueryServers[$num_time] = "" Then ContinueLoop

		UDPStartup()

		Local $sock
		$sock = UDPOpen($asQueryServers[$num_time], 53)
		If $sock = -1 Then ; ok, that happens
			UDPCloseSocket($sock)
			UDPShutdown()
			ContinueLoop ; change server and try again
		EndIf

		UDPSend($sock, $server_bin) ; sending query

		Local $tik = 0
		Do
			$data = UDPRecv($sock, 512)
			$tik += 1
			Sleep(100)
		Until $data <> "" Or $tik = 8 ; waiting reasonable time for the response

		UDPShutdown() ; stopping service

		If $data <> "" And StringRight(BinaryMid($data, 2, 1), 2) = $identifier Then
			Return $data ; if there is data for us, return
		EndIf
	Next

	Return -1
EndFunc   ;==>SRVQueryServer

Func ExtractSRVServerData($binary_data)
	Local $num_answ = Dec(StringMid($binary_data, 15, 4)) ; representing number of answers provided by the server

	Local $arr = StringSplit($binary_data, "C00C00210001", 1) ; splitting input; "C00C000F0001" - translated to human: "this is the answer for your MX query"

	If $num_answ <> $arr[0] - 1 Or $num_answ = 0 Then Return -1 ; dealing with possible options

	Local $iPriority[$arr[0]]
	Local $iWeight[$arr[0]]
	Local $iPort[$arr[0]]
	Local $sTarget[$arr[0]] ; server name(s)
	Local $output[$arr[0] - 1][4] ; this goes out containing both server names and coresponding priority/weight and port numbers

	Local $offset = 14 ; initial offset

	For $i = 2 To $arr[0]

		$arr[$i] = "0x" & $arr[$i] ; well, it is binary data

		$iPriority[$i - 1] = Dec(StringRight(BinaryMid($arr[$i], 7, 2), 4))

		$iWeight[$i - 1] = Dec(StringRight(BinaryMid($arr[$i], 9, 2), 4))

		$iPort[$i - 1] = Dec(StringRight(BinaryMid($arr[$i], 11, 2), 4))

		$offset += BinaryLen($arr[$i - 1]) + 6 ; adding lenght of every past part plus lenght of that "C00C000F0001" used for splitting

		Local $array = ReadBinary($binary_data, $offset) ; extraction of server names starts here

		While $array[1] = 192 ; dealing with special case
			$array = ReadBinary($binary_data, $array[6] + 2)
		WEnd

		$sTarget[$i - 1] &= $array[2] & "."

		While $array[3] <> 0 ; the end will obviously be at $array[3] = 0

			If $array[3] = 192 Then

				$array = ReadBinary($array[0], $array[4] + 2)

				If $array[3] = 0 Then
					$sTarget[$i - 1] &= $array[2]
					ExitLoop
				Else
					$sTarget[$i - 1] &= $array[2] & "."
				EndIf

			Else

				$array = ReadBinary($array[0], $array[5])

				If $array[3] = 0 Then
					$sTarget[$i - 1] &= $array[2]
					ExitLoop
				Else
					$sTarget[$i - 1] &= $array[2] & "."
				EndIf

			EndIf

		WEnd

		$output[$i - 2][0] = $iPriority[$i - 1]
		$output[$i - 2][1] = $iWeight[$i - 1]
		$output[$i - 2][2] = $iPort[$i - 1]
		$output[$i - 2][3] = $sTarget[$i - 1]

	Next

	Return $output ; two-dimensional array
EndFunc   ;==>ExtractSRVServerData


Func ReadBinary($binary_data, $offset)
	Local $len = Dec(StringRight(BinaryMid($binary_data, $offset - 1, 1), 2))

	Local $data_bin = BinaryMid($binary_data, $offset, $len)

	Local $checker = Dec(StringRight(BinaryMid($data_bin, 1, 1), 2))

	Local $data = BinaryToString($data_bin)

	Local $triger = Dec(StringRight(BinaryMid($binary_data, $offset + $len, 1), 2))

	Local $new_offset = Dec(StringRight(BinaryMid($binary_data, $offset + $len + 1, 1), 2))

	Local $another_offset = $offset + $len + 1

	Local $array[7] = [$binary_data, $len, $data, $triger, $new_offset, $another_offset, $checker] ; bit of this and bit of that

	Return $array
EndFunc   ;==>ReadBinary

;Based on Authenticity code from http://www.autoitscript.com/forum/topic/119734-tcpiptoname-extremly-slow-if-no-ptr-record-exists/?p=832148
Func _GetDnsServerAddress()
	Local $aResult, $tBuf, $tDnsServersList

	$aResult = DllCall("iphlpapi.dll", "uint", "GetNetworkParams", "int*", 0, "uint*", 4)

	If $aResult[0] = 111 Then
		$tBuf = DllStructCreate("byte[" & $aResult[2] & "]")
		$aResult = DllCall("iphlpapi.dll", "uint", "GetNetworkParams", "struct*", $tBuf, "uint*", $aResult[2])
		If $aResult[0] <> 0 Then Return SetError($aResult[0], 0, "")

		Local $tagIP_ADDR_STRING = "ptr Next;char IpAddress[16];char IpMask[16];uint Context;"
		$tDnsServersList = DllStructCreate($tagIP_ADDR_STRING, DllStructGetPtr($tBuf) + 268)

		Local $sOutput = $tDnsServersList.IpAddress
		While $tDnsServersList.Next
			$tDnsServersList = DllStructCreate($tagIP_ADDR_STRING, $tDnsServersList.Next)
			$sOutput &= "|" & $tDnsServersList.IpAddress
		WEnd

		Return StringSplit($sOutput, "|", $STR_NOCOUNT)
	Else
		Return SetError(-1, 0, "")
	EndIf
EndFunc   ;==>_GetDnsServerAddress
