#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir% ; Ensures a consistent starting directory.
;#NoTrayIcon
#InstallKeybdHook

; Set screen title, to set the HWND
Gui, Show, x0 y0 h0 w0, FnMapper
HWND := WinExist("FnMapper")

; Variable for the modifier key, define it here, just to be sure
fnPressed := 0
hidMessage := 0

; Set the homepath to the relevant dll file
HomePath=AutohotkeyRemoteControl.dll


; Load the dll
hModule := DllCall("LoadLibrary", "str", HomePath)


SizeofRawInputDeviceList := 16
SizeofRidDeviceInfo := 32
SizeofRawInputDevice := 16
SizeOfRawInputHeader := 24

RIDI_DEVICEINFO := 0x2000000b
RIDI_DEVICENAME := 0x20000007
RIDEV_INPUTSINK := 0x00000100

RID_INPUT     := 0x10000003

rimHIDregistered := 0

Res := DllCall("GetRawInputDeviceList", Ptr, 0, "UInt *", Count, UInt, SizeofRawInputDeviceList)
VarSetCapacity(RawInputList, SizeofRawInputDeviceList * Count)
Res := DllCall("GetRawInputDeviceList", Ptr, &RawInputList, "UInt *", Count, UInt, SizeofRawInputDeviceList)
; MsgBox, Number of devixcs = %Count% -- %Res%

Loop %Count% { ;for all HID devices
   Handle := NumGet(RawInputList, (A_Index - 1) * SizeofRawInputDeviceList)
   Type := NumGet(RawInputList, (A_Index - 1) * SizeofRawInputDeviceList + 8, "UInt")
   ; MsgBox, Handle = %Handle%  Type = %Type%

   if (Type == 2) {
	   	VarSetCapacity(Info, SizeofRidDeviceInfo)   
		NumPut(SizeofRidDeviceInfo, Info, 0)
	   	Length := SizeofRidDeviceInfo
	   	Res := DllCall("GetRawInputDeviceInfo", UInt, Handle, UInt, RIDI_DEVICEINFO, UInt, &Info, "UInt *", SizeofRidDeviceInfo)
	   	if (Res < 0) {
	   		MsgBox, %Res% GetRawInputDeviceInfo failed
	   	}


	 	Vendor := NumGet(Info, 4 * 2, "UShort")
      	Product := NumGet(Info, 4 * 3, "UShort")
      	Version := NumGet(Info, 4 * 4, "UShort")
 		UsagePage := NumGet(Info, (4 * 5), "UShort")
 		Usage := NumGet(Info, (4 * 5) + 2, "UShort")

 		; MsgBox, Vendor: %Vendor% Product: %Product% Version: %Version% UseagePage: %UsagePage% Usage: %Usage%
        if (Vendor = 1452 && rimHIDregistered == 0) {  ; Apple Wireless Keyboard
        	rimHIDregistered := 1
           	VarSetCapacity(RawDevice, SizeofRawInputDevice)
   			NumPut(RIDEV_INPUTSINK, RawDevice, 4, "UInt")
   			NumPut(HWND, RawDevice, 8)
        	NumPut(UsagePage, RawDevice, 0, "UShort")
 		    NumPut(Usage, RawDevice, 2, "UShort") 
			;; Register AWK modifier buttons HID
      		Res := DllCall("RegisterRawInputDevices", "UInt", &RawDevice, UInt, 1, UInt, SizeofRawInputDevice) 
      		if (Res == 0) {
				MsgBox, Failed to register for AWK device! -- %Res%
         		ExitApp
      		}
    	}
 	
	}

}


; On specific message from the dll, goto this function
OnMessage(0x00FF, "InputMsg")

; Register at the dll in order to receive events
EditUsage := 1
EditUsagePage := 12
HWND := WinExist("FnMapper")
nRC := DllCall("AutohotkeyRemoteControl\RegisterDevice", INT, EditUsage, INT, EditUsagePage, INT, HWND, "Cdecl UInt")
WinHide, FnMapper

; This function is called, when a WM_INPUT-msg from a device is received
InputMsg(wParam, lParam, msg, hwnd) 
{
 	global hidMessage
	global SizeOfRawInputHeader
	global RID_INPUT

	; get HID input
   	Res := DllCall("GetRawInputData", UInt, lParam, UInt, RID_INPUT, Ptr, 0, "UInt *", Size, UInt, SizeOfRawInputHeader)
   	VarSetCapacity(Buffer, Size)
   	Res := DllCall("GetRawInputData", UInt, lParam, UInt, RID_INPUT, UInt, &Buffer, "UInt *", Size, UInt, SizeOfRawInputHeader)

   	Type := NumGet(Buffer, 0 * 4, "UInt")
   	if (Type == 2) {
   		SizeHid := NumGet(Buffer, (SizeOfRawInputHeader + 0), "UInt")
 		InputCount := NumGet(Buffer, (SizeOfRawInputHeader + 4), "UInt")
 		Loop %InputCount% {
			Addr := &Buffer + SizeOfRawInputHeader + 8 + ((A_Index - 1) * SizeHid)
         	hidMessage := Mem2Hex(Addr, SizeHid)
         	ProcessHIDData(wParam, lParam)
      	}
   	}

	return

}

Mem2Hex( pointer, len ) {
  	multiply := 0x100
   	Hex := 0
   	Loop, %len%  {
		Hex := Hex * multiply
		Hex := Hex + *pointer+0
		pointer ++
   	}
	Return Hex 
} ; END: Mem2Hex


ProcessHIDData(wParam, lParam) {   ; set global vars for further handling
 	global hidMessage
 	global fnPressed

 	Transform, FnValue, BitAnd, 0xFF10, hidMessage

	if (FnValue = 0x1110) {
		fnPressed := 1
	} else if (fnValue == 0x1100) {
		fnPressed := 0
	}


;	ModKeysProcessing()
}

ModKeysProcessing() {

}



#UseHook On

*Backspace:: DoFnMod("{Backspace}", "{Delete}")
*Right:: DoFnMod("{Right}", "{End}")
*Left:: DoFnMod("{Left}", "{Home}")
*Up:: DoFnMod("{Up}", "{PgUp}")
*Down:: DoFnMod("{Down}", "{PgDn}")

DoFnMod(noFn, fn) {
	global fnPressed
	if (fnPressed == 1) {
		Send {Blind}%fn%
	} else {
		Send {Blind}%noFn%	
	}
	return	
}

