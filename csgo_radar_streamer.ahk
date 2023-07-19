;F6 - Reload, Hold 3 sec (Silent Exit)
;Silent version for streamers, put any OBS window to your radar
;Always undetectable to VAC, but csgo patrol can catch you, be careful


#NoEnv
#Persistent
#InstallKeybdHook
#SingleInstance, Force
#NoTrayIcon
DetectHiddenWindows, On
SetKeyDelay,-1, -1
SetControlDelay, -1
SetMouseDelay, -1
SendMode Input
SetBatchLines,-1
ListLines, Off

;===================================================================
class _ClassMemory
{
    
    static baseAddress, hProcess, PID, currentProgram
    , insertNullTerminator := True
    , readStringLastError := False
    , isTarget64bit := False
    , ptrType := "UInt"
    , aTypeSize := {    "UChar":    1,  "Char":     1
                    ,   "UShort":   2,  "Short":    2
                    ,   "UInt":     4,  "Int":      4
                    ,   "UFloat":   4,  "Float":    4
                    ,   "Int64":    8,  "Double":   8}  
    , aRights := {  "PROCESS_ALL_ACCESS": 0x001F0FFF
                ,   "PROCESS_CREATE_PROCESS": 0x0080
                ,   "PROCESS_CREATE_THREAD": 0x0002
                ,   "PROCESS_DUP_HANDLE": 0x0040
                ,   "PROCESS_QUERY_INFORMATION": 0x0400
                ,   "PROCESS_QUERY_LIMITED_INFORMATION": 0x1000
                ,   "PROCESS_SET_INFORMATION": 0x0200
                ,   "PROCESS_SET_QUOTA": 0x0100
                ,   "PROCESS_SUSPEND_RESUME": 0x0800
                ,   "PROCESS_TERMINATE": 0x0001
                ,   "PROCESS_VM_OPERATION": 0x0008
                ,   "PROCESS_VM_READ": 0x0010
                ,   "PROCESS_VM_WRITE": 0x0020
                ,   "SYNCHRONIZE": 0x00100000}
    __new(program, dwDesiredAccess := "", byRef handle := "", windowMatchMode := 3)
    {         
        if this.PID := handle := this.findPID(program, windowMatchMode) 
        {
            if dwDesiredAccess is not integer       
                dwDesiredAccess := this.aRights.PROCESS_QUERY_INFORMATION | this.aRights.PROCESS_VM_OPERATION | this.aRights.PROCESS_VM_READ | this.aRights.PROCESS_VM_WRITE
            dwDesiredAccess |= this.aRights.SYNCHRONIZE 
            if this.hProcess := handle := this.OpenProcess(this.PID, dwDesiredAccess) 
            {
                this.pNumberOfBytesRead := DllCall("GlobalAlloc", "UInt", 0x0040, "Ptr", A_PtrSize, "Ptr") 
                this.pNumberOfBytesWritten := DllCall("GlobalAlloc", "UInt", 0x0040, "Ptr", A_PtrSize, "Ptr") 
                this.readStringLastError := False
                this.currentProgram := program
                if this.isTarget64bit := this.isTargetProcess64Bit(this.PID, this.hProcess, dwDesiredAccess)
                    this.ptrType := "Int64"
                else this.ptrType := "UInt" 
                if (A_PtrSize != 4 || !this.isTarget64bit)
                    this.BaseAddress := this.getModuleBaseAddress()
                if this.BaseAddress < 0 || !this.BaseAddress
                    this.BaseAddress := this.getProcessBaseAddress(program, windowMatchMode)            
                return this
            }
        }
        return
    }
    __delete()
    {
        this.closeHandle(this.hProcess)
        if this.pNumberOfBytesRead
            DllCall("GlobalFree", "Ptr", this.pNumberOfBytesRead)
        if this.pNumberOfBytesWritten
            DllCall("GlobalFree", "Ptr", this.pNumberOfBytesWritten)
        return
    }  
    findPID(program, windowMatchMode := "3")
    {
        if RegExMatch(program, "i)\s*AHK_PID\s+(0x[[:xdigit:]]+|\d+)", pid)
            return pid1
        if windowMatchMode
        {
            
            mode := A_TitleMatchMode
            
            StringReplace, windowMatchMode, windowMatchMode, 0x 
            SetTitleMatchMode, %windowMatchMode%
        }
        WinGet, pid, pid, %program%
        if windowMatchMode
            SetTitleMatchMode, %mode% 
        if (!pid && RegExMatch(program, "i)\bAHK_EXE\b\s*(.*)", fileName))
        {
            filename := RegExReplace(filename1, "i)\bahk_(class|id|pid|group)\b.*", "")
            filename := trim(filename)  
            SplitPath, fileName , fileName
            if (fileName) 
            {
                process, Exist, %fileName%
                pid := ErrorLevel
            }
        }
        return pid ? pid : 0 
    }
    isHandleValid()
    {
        return 0x102 = DllCall("WaitForSingleObject", "Ptr", this.hProcess, "UInt", 0)
    }
    openProcess(PID, dwDesiredAccess)
    {
        r := DllCall("OpenProcess", "UInt", dwDesiredAccess, "Int", False, "UInt", PID, "Ptr")
        if (!r && A_LastError = 5)
        {
            this.setSeDebugPrivilege(true) 
            if (r2 := DllCall("OpenProcess", "UInt", dwDesiredAccess, "Int", False, "UInt", PID, "Ptr"))
                return r2
            DllCall("SetLastError", "UInt", 5) 
        }
        return r ? r : ""
    }
    closeHandle(hProcess)
    {
        return DllCall("CloseHandle", "Ptr", hProcess)
    }
    numberOfBytesRead()
    {
        return !this.pNumberOfBytesRead ? -1 : NumGet(this.pNumberOfBytesRead+0, "Ptr")
    }
    numberOfBytesWritten()
    {
        return !this.pNumberOfBytesWritten ? -1 : NumGet(this.pNumberOfBytesWritten+0, "Ptr")
    }
    read(address, type := "UInt", aOffsets*)
    {
        if !this.aTypeSize.hasKey(type)
            return "", ErrorLevel := -2 
        if DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, type "*", result, "Ptr", this.aTypeSize[type], "Ptr", this.pNumberOfBytesRead)
            return result
        return        
    }
    readRaw(address, byRef buffer, bytes := 4, aOffsets*)
    {
        VarSetCapacity(buffer, bytes)
        return DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, "Ptr", &buffer, "Ptr", bytes, "Ptr", this.pNumberOfBytesRead)
    }
    readString(address, sizeBytes := 0, encoding := "UTF-8", aOffsets*)
    {
        bufferSize := VarSetCapacity(buffer, sizeBytes ? sizeBytes : 100, 0)
        this.ReadStringLastError := False
        if aOffsets.maxIndex()
            address := this.getAddressFromOffsets(address, aOffsets*)
        if !sizeBytes  
        {
            
            if (encoding = "utf-16" || encoding = "cp1200")
                encodingSize := 2, charType := "UShort", loopCount := 2
            else encodingSize := 1, charType := "Char", loopCount := 4
            Loop
            {   
                if !DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", address + ((outterIndex := A_index) - 1) * 4, "Ptr", &buffer, "Ptr", 4, "Ptr", this.pNumberOfBytesRead) || ErrorLevel
                    return "", this.ReadStringLastError := True 
                else loop, %loopCount%
                {
                    if NumGet(buffer, (A_Index - 1) * encodingSize, charType) = 0 
                    {
                        if (bufferSize < sizeBytes := outterIndex * 4 - (4 - A_Index * encodingSize)) 
                            VarSetCapacity(buffer, sizeBytes)
                        break, 2
                    }  
                } 
            }
        }
        if DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", address, "Ptr", &buffer, "Ptr", sizeBytes, "Ptr", this.pNumberOfBytesRead)   
            return StrGet(&buffer,, encoding)  
        return "", this.ReadStringLastError := True             
    }
    writeString(address, string, encoding := "utf-8", aOffsets*)
    {
        encodingSize := (encoding = "utf-16" || encoding = "cp1200") ? 2 : 1
        requiredSize := StrPut(string, encoding) * encodingSize - (this.insertNullTerminator ? 0 : encodingSize)
        VarSetCapacity(buffer, requiredSize)
        StrPut(string, &buffer, StrLen(string) + (this.insertNullTerminator ?  1 : 0), encoding)
        return DllCall("WriteProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, "Ptr", &buffer, "Ptr", requiredSize, "Ptr", this.pNumberOfBytesWritten)
    }
    write(address, value, type := "Uint", aOffsets*)
    {
        if !this.aTypeSize.hasKey(type)
            return "", ErrorLevel := -2 
        return DllCall("WriteProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, type "*", value, "Ptr", this.aTypeSize[type], "Ptr", this.pNumberOfBytesWritten) 
    }
    writeRaw(address, pBuffer, sizeBytes, aOffsets*)
    {
        return DllCall("WriteProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, "Ptr", pBuffer, "Ptr", sizeBytes, "Ptr", this.pNumberOfBytesWritten) 
    }
    writeBytes(address, hexStringOrByteArray, aOffsets*)
    {
        if !IsObject(hexStringOrByteArray)
        {
            if !IsObject(hexStringOrByteArray := this.hexStringToPattern(hexStringOrByteArray))
                return hexStringOrByteArray
        }
        sizeBytes := this.getNeedleFromAOBPattern("", buffer, hexStringOrByteArray*)
        return this.writeRaw(address, &buffer, sizeBytes, aOffsets*)
    }
    pointer(address, finalType := "UInt", offsets*)
    { 
        For index, offset in offsets
            address := this.Read(address, this.ptrType) + offset 
        Return this.Read(address, finalType)
    }
    getAddressFromOffsets(address, aOffsets*)
    {
        return  aOffsets.Remove() + this.pointer(address, this.ptrType, aOffsets*) 
    }
    getProcessBaseAddress(windowTitle, windowMatchMode := "3")   
    {
        if (windowMatchMode && A_TitleMatchMode != windowMatchMode)
        {
            mode := A_TitleMatchMode 
            StringReplace, windowMatchMode, windowMatchMode, 0x 
            SetTitleMatchMode, %windowMatchMode%    
        }
        WinGet, hWnd, ID, %WindowTitle%
        if mode
            SetTitleMatchMode, %mode%    
        if !hWnd
            return 
        return DllCall(A_PtrSize = 4     
            ? "GetWindowLong"
            : "GetWindowLongPtr"
            , "Ptr", hWnd, "Int", -6, A_Is64bitOS ? "Int64" : "UInt") 
    }
    getModuleBaseAddress(moduleName := "", byRef aModuleInfo := "")
    {
        aModuleInfo := ""
        if (moduleName = "")
            moduleName := this.GetModuleFileNameEx(0, True) 
        if r := this.getModules(aModules, True) < 0
            return r 
        return aModules.HasKey(moduleName) ? (aModules[moduleName].lpBaseOfDll, aModuleInfo := aModules[moduleName]) : -1
        
    }
    getModuleFromAddress(address, byRef aModuleInfo, byRef offsetFromModuleBase := "") 
    {
        aModuleInfo := offsetFromModule := ""
        if result := this.getmodules(aModules) < 0
            return result 
        for k, module in aModules 
        {
            if (address >= module.lpBaseOfDll && address < module.lpBaseOfDll + module.SizeOfImage)
                return 1, aModuleInfo := module, offsetFromModuleBase := address - module.lpBaseOfDll
        }    
        return -1    
    }
    setSeDebugPrivilege(enable := True)
    {
        h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", DllCall("GetCurrentProcessId"), "Ptr")
        
        DllCall("Advapi32.dll\OpenProcessToken", "Ptr", h, "UInt", 32, "PtrP", t)
        VarSetCapacity(ti, 16, 0)  
        NumPut(1, ti, 0, "UInt")  
        
        DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", "SeDebugPrivilege", "Int64P", luid)
        NumPut(luid, ti, 4, "Int64")
        if enable
            NumPut(2, ti, 12, "UInt")  
        
        r := DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", t, "Int", false, "Ptr", &ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
        DllCall("CloseHandle", "Ptr", t)  
        DllCall("CloseHandle", "Ptr", h)  
        return r
    }
    isTargetProcess64Bit(PID, hProcess := "", currentHandleAccess := "")
    {
        if !A_Is64bitOS
            return False 
        
        else if !hProcess || !(currentHandleAccess & (this.aRights.PROCESS_QUERY_INFORMATION | this.aRights.PROCESS_QUERY_LIMITED_INFORMATION))
            closeHandle := hProcess := this.openProcess(PID, this.aRights.PROCESS_QUERY_INFORMATION)
        if (hProcess && DllCall("IsWow64Process", "Ptr", hProcess, "Int*", Wow64Process))
            result := !Wow64Process
        return result, closeHandle ? this.CloseHandle(hProcess) : ""
    }
    suspend()
    {
        return DllCall("ntdll\NtSuspendProcess", "Ptr", this.hProcess)
    } 
    resume()
    {
        return DllCall("ntdll\NtResumeProcess", "Ptr", this.hProcess)
    }
    getModules(byRef aModules, useFileNameAsKey := False)
    {
        if (A_PtrSize = 4 && this.IsTarget64bit)
            return -4 
        aModules := []
        if !moduleCount := this.EnumProcessModulesEx(lphModule)
            return -3  
        loop % moduleCount
        {
            this.GetModuleInformation(hModule := numget(lphModule, (A_index - 1) * A_PtrSize), aModuleInfo)
            aModuleInfo.Name := this.GetModuleFileNameEx(hModule)
            filePath := aModuleInfo.name
            SplitPath, filePath, fileName
            aModuleInfo.fileName := fileName
            if useFileNameAsKey
                aModules[fileName] := aModuleInfo
            else aModules.insert(aModuleInfo)
        }
        return moduleCount        
    }
    getEndAddressOfLastModule(byRef aModuleInfo := "")
    {
        if !moduleCount := this.EnumProcessModulesEx(lphModule)
            return -3     
        hModule := numget(lphModule, (moduleCount - 1) * A_PtrSize)
        if this.GetModuleInformation(hModule, aModuleInfo)
            return aModuleInfo.lpBaseOfDll + aModuleInfo.SizeOfImage
        return -5
    }
    GetModuleFileNameEx(hModule := 0, fileNameNoPath := False)
    {
        
        
        VarSetCapacity(lpFilename, 2048 * (A_IsUnicode ? 2 : 1)) 
        DllCall("psapi\GetModuleFileNameEx"
                    , "Ptr", this.hProcess
                    , "Ptr", hModule
                    , "Str", lpFilename
                    , "Uint", 2048 / (A_IsUnicode ? 2 : 1))
        if fileNameNoPath
            SplitPath, lpFilename, lpFilename 
        return lpFilename
    }
    EnumProcessModulesEx(byRef lphModule, dwFilterFlag := 0x03)
    {
        lastError := A_LastError
        size := VarSetCapacity(lphModule, 4)
        loop 
        {
            DllCall("psapi\EnumProcessModulesEx"
                        , "Ptr", this.hProcess
                        , "Ptr", &lphModule
                        , "Uint", size
                        , "Uint*", reqSize
                        , "Uint", dwFilterFlag)
            if ErrorLevel
                return 0
            else if (size >= reqSize)
                break
            else size := VarSetCapacity(lphModule, reqSize)  
        }
        
        
        DllCall("SetLastError", "UInt", lastError)
        return reqSize // A_PtrSize 
    }
    GetModuleInformation(hModule, byRef aModuleInfo)
    {
        VarSetCapacity(MODULEINFO, A_PtrSize * 3), aModuleInfo := []
        return DllCall("psapi\GetModuleInformation"
                    , "Ptr", this.hProcess
                    , "Ptr", hModule
                    , "Ptr", &MODULEINFO
                    , "UInt", A_PtrSize * 3)
                , aModuleInfo := {  lpBaseOfDll: numget(MODULEINFO, 0, "Ptr")
                                ,   SizeOfImage: numget(MODULEINFO, A_PtrSize, "UInt")
                                ,   EntryPoint: numget(MODULEINFO, A_PtrSize * 2, "Ptr") }
    }
    hexStringToPattern(hexString)
    {
        AOBPattern := []
        hexString := RegExReplace(hexString, "(\s|0x)")
        StringReplace, hexString, hexString, ?, ?, UseErrorLevel
        wildCardCount := ErrorLevel
        if !length := StrLen(hexString)
            return -1 
        else if RegExMatch(hexString, "[^0-9a-fA-F?]")
            return -2 
        else if Mod(wildCardCount, 2)
            return -3 
        else if Mod(length, 2)
            return -4 
        loop, % length/2
        {
            value := "0x" SubStr(hexString, 1 + 2 * (A_index-1), 2)
            AOBPattern.Insert(value + 0 = "" ? "?" : value)
        }
        return AOBPattern
    }
    stringToPattern(string, encoding := "UTF-8", insertNullTerminator := False)
    {   
        if !length := StrLen(string)
            return -1 
        AOBPattern := []
        encodingSize := (encoding = "utf-16" || encoding = "cp1200") ? 2 : 1
        requiredSize := StrPut(string, encoding) * encodingSize - (insertNullTerminator ? 0 : encodingSize)
        VarSetCapacity(buffer, requiredSize)
        StrPut(string, &buffer, length + (insertNullTerminator ?  1 : 0), encoding) 
        loop, % requiredSize
            AOBPattern.Insert(NumGet(buffer, A_Index-1, "UChar"))
        return AOBPattern
    }
    modulePatternScan(module := "", aAOBPattern*)
    {
        MEM_COMMIT := 0x1000, MEM_MAPPED := 0x40000, MEM_PRIVATE := 0x20000
        , PAGE_NOACCESS := 0x01, PAGE_GUARD := 0x100
        if (result := this.getModuleBaseAddress(module, aModuleInfo)) <= 0
             return "", ErrorLevel := result 
        if !patternSize := this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10 
        
        
        if (result := this.PatternScan(aModuleInfo.lpBaseOfDll, aModuleInfo.SizeOfImage, patternMask, AOBBuffer)) >= 0
            return result  
        
        address := aModuleInfo.lpBaseOfDll
        endAddress := address + aModuleInfo.SizeOfImage
        loop 
        {
            if !this.VirtualQueryEx(address, aRegion)
                return -9
            if (aRegion.State = MEM_COMMIT 
            && !(aRegion.Protect & (PAGE_NOACCESS | PAGE_GUARD)) 
            
            && aRegion.RegionSize >= patternSize
            && (result := this.PatternScan(address, aRegion.RegionSize, patternMask, AOBBuffer)) > 0)
                return result
        } until (address += aRegion.RegionSize) >= endAddress
        return 0       
    }
    addressPatternScan(startAddress, sizeOfRegionBytes, aAOBPattern*)
    {
        if !this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10
        return this.PatternScan(startAddress, sizeOfRegionBytes, patternMask, AOBBuffer)   
    }
    processPatternScan(startAddress := 0, endAddress := "", aAOBPattern*)
    {
        address := startAddress
        if endAddress is not integer  
            endAddress := this.isTarget64bit ? (A_PtrSize = 8 ? 0x7FFFFFFFFFF : 0xFFFFFFFF) : 0x7FFFFFFF
        MEM_COMMIT := 0x1000, MEM_MAPPED := 0x40000, MEM_PRIVATE := 0x20000
        PAGE_NOACCESS := 0x01, PAGE_GUARD := 0x100
        if !patternSize := this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10  
        while address <= endAddress 
        {
            if !this.VirtualQueryEx(address, aInfo)
                return -1
            if A_Index = 1
                aInfo.RegionSize -= address - aInfo.BaseAddress
            if (aInfo.State = MEM_COMMIT) 
            && !(aInfo.Protect & (PAGE_NOACCESS | PAGE_GUARD)) 
            
            && aInfo.RegionSize >= patternSize
            && (result := this.PatternScan(address, aInfo.RegionSize, patternMask, AOBBuffer))
            {
                if result < 0 
                    return -2
                else if (result + patternSize - 1 <= endAddress)
                    return result
                else return 0
            }
            address += aInfo.RegionSize
        }
        return 0
    }
    rawPatternScan(byRef buffer, sizeOfBufferBytes := "", startOffset := 0, aAOBPattern*)
    {
        if !this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10
        if (sizeOfBufferBytes + 0 = "" || sizeOfBufferBytes <= 0)
            sizeOfBufferBytes := VarSetCapacity(buffer)
        if (startOffset + 0 = "" || startOffset < 0)
            startOffset := 0
        return this.bufferScanForMaskedPattern(&buffer, sizeOfBufferBytes, patternMask, &AOBBuffer, startOffset)           
    }
    getNeedleFromAOBPattern(byRef patternMask, byRef needleBuffer, aAOBPattern*)
    {
        patternMask := "", VarSetCapacity(needleBuffer, aAOBPattern.MaxIndex())
        for i, v in aAOBPattern
            patternMask .= (v + 0 = "" ? "?" : "x"), NumPut(round(v), needleBuffer, A_Index - 1, "UChar")
        return round(aAOBPattern.MaxIndex())
    }
    VirtualQueryEx(address, byRef aInfo)
    {
        if (aInfo.__Class != "_ClassMemory._MEMORY_BASIC_INFORMATION")
            aInfo := new this._MEMORY_BASIC_INFORMATION()
        return aInfo.SizeOfStructure = DLLCall("VirtualQueryEx" 
                                                , "Ptr", this.hProcess
                                                , "Ptr", address
                                                , "Ptr", aInfo.pStructure
                                                , "Ptr", aInfo.SizeOfStructure
                                                , "Ptr") 
    }
    patternScan(startAddress, sizeOfRegionBytes, byRef patternMask, byRef needleBuffer)
    {
        if !this.readRaw(startAddress, buffer, sizeOfRegionBytes)
            return -1      
        if (offset := this.bufferScanForMaskedPattern(&buffer, sizeOfRegionBytes, patternMask, &needleBuffer)) >= 0
            return startAddress + offset 
        else return 0
    }
    bufferScanForMaskedPattern(hayStackAddress, sizeOfHayStackBytes, byRef patternMask, needleAddress, startOffset := 0)
    {
        static p
        if !p
        {
            if A_PtrSize = 4    
                p := this.MCode("1,x86:8B44240853558B6C24182BC5568B74242489442414573BF0773E8B7C241CBB010000008B4424242BF82BD8EB038D49008B54241403D68A0C073A0A740580383F750B8D0C033BCD74174240EBE98B442424463B74241876D85F5E5D83C8FF5BC35F8BC65E5D5BC3")
            else 
                p := this.MCode("1,x64:48895C2408488974241048897C2418448B5424308BF2498BD8412BF1488BF9443BD6774A4C8B5C24280F1F800000000033C90F1F400066660F1F840000000000448BC18D4101418D4AFF03C80FB60C3941380C18740743803C183F7509413BC1741F8BC8EBDA41FFC2443BD676C283C8FF488B5C2408488B742410488B7C2418C3488B5C2408488B742410488B7C2418418BC2C3")
        }
        if (needleSize := StrLen(patternMask)) + startOffset > sizeOfHayStackBytes
            return -1 
        if (sizeOfHayStackBytes > 0)
            return DllCall(p, "Ptr", hayStackAddress, "UInt", sizeOfHayStackBytes, "Ptr", needleAddress, "UInt", needleSize, "AStr", patternMask, "UInt", startOffset, "cdecl int")
        return -2
    }
    MCode(mcode)
    {
        static e := {1:4, 2:1}, c := (A_PtrSize=8) ? "x64" : "x86"
        if !regexmatch(mcode, "^([0-9]+),(" c ":|.*?," c ":)([^,]+)", m)
            return
        if !DllCall("crypt32\CryptStringToBinary", "str", m3, "uint", 0, "uint", e[m1], "ptr", 0, "uint*", s, "ptr", 0, "ptr", 0)
            return
        p := DllCall("GlobalAlloc", "uint", 0, "ptr", s, "ptr")
        
        DllCall("VirtualProtect", "ptr", p, "ptr", s, "uint", 0x40, "uint*", op)
        if DllCall("crypt32\CryptStringToBinary", "str", m3, "uint", 0, "uint", e[m1], "ptr", p, "uint*", s, "ptr", 0, "ptr", 0)
            return p
        DllCall("GlobalFree", "ptr", p)
        return
    }
    class _MEMORY_BASIC_INFORMATION
    {
        __new()
        {   
            if !this.pStructure := DllCall("GlobalAlloc", "UInt", 0, "Ptr", this.SizeOfStructure := A_PtrSize = 8 ? 48 : 28, "Ptr")
                return ""
            return this
        }
        __Delete()
        {
            DllCall("GlobalFree", "Ptr", this.pStructure)
        }
        
        __get(key)
        {
            static aLookUp := A_PtrSize = 8 
                                ?   {   "BaseAddress": {"Offset": 0, "Type": "Int64"}
                                    ,    "AllocationBase": {"Offset": 8, "Type": "Int64"}
                                    ,    "AllocationProtect": {"Offset": 16, "Type": "UInt"}
                                    ,    "RegionSize": {"Offset": 24, "Type": "Int64"}
                                    ,    "State": {"Offset": 32, "Type": "UInt"}
                                    ,    "Protect": {"Offset": 36, "Type": "UInt"}
                                    ,    "Type": {"Offset": 40, "Type": "UInt"} }
                                :   {  "BaseAddress": {"Offset": 0, "Type": "UInt"}
                                    ,   "AllocationBase": {"Offset": 4, "Type": "UInt"}
                                    ,   "AllocationProtect": {"Offset": 8, "Type": "UInt"}
                                    ,   "RegionSize": {"Offset": 12, "Type": "UInt"}
                                    ,   "State": {"Offset": 16, "Type": "UInt"}
                                    ,   "Protect": {"Offset": 20, "Type": "UInt"}
                                    ,   "Type": {"Offset": 24, "Type": "UInt"} }
            if aLookUp.HasKey(key)
                return numget(this.pStructure+0, aLookUp[key].Offset, aLookUp[key].Type)        
        }
        __set(key, value)
        {
             static aLookUp := A_PtrSize = 8 
                                ?   {   "BaseAddress": {"Offset": 0, "Type": "Int64"}
                                    ,    "AllocationBase": {"Offset": 8, "Type": "Int64"}
                                    ,    "AllocationProtect": {"Offset": 16, "Type": "UInt"}
                                    ,    "RegionSize": {"Offset": 24, "Type": "Int64"}
                                    ,    "State": {"Offset": 32, "Type": "UInt"}
                                    ,    "Protect": {"Offset": 36, "Type": "UInt"}
                                    ,    "Type": {"Offset": 40, "Type": "UInt"} }
                                :   {  "BaseAddress": {"Offset": 0, "Type": "UInt"}
                                    ,   "AllocationBase": {"Offset": 4, "Type": "UInt"}
                                    ,   "AllocationProtect": {"Offset": 8, "Type": "UInt"}
                                    ,   "RegionSize": {"Offset": 12, "Type": "UInt"}
                                    ,   "State": {"Offset": 16, "Type": "UInt"}
                                    ,   "Protect": {"Offset": 20, "Type": "UInt"}
                                    ,   "Type": {"Offset": 24, "Type": "UInt"} }
            if aLookUp.HasKey(key)
            {
                NumPut(value, this.pStructure+0, aLookUp[key].Offset, aLookUp[key].Type)            
                return value
            }
        }
        Ptr()
        {
            return this.pStructure
        }
        sizeOf()
        {
            return this.SizeOfStructure
        }
    }
}

;===================================================================

Global timestamp
Global cs_gamerules_data
Global m_ArmorValue
Global m_Collision
Global m_CollisionGroup
Global m_Local
Global m_MoveType
Global m_OriginalOwnerXuidHigh
Global m_OriginalOwnerXuidLow
Global m_SurvivalGameRuleDecisionTypes
Global m_SurvivalRules
Global m_aimPunchAngle
Global m_aimPunchAngleVel
Global m_angEyeAnglesX
Global m_angEyeAnglesY
Global m_bBombDefused
Global m_bBombPlanted
Global m_bBombTicking
Global m_bFreezePeriod
Global m_bGunGameImmunity
Global m_bHasDefuser
Global m_bHasHelmet
Global m_bInReload
Global m_bIsDefusing
Global m_bIsQueuedMatchmaking
Global m_bIsScoped
Global m_bIsValveDS
Global m_bSpotted
Global m_bSpottedByMask
Global m_bStartedArming
Global m_bUseCustomAutoExposureMax
Global m_bUseCustomAutoExposureMin
Global m_bUseCustomBloomScale
Global m_clrRender
Global m_dwBoneMatrix
Global m_fAccuracyPenalty
Global m_fFlags
Global m_flC4Blow
Global m_flCustomAutoExposureMax
Global m_flCustomAutoExposureMin
Global m_flCustomBloomScale
Global m_flDefuseCountDown
Global m_flDefuseLength
Global m_flFallbackWear
Global m_flFlashDuration
Global m_flFlashMaxAlpha
Global m_flLastBoneSetupTime
Global m_flLowerBodyYawTarget
Global m_flNextAttack
Global m_flNextPrimaryAttack
Global m_flSimulationTime
Global m_flTimerLength
Global m_hActiveWeapon
Global m_hBombDefuser
Global m_hMyWeapons
Global m_hObserverTarget
Global m_hOwner
Global m_hOwnerEntity
Global m_hViewModel
Global m_iAccountID
Global m_iClip1
Global m_iCompetitiveRanking
Global m_iCompetitiveWins
Global m_iCrosshairId
Global m_iDefaultFOV
Global m_iEntityQuality
Global m_iFOVStart
Global m_iHealth
Global m_iItemDefinitionIndex
Global m_iItemIDHigh
Global m_iMostRecentModelBoneCounter
Global m_iObserverMode
Global m_iShotsFired
Global m_iState
Global m_iTeamNum
Global m_lifeState
Global m_nBombSite
Global m_nFallbackPaintKit
Global m_nFallbackSeed
Global m_nFallbackStatTrak
Global m_nForceBone
Global m_nTickBase
Global m_nViewModelIndex
Global m_rgflCoordinateFrame
Global m_szCustomName
Global m_szLastPlaceName
Global m_thirdPersonViewAngles
Global m_vecOrigin
Global m_vecVelocity
Global m_vecViewOffset
Global m_viewPunchAngle
Global m_zoomLevel

Global anim_overlays
Global clientstate_choked_commands
Global clientstate_delta_ticks
Global clientstate_last_outgoing_command
Global clientstate_net_channel
Global convar_name_hash_table
Global dwClientState
Global dwClientState_GetLocalPlayer
Global dwClientState_IsHLTV
Global dwClientState_Map
Global dwClientState_MapDirectory
Global dwClientState_MaxPlayer
Global dwClientState_PlayerInfo
Global dwClientState_State
Global dwClientState_ViewAngles
Global dwEntityList
Global dwForceAttack
Global dwForceAttack2
Global dwForceBackward
Global dwForceForward
Global dwForceJump
Global dwForceLeft
Global dwForceRight
Global dwGameDir
Global dwGameRulesProxy
Global dwGetAllClasses
Global dwGlobalVars
Global dwInput
Global dwInterfaceLinkList
Global dwLocalPlayer
Global dwMouseEnable
Global dwMouseEnablePtr
Global dwPlayerResource
Global dwRadarBase
Global dwSensitivity
Global dwSensitivityPtr
Global dwSetClanTag
Global dwViewMatrix
Global dwWeaponTable
Global dwWeaponTableIndex
Global dwYawPtr
Global dwZoomSensitivityRatioPtr
Global dwbSendPackets
Global dwppDirect3DDevice9
Global find_hud_element
Global interface_engine_cvar
Global is_c4_owner
Global m_bDormant
Global m_flSpawnTime
Global m_pStudioHdr
Global m_pitchClassPtr
Global m_yawClassPtr
Global model_ambient_min
Global set_abs_angles
Global set_abs_origin


Read_csgo_offsets_from_hazedumper() {
	whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	whr.Open("GET", "https://raw.githubusercontent.com/frk1/hazedumper/master/csgo.toml", true)
	whr.Send()
	whr.WaitForResponse(-1)
	
	CsgoOffsets := whr.ResponseText
	if InStr(CsgoOffsets, "Not Found")
		Return False

	SetFormat, integer, H
	Loop, parse, CsgoOffsets, `n,`r
	{
		item := A_LoopField
		if !InStr(item, "=")
			Continue
		n := 1
		Loop, parse, item, =
		{
			if (n=1) {
				Str = %A_LoopField%
				n += 1
			} Else if (n=2) {
				%Str% := A_LoopField<<0
			}
		}
	}
	Return True
}
;===================================================================
if !Read_csgo_offsets_from_hazedumper() {
	MsgBox, 48, Error, Failed to get csgo offsets!
    ExitApp
}
if (_ClassMemory.__Class != "_ClassMemory") {
    msgbox class memory not correctly installed. Or the (global class) variable "_ClassMemory" has been overwritten
    ExitApp
}
;===================================================================
;ItemDefinitionIndex
Global WEAPON_NONE := 0
Global WEAPON_DEAGLE := 1
Global WEAPON_ELITE := 2
Global WEAPON_FIVESEVEN := 3
Global WEAPON_GLOCK := 4
Global WEAPON_AK47 := 7
Global WEAPON_AUG := 8
Global WEAPON_AWP := 9
Global WEAPON_FAMAS := 10
Global WEAPON_G3SG1 := 11
Global WEAPON_GALILAR := 13
Global WEAPON_M249 := 14
Global WEAPON_M4A1 := 16
Global WEAPON_MAC10 := 17
Global WEAPON_P90 := 19
Global WEAPON_MP5SD := 23
Global WEAPON_UMP45 := 24
Global WEAPON_XM1014 := 25
Global WEAPON_BIZON := 26
Global WEAPON_MAG7 := 27
Global WEAPON_NEGEV := 28
Global WEAPON_SAWEDOFF := 29
Global WEAPON_TEC9 := 30
Global WEAPON_TASER := 31
Global WEAPON_HKP2000 := 32
Global WEAPON_MP7 := 33
Global WEAPON_MP9 := 34
Global WEAPON_NOVA := 35
Global WEAPON_P250 := 36
Global WEAPON_SCAR20 := 38
Global WEAPON_SG556 := 39
Global WEAPON_SSG08 := 40
Global WEAPON_KNIFE_GG := 41
Global WEAPON_KNIFE_CT := 42
Global WEAPON_FLASHBANG := 43
Global WEAPON_HEGRENADE := 44
Global WEAPON_SMOKEGRENADE := 45
Global WEAPON_MOLOTOV := 46
Global WEAPON_DECOY := 47
Global WEAPON_INCGRENADE := 48
Global WEAPON_C4 := 49
Global WEAPON_HEALTHSHOT := 57
Global WEAPON_KNIFE_T := 59
Global WEAPON_M4A1_SILENCER := 60
Global WEAPON_USP_SILENCER := 61
Global WEAPON_CZ75A := 63
Global WEAPON_REVOLVER := 64
Global WEAPON_TAGRENADE := 68
Global WEAPON_FISTS := 69
Global WEAPON_BREACHCHARGE := 70
Global WEAPON_TABLET := 72
;Global WEAPON_MELEE := 74	;prefab
Global WEAPON_AXE := 75
Global WEAPON_HAMMER := 76
Global WEAPON_SPANNER := 78
Global WEAPON_KNIFE_GHOST := 80
Global WEAPON_FIREBOMB := 81
Global WEAPON_DIVERSION := 82
Global WEAPON_FRAG_GRENADE := 83
Global WEAPON_KNIFE_BAYONET := 500
Global WEAPON_KNIFE_FLIP := 505
Global WEAPON_KNIFE_GUT := 506
Global WEAPON_KNIFE_KARAMBIT := 507
Global WEAPON_KNIFE_M9_BAYONET := 508
Global WEAPON_KNIFE_TACTICAL := 509
Global WEAPON_KNIFE_FALCHION := 512
Global WEAPON_KNIFE_SURVIVAL_BOWIE := 514
Global WEAPON_KNIFE_BUTTERFLY := 515
Global WEAPON_KNIFE_PUSH := 516
Global WEAPON_KNIFE_URSUS := 519
Global WEAPON_KNIFE_GYPSY_JACKKNIFE := 520
Global WEAPON_KNIFE_STILETTO := 522
Global WEAPON_KNIFE_WIDOWMAKER := 523

;CSWeaponType
Global WEAPONTYPE_KNIFE         := 0
Global WEAPONTYPE_PISTOL        := 1
Global WEAPONTYPE_SUBMACHINEGUN := 2
Global WEAPONTYPE_RIFLE         := 3
Global WEAPONTYPE_SHOTGUN       := 4
Global WEAPONTYPE_SNIPER_RIFLE  := 5
Global WEAPONTYPE_MACHINEGUN    := 6
Global WEAPONTYPE_C4            := 7
Global WEAPONTYPE_GRENADE       := 9
Global WEAPONTYPE_STACKABLE     := 11
Global WEAPONTYPE_FISTS         := 12
Global WEAPONTYPE_BREACHCHARGE  := 13
Global WEAPONTYPE_TABLET        := 14
Global WEAPONTYPE_MELEE         := 15
Global WEAPONTYPE_UNKNOWN       := 16

GetWeaponType(itemDefIndex) {
	switch (itemDefIndex) {
		case WEAPON_TASER
		, WEAPON_KNIFE_GG
		, WEAPON_KNIFE_CT
		, WEAPON_KNIFE_T
		, WEAPON_KNIFE_GHOST
		, WEAPON_KNIFE_BAYONET
		, WEAPON_KNIFE_FLIP
		, WEAPON_KNIFE_GUT
		, WEAPON_KNIFE_KARAMBIT
		, WEAPON_KNIFE_M9_BAYONET
		, WEAPON_KNIFE_TACTICAL
		, WEAPON_KNIFE_FALCHION
		, WEAPON_KNIFE_SURVIVAL_BOWIE
		, WEAPON_KNIFE_BUTTERFLY
		, WEAPON_KNIFE_PUSH
		, WEAPON_KNIFE_URSUS
		, WEAPON_KNIFE_GYPSY_JACKKNIFE
		, WEAPON_KNIFE_STILETTO
		, WEAPON_KNIFE_WIDOWMAKER:
			return WEAPONTYPE_KNIFE
		case WEAPON_DEAGLE
		, WEAPON_ELITE
		, WEAPON_FIVESEVEN
		, WEAPON_GLOCK
		, WEAPON_TEC9
		, WEAPON_HKP2000
		, WEAPON_P250
		, WEAPON_USP_SILENCER
		, WEAPON_CZ75A
		, WEAPON_REVOLVER:
			return WEAPONTYPE_PISTOL
		case WEAPON_MAC10
		, WEAPON_P90
		, WEAPON_MP5SD
		, WEAPON_UMP45
		, WEAPON_BIZON
		, WEAPON_MP7
		, WEAPON_MP9:
			return WEAPONTYPE_SUBMACHINEGUN
		case WEAPON_AK47
		, WEAPON_AUG
		, WEAPON_FAMAS
		, WEAPON_GALILAR
		, WEAPON_M4A1
		, WEAPON_SG556
		, WEAPON_M4A1_SILENCER:
			return WEAPONTYPE_RIFLE
		case WEAPON_XM1014
		, WEAPON_MAG7
		, WEAPON_SAWEDOFF
		, WEAPON_NOVA:
			return WEAPONTYPE_SHOTGUN
		case WEAPON_AWP
		, WEAPON_G3SG1
		, WEAPON_SCAR20
		, WEAPON_SSG08:
			return WEAPONTYPE_SNIPER_RIFLE
		case WEAPON_M249
		, WEAPON_NEGEV:
			return WEAPONTYPE_MACHINEGUN
		case WEAPON_C4:
			return WEAPONTYPE_C4
		case WEAPON_FLASHBANG
		, WEAPON_HEGRENADE
		, WEAPON_SMOKEGRENADE
		, WEAPON_MOLOTOV
		, WEAPON_DECOY
		, WEAPON_INCGRENADE
		, WEAPON_TAGRENADE
		, WEAPON_FIREBOMB
		, WEAPON_DIVERSION
		, WEAPON_FRAG_GRENADE:
			return WEAPONTYPE_GRENADE
		case WEAPON_FISTS:
			return WEAPONTYPE_FISTS
		case WEAPON_BREACHCHARGE:
			return WEAPONTYPE_BREACHCHARGE
		case WEAPON_TABLET:
			return WEAPONTYPE_TABLET
		case WEAPON_AXE
		, WEAPON_HAMMER
		, WEAPON_SPANNER:
			return WEAPONTYPE_MELEE
		default:
			return WEAPONTYPE_UNKNOWN
	}
}

Class CWeapon {
	__New(entity) {
		csgo.readRaw(entity, ent_struct, m_zoomLevel+0x4)
		this.m_OriginalOwnerXuidHigh := NumGet(ent_struct, m_OriginalOwnerXuidHigh, "int")
		,this.m_OriginalOwnerXuidLow := NumGet(ent_struct, m_OriginalOwnerXuidLow, "int")
		,this.m_iItemDefinitionIndex := NumGet(ent_struct, m_iItemDefinitionIndex, "Short")
		,this.m_flNextPrimaryAttack  := NumGet(ent_struct, m_flNextPrimaryAttack, "Float")
		,this.m_iClip1               := NumGet(ent_struct, m_iClip1, "int")
		,this.m_bInReload            := NumGet(ent_struct, m_bInReload, "char")
		,this.m_fAccuracyPenalty     := NumGet(ent_struct, m_fAccuracyPenalty, "Float")
		,this.m_nFallbackPaintKit    := NumGet(ent_struct, m_nFallbackPaintKit, "int")
		,this.m_zoomLevel            := NumGet(ent_struct, m_zoomLevel, "int")
	}
}
;===================================================================

;Move types
Global MOVETYPE := {}
MOVETYPE.NONE       := 0
MOVETYPE.ISOMETRIC  := 1
MOVETYPE.WALK       := 2
MOVETYPE.STEP       := 3
MOVETYPE.FLY        := 4
MOVETYPE.FLYGRAVITY := 5
MOVETYPE.VPHYSICS   := 6
MOVETYPE.PUSH       := 7
MOVETYPE.NOCLIP     := 8
MOVETYPE.LADDER     := 9
MOVETYPE.OBSERVER   := 10

;Flags
Global FL_ONGROUND    := 1<<0
Global FL_DUCKING     := 1<<1
Global FL_ANIMDUCKING := 1<<2
Global FL_WATERJUMP   := 1<<3
Global FL_ONTRAIN     := 1<<4
Global FL_INRAIN      := 1<<5
Global FL_FROZEN      := 1<<6
Global FL_ATCONTROLS  := 1<<7
Global FL_CLIENT      := 1<<8
Global FL_FAKECLIENT  := 1<<9
Global FL_INWATER     := 1<<10

Class CPlayer {
	__New(entity) {
		csgo.readRaw(entity, ent_struct, m_iCrosshairId+0x4)
		this.entity             := entity
		,this.m_aimPunchAngle   := [NumGet(ent_struct, m_aimPunchAngle, "Float"), NumGet(ent_struct, m_aimPunchAngle+0x4, "Float")]
		,this.m_bIsScoped       := NumGet(ent_struct, m_bIsScoped, "int")
		,this.m_bSpotted        := NumGet(ent_struct, m_bSpotted, "int")
		,this.m_bSpottedByMask  := NumGet(ent_struct, m_bSpottedByMask, "int")
		,this.m_dwBoneMatrix    := NumGet(ent_struct, m_dwBoneMatrix, "int")
		,this.m_fFlags          := NumGet(ent_struct, m_fFlags, "int")
		,this.m_flFlashDuration := NumGet(ent_struct, m_flFlashDuration, "Float")
		,this.m_flFlashMaxAlpha := NumGet(ent_struct, m_flFlashMaxAlpha, "Float") 
		,this.m_iCrosshairId    := NumGet(ent_struct, m_iCrosshairId, "int")
		,this.m_iDefaultFOV     := NumGet(ent_struct, m_iDefaultFOV, "int") 
		,this.m_hActiveWeapon   := NumGet(ent_struct, m_hActiveWeapon, "int")
		,this.m_hMyWeapons      := NumGet(ent_struct, m_hMyWeapons, "int")
		,this.m_hViewModel      := NumGet(ent_struct, m_hViewModel, "int")
		,this.m_iShotsFired     := NumGet(ent_struct, m_iShotsFired, "int")
		,this.m_iHealth         := NumGet(ent_struct, m_iHealth, "int")
		,this.m_iTeamNum        := NumGet(ent_struct, m_iTeamNum, "int")
		,this.m_lifeState       := NumGet(ent_struct, m_lifeState, "int")
		,this.m_nTickBase       := NumGet(ent_struct, m_nTickBase, "int")
		,this.m_vecOrigin       := [NumGet(ent_struct, m_vecOrigin, "float"), NumGet(ent_struct, m_vecOrigin+0x4, "float"), NumGet(ent_struct, m_vecOrigin+0x8, "float")]
		,this.vecVelocity       := Sqrt(NumGet(ent_struct, m_vecVelocity, "Float")**2 + NumGet(ent_struct, m_vecVelocity+0x4, "Float")**2)
		,this.m_vecViewOffset   := [NumGet(ent_struct, m_vecViewOffset, "float"), NumGet(ent_struct, m_vecViewOffset+0x4, "float"), NumGet(ent_struct, m_vecViewOffset+0x8, "float")]
		,this.localHead         := [this.m_vecOrigin[1]+this.m_vecViewOffset[1], this.m_vecOrigin[2]+this.m_vecViewOffset[2], this.m_vecOrigin[3]+this.m_vecViewOffset[3]]
		,this.m_bDormant        := NumGet(ent_struct, m_bDormant, "int")
	}

	GetViewModel() {
		if !(this.m_hViewModel)
			return false

		return csgo.read(client + dwEntityList + ((this.m_hViewModel & 0xFFF) - 1) * 0x10, "int")
	}

	GetWeapon() {
		if (this.m_hActiveWeapon = -1)
			return false

		pWeapon := csgo.read(client + dwEntityList + ((this.m_hActiveWeapon & 0xFFF) - 1) * 0x10, "int")
		return pWeapon
	}

	GetClassId() {
		return csgo.read(this.entity + 0x8, "Uint", 0x8, 0x1, 0x14)
	}

	GetBone(BoneId) {
		Return [ csgo.read(this.m_dwBoneMatrix + 0x30*BoneId + 0x0C, "Float"), csgo.read(this.m_dwBoneMatrix + 0x30*BoneId + 0x1C, "Float"), csgo.read(this.m_dwBoneMatrix + 0x30*BoneId + 0x2C, "Float")]
	}
}

;===================================================================

;GlobalVars
Global realtime          := 0x0 ;float
Global framecount        := 0x4 ;int
Global absoluteFrameTime := 0x8 ;float
Global currenttime       := 0x10 ;float
Global frametime         := 0x14 ;float
Global maxClients        := 0x18 ;int
Global tickCount         := 0x1C ;int
Global intervalPerTick   := 0x20 ;float

Class GlobalVars {
	__New() {
		csgo.readRaw(engine + dwGlobalVars, globalvars_struct, intervalPerTick+0x4)
		this.realtime           := NumGet(globalvars_struct, realtime, "float")
		,this.framecount        := NumGet(globalvars_struct, framecount, "int")
		,this.absoluteFrameTime := NumGet(globalvars_struct, absoluteFrameTime, "float")
		,this.currenttime       := NumGet(globalvars_struct, currenttime, "float")
		,this.frametime         := NumGet(globalvars_struct, frametime, "float")
		,this.maxClients        := NumGet(globalvars_struct, maxClients, "int")
		,this.tickCount         := NumGet(globalvars_struct, tickCount, "int")
		,this.intervalPerTick   := NumGet(globalvars_struct, intervalPerTick, "float")
	}
}
;===================================================================

;classid
Global ClassId := {}
ClassId.AK47 := 1
ClassId.BaseAnimating := 2
ClassId.GrenadeProjectile := 9
ClassId.WeaponWorldModel := 23
ClassId.BreachCharge := 28
ClassId.BreachChargeProjectile := 29
ClassId.BumpMine := 32
ClassId.BumpMineProjectile := 33
ClassId.C4 := 34
ClassId.Chicken := 36
ClassId.Player := 40
ClassId.PlayerResource := 41
ClassId.Ragdoll := 42
ClassId.Deagle := 46
ClassId.DecoyGrenade := 47
ClassId.DecoyProjectile := 48
ClassId.Drone := 49
ClassId.Dronegun := 50
ClassId.PropDynamic := 52
ClassId.EconEntity := 53
ClassId.EconWearable := 54
ClassId.Flashbang := 77
ClassId.HEGrenade := 96
ClassId.Hostage := 97
ClassId.Inferno := 100
ClassId.Healthshot := 104
ClassId.Cash := 105
ClassId.Knife := 107
ClassId.KnifeGG := 108
ClassId.MolotovGrenade := 113
ClassId.MolotovProjectile := 114
ClassId.PropPhysicsMultiplayer := 123
ClassId.AmmoBox := 125
ClassId.LootCrate := 126
ClassId.RadarJammer := 127
ClassId.WeaponUpgrade := 128
ClassId.PlantedC4 := 129
ClassId.PropDoorRotating := 143
ClassId.SensorGrenade := 152
ClassId.SensorGrenadeProjectile := 153
ClassId.SmokeGrenade := 156
ClassId.SmokeGrenadeProjectile := 157
ClassId.Snowball := 159
ClassId.SnowballPile := 160
ClassId.SnowballProjectile := 161
ClassId.Tablet := 172
ClassId.Aug := 232
ClassId.Awp := 233
ClassId.Elite := 239
ClassId.FiveSeven := 241
ClassId.G3sg1 := 242
ClassId.Glock := 245
ClassId.P2000 := 246
ClassId.P250 := 258
ClassId.Scar20 := 261
ClassId.Sg553 := 265
ClassId.Ssg08 := 267
ClassId.Tec9 := 269
ClassId.World := 275


Process, Wait, csgo.exe
Global csgo := new _ClassMemory("ahk_exe csgo.exe", "", hProcessCopy)
Global client := csgo.getModuleBaseAddress("client.dll")
Global engine := csgo.getModuleBaseAddress("engine.dll")

DllCall("QueryPerformanceFrequency", "Int64*", freq)

Global rc
VarSetCapacity(rc, 16)
DllCall("GetClientRect", "Uint", hwnd, "Uint", &rc)

SetFormat, integer, H
;===================================================================
Loop {
	DllCall("QueryPerformanceCounter", "Int64*", LoopBefore)
	IsInGame := IsInGame()
	Global LocalPlayer := new CPlayer(GetLocalPlayer())
	if (IsInGame && LocalPlayer.entity) {
		
		MaxPlayer := GetMaxPlayer()
		,Weapon := new CWeapon(LocalPlayer.GetWeapon())

		csgo.readRaw(client + dwEntityList, EntityList, (MaxPlayer+1)*0x10)
		Loop % MaxPlayer {
			Global Entity := new CPlayer(NumGet(EntityList, A_index*0x10, "int"))

			if (Entity.entity=0 || Entity.entity=LocalPlayer.entity || Entity.m_lifeState || Entity.m_bDormant || Entity.GetClassId() != ClassId.Player)
				Continue

			if (LocalPlayer.m_iTeamNum != Entity.m_iTeamNum)  {			
				if (Entity.m_bSpotted!=2) {
					csgo.write(Entity.entity + m_bSpotted, 2, "Char")
				}				
			}
		}
	}
	DllCall("QueryPerformanceCounter", "Int64*", LoopAfter)
	LoopTimer := (LoopAfter - LoopBefore) / freq * 1000
}

GetMaxPlayer() {
	Return csgo.read(engine + dwClientState, "Uint", dwClientState_MaxPlayer)
}

GetLocalPlayer() {
	Return csgo.read(client + dwLocalPlayer, "Uint")
}

IsInGame() {
	Return csgo.read(engine + dwClientState, "Uint", dwClientState_State)=6
}

;===================================================================
*~$F6::
KeyWait, F6, T2.8
If ErrorLevel
{
  ExitApp
}
Else
{
  Reload
}
Return