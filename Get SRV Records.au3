#cs
Originally was a script to get MX records written by trancexx
http://www.autoitscript.com/forum/topic/78465-mx-records-for-a-specific-domain/

Now modified to get SRV records by AdmiralAlkex
#ce

Opt("MustDeclareVars", 1)

#include <Array.au3>

Local $domain = "_minecraft._tcp.mc.streamercraft.com" ; change it to domain of your interest

Local $mx = SRVRecords($domain)

If IsArray($mx) Then
    Local $au
    For $j = 0 To UBound($mx) -1
        $au &= "Priority:" & $mx[$j][0] & " Weight:" & $mx[$j][1] & " Port:" & $mx[$j][2] & " Target:" & $mx[$j][3] & @CRLF
    Next

    MsgBox(0, "SRV records for " & $domain, $au)
Else
    MsgBox(0, "SRV records for " & $domain, "No Records")
EndIf



Func SRVRecords($domain)

    Local $binary_data = SRVQueryServer($domain)
    If $binary_data = -1 Then Return -1

	Local $output = ExtractSRVServerData($binary_data)

	_ArraySort($output, 0, 0, 0, 0)

	Local $iStart = -1
	For $iX = 1 To UBound($output) -1
		If $output[$iX][0] = $output[$iX -1][0] And $iStart = -1 Then
			$iStart = $iX -1
		ElseIf $output[$iX][0] <> $output[$iX -1][0] And $iStart <> -1 Then
			_ArraySort($output, 1, $iStart, $iX -1, 1)
			$iStart = -1
		EndIf
	Next
	If $iStart <> -1 Then
		_ArraySort($output, 1, $iStart, $iX -1, 1)
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

    For $num_time = 1 To 10
        Local $query_server ; ten(10) DNS servers, we'll start with one that is our's default, if no response or local one switch to public free servers
        Switch $num_time
            Case 1
                Local $loc_serv = StringSplit(RegRead("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "DhcpNameServer"), " ", 1)
                If $loc_serv[0] > 0 Then
                    If StringLeft($loc_serv[1], 3) <> "192" Then ; this kind of server is not what we want
                        $query_server = $loc_serv[1]
                    EndIf
                EndIf
            Case 2
                $query_server = "4.2.2.1"
            Case 3
                $query_server = "67.138.54.100"
            Case 4
                $query_server = "208.67.222.222"
            Case 5
                $query_server = "4.2.2.2"
            Case 6
                $query_server = "4.2.2.3"
            Case 7
                $query_server = "208.67.220.220"
            Case 8
                $query_server = "4.2.2.4"
            Case 9
                $query_server = "4.2.2.5"
            Case 10
                $query_server = "4.2.2.6"
            Case 11
                Return -1
        EndSwitch

        If $query_server <> "" Then
            UDPStartup()

            Local $sock
            $sock = UDPOpen($query_server, 53)
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
    Local $output[$arr[0] -1][4] ; this goes out containing both server names and coresponding priority/weight and port numbers

    Local $offset = 10 ; initial offset

    For $i = 2 To $arr[0]

        $arr[$i] = "0x" & $arr[$i] ; well, it is binary data

        $iPriority[$i - 1] = Dec(StringRight(BinaryMid($arr[$i], 7, 2), 4))

        $iWeight[$i - 1] = Dec(StringRight(BinaryMid($arr[$i], 9, 2), 4))

        $iPort[$i - 1] = Dec(StringRight(BinaryMid($arr[$i], 11, 2), 4))

        $offset += BinaryLen($arr[$i - 1]) + 10 ; adding lenght of every past part plus lenght of that "C00C000F0001" used for splitting

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