;============================================================================
;           AUTOIT PICKLING LIBRARY                         © Hyperzap 2011
;
;
;Pickling refers to the ability to 'freeze' a variable and store its exact
;and current state, and data to disk, where it can be loaded into its exact
;previous Form at a later time or subsequent executions.
;
;   Functions:                                                  ------------
;
;       Pickle( $variable, $file_path)
;       LoadPickle( $file_path)
;
;============================================================================


;Pickler Global COnstants
Const $Pickle_Version = 1
Global $Pickle_Temp[1]


;------------------- EXAMPLE USAGE ------------------------------------------
;#include <array.au3>
;global $test[2]
;$test[0] = "This is some data to pickle!, I can put it in up to 7 dimensions."
;$test[1] = "So is this, and I can use up to 9999999 elements per dimension!!"
;Pickle( $test, @ScriptDir & "/test.txt")
;$test = 0 ;MUHAHA Destroyed the variable, now the only hope is retrieving it from the pickle.
;$tempe = LoadPickle( @ScriptDir & "/test.txt")
;_ArrayDisplay( $tempe)











;============================================================================
;============================================================================
;   PICKLING FUNCTIONS                          (Variable -> File)
;
;   Use 'Pickle( $variable, $file_path)'
;   Will create a file on disk that contains the data and state of your
;   Variable which was passed as the first parameter.
;============================================================================
;============================================================================

Func Pickle( ByRef $variable, $file_path)
    local $filehnd = FileOpen( $file_path, 2)
    local $return = Pickle_Recursive_Var_Serialize( $filehnd, $variable)
    FileClose( $filehnd)

    return $return
EndFunc


;============================================================================
;============================================================================
;   UN-PICKLING FUNCTIONS                       (Pickle -> Variable)
;
;   Goes from a file on disk to a fully blown Autoit Variable.
;   LoadPickle( $file_path)
;
;   Returns your new variable, given the file path of the pickle as a string.
;============================================================================
;============================================================================

Func LoadPickle( $file_path)
    ;First we readin the file into individual characters.
    local $char_array[1]
    local $array_commit_pos = 0
    local $filehnd = FileOpen( $file_path, 0)

    While 1
        $char = FileRead($filehnd, 1)
        If @error = -1 Then ExitLoop
        $char_array[$array_commit_pos] = $char
        $array_commit_pos += 1
        ;We redim in blocks of 350 to speed things up.
        if $array_commit_pos > UBound( $char_array)-1 Then
            ReDim $char_array[$array_commit_pos+350]
        EndIf
    WEnd

    ReDim $char_array[$array_commit_pos];Put to right size
    FileClose( $filehnd)

    ;_ArrayDisplay( $char_array)
    local $NuPOS = 1
    return Recurse_Var_UNSerialize( $char_array, $NuPOS)
EndFunc


;Recursive main function to parse the file structure and generate the variable.
Func Pickle_Recursive_Var_Serialize( $filehnd, ByRef $Variable)
    ;First we need to write out the Pickle Version.
    FileWrite( $filehnd, "<#" & StringFormat("%02d",$Pickle_Version) & ";")

    ;Now we need to write out the Typeheader of our Variable.
    If IsString( $Variable) Then ;STRING
        FileWrite( $filehnd, "01;#" & Pickle_Encode_String( String($Variable)))

    Elseif IsNumber( $variable) Then ;NUMBER
        FileWrite( $filehnd, "02;#" & Pickle_Encode_String( String($Variable)))

    Elseif IsHWnd( $variable) Then ;WIN HANDLE
        FileWrite( $filehnd, "03;#" & Pickle_Encode_String( String($Variable)))

    Elseif IsPtr( $variable) Then ;POINTER
        FileWrite( $filehnd, "04;#" & Pickle_Encode_String( String($Variable)))

    Elseif IsBinary( $variable) Then ;BINARY
        FileWrite( $filehnd, "05;#" & Pickle_Encode_String( BinaryToString($Variable)))

    Elseif IsBool( $variable) Then ;BOOLEAN
        FileWrite( $filehnd, "06;#" & Pickle_Encode_String( String($Variable)))

    ElseIf IsArray( $Variable) Then ;ARRAY
        FileWrite( $filehnd, "07;")

        ;Now we make the rest of the header based on the sizes of the array.
        FileWrite( $filehnd, StringFormat("%02d",UBound( $Variable, 0)) & ";")
        for $r = 1 to UBound( $Variable, 0) step 1
            FileWrite( $filehnd, StringFormat("%07d",UBound( $Variable, $r)) & ";");Each Array dimension has its dimensions in the header.
        Next

        FileWrite( $filehnd, "#")
        Pickle_Array_Writeout( $Variable, 1, $filehnd);This writes the elements of the array out.

    Else    ;Unsupported Datatype.
        FileWrite( $filehnd, "00;#>")
        return 2;Two means failure, unsupported
    EndIf

    FileWrite( $filehnd, ">") ;End of Variable
    return 1    ;Success
EndFunc


;Recursive function to Writeout arrays to file.
;As you can see, my pickler can only pickle arrays with less than 8 dimensions.
Func Pickle_Array_Writeout($var, $level, $filehnd, $1=-1,$2=-1,$3=-1,$4=-1,$5=-1,$6=-1,$7=-1,$8=-1)
    For $c = 0 to UBound( $var, $level)-1 Step 1
        if $level < UBound( $var, 0) then
            Switch $level
            Case 1
                Pickle_Array_Writeout($var, $level+1, $filehnd,$c,$2,$3,$4,$5,$6,$7,$8)
            Case 2
                Pickle_Array_Writeout($var, $level+1, $filehnd,$1,$c,$3,$4,$5,$6,$7,$8)
            Case 3
                Pickle_Array_Writeout($var, $level+1, $filehnd,$1,$2,$c,$4,$5,$6,$7,$8)
            Case 4
                Pickle_Array_Writeout($var, $level+1, $filehnd,$1,$2,$3,$c,$5,$6,$7,$8)
            Case 5
                Pickle_Array_Writeout($var, $level+1, $filehnd,$1,$2,$3,$4,$c,$6,$7,$8)
            Case 6
                Pickle_Array_Writeout($var, $level+1, $filehnd,$1,$2,$3,$4,$5,$c,$7,$8)
            Case 7
                Pickle_Array_Writeout($var, $level+1, $filehnd,$1,$2,$3,$4,$5,$6,$c,$8)
            Case 8
                Pickle_Array_Writeout($var, $level+1, $filehnd,$1,$2,$3,$4,$5,$6,$7,$c)
            EndSwitch
        Else
            Switch $level
            Case 1
                Pickle_Recursive_Var_Serialize( $filehnd, $Var[$c])
            Case 2
                Pickle_Recursive_Var_Serialize( $filehnd, $Var[$1][$c])
            Case 3
                Pickle_Recursive_Var_Serialize( $filehnd, $Var[$1][$2][$c])
            Case 4
                Pickle_Recursive_Var_Serialize( $filehnd, $Var[$1][$2][$3][$c])
            Case 5
                Pickle_Recursive_Var_Serialize( $filehnd, $Var[$1][$2][$3][$4][$c])
            Case 6
                Pickle_Recursive_Var_Serialize( $filehnd, $Var[$1][$2][$3][$4][$5][$c])
            Case 7
                Pickle_Recursive_Var_Serialize( $filehnd, $Var[$1][$2][$3][$4][$5][$6][$c])
            Case 8
                Pickle_Recursive_Var_Serialize( $filehnd, $Var[$1][$2][$3][$4][$5][$6][$7][$c])
            EndSwitch
        EndIf
    Next

EndFunc


;Encodes the bad/clashing parts of a string in the format A = %065%
Func Pickle_Encode_String( $string)
    local $str = StringSplit( $string, "")
    local $outputstr = ""

    for $x = 1 to $str[0] step 1
        local $num = Asc( $str[$x])

        if $num < 32 or $num > 126 or $num = 37 or $num = 60 or $num = 62 or $num = 59 or $num = 35 then
            $outputstr &= Pickle_Encode( $num)
        Else
            $outputstr &= $str[$x]
        EndIf

    Next
    return $outputstr
EndFunc

;Wrapper for above.
Func Pickle_Encode( $num)
    local $ret = "%" & StringFormat("%03d",$num) & "%"
    return $ret
EndFunc



;--------------------------------------------------------------------------------------------
;       UNPICKLING WRAPPER FUNCTIONS
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::;




;Recurive main function generating the variables and returning them based on file structure.
Func Recurse_Var_UNSerialize( ByRef $char_array, ByRef $startpos)
    ;ConsoleWrite("UNSerialize START :: " & $startpos&":"&$char_array[$startpos]&@CRLF);Debug.
    ;Start at one to skip past initial '<'
    For $pos = $startpos to UBound( $char_array)-1 step 1
        $startpos = $pos ;FOr the byref.
        Switch $char_array[$pos]
            Case '>'
                return 0    ;Bad pickle or no data - either way its just a blank variable.
            Case "#"        ;Header Information!
                local $pickler_vers = Number(Pickler_Readin_HeaderSect( $char_array, $pos));See if the encoding is compatible
                if $pickler_vers > $Pickle_Version then return 0 ;Cannot decode - later version of pickler used to pickle.

                ;So we know the file format is compatible, so lets determine the variable type and make the variable.
                local $var_type = Number(Pickler_Readin_HeaderSect( $char_array, $pos))
                ;ConsoleWrite("TYPE"&$var_type)
                Switch $var_type
                    Case 0 ;Untransferable datatype or bad pickle, lets just return default.
                        $startpos = $pos
                        return 0
                    Case 1 ;Its a string - so read it in and store it.
                        $sTemp = Pickler_Readin_Datasect( $char_array, $pos)
                        $startpos = $pos
                        return Pickler_De_Encode( $sTemp) ;Mail off to be decoded, then return the string.
                    Case 2 ;Number
                        $sTemp = Pickler_Readin_Datasect( $char_array, $pos)
                        $startpos = $pos
                        return Number($stemp)
                    Case 3 ;Win Handle.
                        $sTemp = Pickler_Readin_Datasect( $char_array, $pos)
                        $startpos = $pos
                        Return HWnd( $stemp)
                    Case 4 ;Pointer
                        $sTemp = Pickler_Readin_Datasect( $char_array, $pos)
                        $startpos = $pos
                        Return Ptr( $stemp)
                    Case 5 ;Binary
                        $sTemp = Pickler_Readin_Datasect( $char_array, $pos)
                        $startpos = $pos
                        Return StringToBinary( $stemp)
                    Case 6 ;Boolean
                        $sTemp = Pickler_Readin_Datasect( $char_array, $pos)
                        $startpos = $pos
                        if $sTemp = "True" then return True
                        if $sTemp = "False" then return False
                    Case 7 ;Array. FUCK. This is by far the hardest to write.
                        ;First we need to get the sizes of the array. We will start with the num of dimensions.
                        local $nDimensions = Number(Pickler_Readin_HeaderSect( $char_array, $pos))
                        local $aDimensions[$nDimensions]
                        For $q = 0 to UBound( $aDimensions)-1 step 1 ;Get sizes for each dimension.
                            $aDimensions[$q] = Number(Pickler_Readin_HeaderSect( $char_array, $pos))
                        Next

                        $pos += 2 ;Get away from the end of header identifiers. (;#)
                        local $TempHND = Pickle_Generate_Array( $nDimensions, $aDimensions);Declares array.
                        Pickler_Create_Array( $char_array, $pos, $TempHND, $nDimensions, $aDimensions);Populates array.
                        local $ret = $Pickle_Temp[$TempHND]
                        Pickle_TEMPArray_Free( $TempHND);Lets try and save some memory.
                        $startpos = $pos
                        return $ret
                EndSwitch

        EndSwitch
    Next
EndFunc

;This is a recursive function that is used to POPULATE an array.
Func Pickler_Create_Array( ByRef $char_array, ByRef $pos, ByRef $temp, $nDimensions, $aDimensions, $level=0, $0=0,$1=0,$2=0,$3=0,$4=0,$5=0,$6=0,$7=0,$8=0)
    For $c = 0 to $aDimensions[$level]-1 Step 1
        ;ConsoleWrite("LEVEL: " & $c & "::" & $aDimensions[$level] & @CRLF);Debug
        if $level < $nDimensions-1 then
            Switch $level
                Case 0
                    Pickler_Create_Array( $char_array, $pos,$temp, $nDimensions, $aDimensions, $level+1, $c,$1,$2,$3,$4,$5,$6,$7,$8)
                Case 1
                    Pickler_Create_Array( $char_array, $pos,$temp, $nDimensions, $aDimensions, $level+1, $0,$c,$2,$3,$4,$5,$6,$7,$8)
                Case 2
                    Pickler_Create_Array( $char_array, $pos,$temp, $nDimensions, $aDimensions, $level+1, $0,$1,$c,$3,$4,$5,$6,$7,$8)
                Case 3
                    Pickler_Create_Array( $char_array, $pos,$temp, $nDimensions, $aDimensions, $level+1, $0,$1,$2,$c,$4,$5,$6,$7,$8)
                Case 4
                    Pickler_Create_Array( $char_array, $pos,$temp, $nDimensions, $aDimensions, $level+1, $0,$1,$2,$3,$c,$5,$6,$7,$8)
                Case 5
                    Pickler_Create_Array( $char_array, $pos,$temp, $nDimensions, $aDimensions, $level+1, $0,$1,$2,$3,$4,$c,$6,$7,$8)
                Case 6
                    Pickler_Create_Array( $char_array, $pos,$temp, $nDimensions, $aDimensions, $level+1, $0,$1,$2,$3,$4,$5,$c,$7,$8)
                Case 7
                    Pickler_Create_Array( $char_array, $pos,$temp, $nDimensions, $aDimensions, $level+1, $0,$1,$2,$3,$4,$5,$6,$c,$8)
                Case 8
                    Pickler_Create_Array( $char_array, $pos,$temp, $nDimensions, $aDimensions, $level+1, $0,$1,$2,$3,$4,$5,$6,$7,$c)

            EndSwitch
        Else
            local $commit_Array = $Pickle_Temp[$temp] ;Slow, but will do for now. WANNA FIGHT ME
            $pos += 1
            Switch $level+1
                Case 1
                    $commit_Array[$c] = Recurse_Var_UNSerialize( $char_array, $pos)
                Case 2
                    $commit_Array[$0][$c] = Recurse_Var_UNSerialize( $char_array, $pos)
                Case 3
                    $commit_Array[$0][$1][$c] = Recurse_Var_UNSerialize( $char_array, $pos)
                Case 4
                    $commit_Array[$0][$1][$2][$c] = Recurse_Var_UNSerialize( $char_array, $pos)
                Case 5
                    $commit_Array[$0][$1][$2][$3][$c] = Recurse_Var_UNSerialize( $char_array, $pos)
                Case 6
                    $commit_Array[$0][$1][$2][$3][$4][$c] = Recurse_Var_UNSerialize( $char_array, $pos)
                Case 7
                    $commit_Array[$0][$1][$2][$3][$4][$5][$c] = Recurse_Var_UNSerialize( $char_array, $pos)
                Case 8
                    $commit_Array[$0][$1][$2][$3][$4][$5][$6][$c] = Recurse_Var_UNSerialize( $char_array, $pos)
            EndSwitch
            $Pickle_Temp[$temp] = $commit_Array
        EndIf
    Next

EndFunc

;Generates the sizes of a requested array.
Func Pickle_Generate_Array( $nDimensions, $aDimensions)
    ;First we create our custom array.
    Switch $nDimensions
        Case 1
            local $TEMP_array[$aDimensions[0]]
        Case 2
            local $TEMP_array[$aDimensions[0]][$aDimensions[1]]
        Case 3
            local $TEMP_array[$aDimensions[0]][$aDimensions[1]][$aDimensions[2]]
        Case 4
            local $TEMP_array[$aDimensions[0]][$aDimensions[1]][$aDimensions[2]][$aDimensions[3]]
        Case 5
            local $TEMP_array[$aDimensions[0]][$aDimensions[1]][$aDimensions[2]][$aDimensions[3]][$aDimensions[4]]
        Case 6
            local $TEMP_array[$aDimensions[0]][$aDimensions[1]][$aDimensions[2]][$aDimensions[3]][$aDimensions[4]][$aDimensions[5]][$aDimensions[6]]
        Case 7
            local $TEMP_array[$aDimensions[0]][$aDimensions[1]][$aDimensions[2]][$aDimensions[3]][$aDimensions[4]][$aDimensions[5]][$aDimensions[6]][$aDimensions[7]]
        Case 8
            local $TEMP_array[$aDimensions[0]][$aDimensions[1]][$aDimensions[2]][$aDimensions[3]][$aDimensions[4]][$aDimensions[5]][$aDimensions[6]][$aDimensions[7]][$aDimensions[8]]
        Case Else
            local $TEMP_array[1]
    EndSwitch

    ;Now we need to allocate a spot for it in storage.
    ReDim $Pickle_Temp[UBound($Pickle_Temp)+1]
    $Pickle_Temp[UBound($Pickle_Temp)-1] = $TEMP_array

    return UBound($Pickle_Temp)-1   ;Give them a handle to the array
EndFunc

Func Pickle_TEMPArray_Free( $index)
    $Pickle_Temp[$index] = 0 ;Guess what? This apparently deletes and releases the memory used by that variable.
EndFunc


;This is a wrapper function to readin the data upto the End Variable (>) Character.
;Avoids Copy pasting :)
Func Pickler_Readin_Datasect( $char_array, ByRef $pos)
    $pos += 2
    $sTemp = ""
    While $char_array[$pos] <> ">" ;Loop through picking up the data.
        $stemp &= $char_array[$pos]
        $pos += 1;Goto next char.
    WEnd
    return $sTemp
EndFunc



;This readsin the next part of the header. Its wrapped in a function to avoid copy paste.
Func Pickler_Readin_HeaderSect( ByRef $char_array, Byref $charpos)
    local $return = ""
    $charpos += 1
    For $d = $charpos to UBound( $char_array)-1 step 1
        $charpos = $d
        if $char_array[$d] = ';' then return $return
        $return &= $char_array[$d]
    Next
    return $return
EndFunc

;Takes an encoded string and returns it to its original form. Returns string.
Func Pickler_De_Encode( $instr)
    local $outstr = ""
    local $spl = StringSplit( $instr, "")

    for $s = 1 to $spl[0] step 1

        If $spl[$s] <> "%" Then ;This is an encoded sequence.
            $outstr &= $spl[$s]
        ElseIf $spl[$s] = ">" then ;This should NOT have happened. We are at the end of a sequence. Lets bail.
            return $outstr
        Else
            $s += 1
            $stemp = ""
            While $spl[$s] <> "%" ;Loop through picking up the Code for the encoded character.
                $stemp &= $spl[$s]
                $s += 1;Goto next char.
            WEnd
            $outstr &= Chr(Number( $stemp));We have the encoded sequence. Convert to original char and commit.
        EndIf

    Next

    return $outstr
EndFunc



;My notes as I was writing it.
;FILE FORMAT SPECS: Start Var: < End Var: > Start+End Header: # Delim: ;
