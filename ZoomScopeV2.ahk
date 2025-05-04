;Ctrl+Shift+Alt - Toggle Red Dot / Zoom Scope (Cycle On/Off)
;Ctrl+Shift+MouseWheel - Zoom (In/Out)
;Esc - Hold 1 sec (Reload), 3 sec (Exit) 


#SingleInstance, Force
#Persistent

SetBatchLines -1
ListLines, Off

Process, Priority, , High

;Admin rights overrider
full_command_line := DllCall("GetCommandLine", "str")
If Not (A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)"))
{
  Try
  {
    If A_IsCompiled
      Run *RunAs "%A_ScriptFullPath%" /restart
    Else
      Run *RunAs "%A_AhkPath%" /restart "%A_ScriptFullPath%"
  }
  ExitApp
}

Zoom = 2
Rx = 256
Ry = 256
Zx := Rx/Zoom
Zy := Ry/Zoom
Delay := 15

StepZoomWinX = 0.65
StepZoomWinY = 1.15

StepZero := 0.6
ZeroX := (A_ScreenWidth / 2) - StepZero
ZeroY := (A_ScreenHeight / 2) - StepZero

ScopeZeroX := (A_ScreenWidth / 2) - (Rx / 4)
ScopeZeroY := (A_ScreenHeight / 2) - (Ry / 4)
ZoomWinX := (A_ScreenWidth / 2) * StepZoomWinX
ZoomWinY := (A_ScreenHeight / 2) * StepZoomWinY

xhair := 11-11 14-11 14-14 11-14 11-11

RedDotSC:
If StateX := !StateX
{
  Gui crosshair: +Disabled +AlwaysOnTop -Caption
  Gui crosshair: Margin, 0, 0
  Gui crosshair: Add, Progress, x-2 y-2 w5 h5 cFF0000, 100
  Gui crosshair: Show, AutoSize x%ZeroX% y%ZeroY% NoActivate, Crosshair
  Gui crosshair: +E0x80020
}
Else
  Gui crosshair: Hide
Return

ZoomSC:
If StateZSC := !StateZSC
{
  Gui ZSC: +Disabled +AlwaysOnTop -Caption
  Gui ZSC: Show, w%Rx% h%Ry% x%ZoomWinX% y%ZoomWinY% NoActivate, ZoomScope
  WinSet Region, 0-0  W%Rx% H%Ry% E , ZoomScope
  WinSet Transparent, 250, ZoomScope
  WinGet ZscID, id,  ZoomScope
  WinGet PrintSourceID, ID
  Gui ZSC: +E0x80020
  SetTimer, Refresh, %Delay%
}
Else
  Gui ZSC: Hide

Global hdd_frame := DllCall("GetDC", UInt, PrintSourceID)
Global hdc_frame := DllCall("GetDC", UInt, ZscID)
Global hdc_buffer := DllCall("gdi32.dll\CreateCompatibleDC", UInt,  hdc_frame)  ; buffer
Global hbm_buffer := DllCall("gdi32.dll\CreateCompatibleBitmap", UInt,hdc_frame, Int,A_ScreenWidth, Int,A_ScreenHeight)

Refresh:
  DllCall("gdi32.dll\StretchBlt", UInt,hdc_frame, Int,0, Int,0, Int,Rx, Int,Ry, UInt,hdd_frame, Int,ZeroX - (Rx / Zoom /2), Int,ZeroY - (Ry / Zoom /2), Int, Rx / Zoom, Int,Ry / Zoom ,UInt,0xCC0020)
Return

^+WheelUp::
^+WheelDown::
  If (Zoom < 31 and ( A_ThisHotKey = "^+WheelUp"))
      Zoom *= 1.18921
  If (Zoom >  2 and ( A_ThisHotKey = "^+WheelDown"))
      Zoom /= 1.18921
  Zx := Rx/Zoom
  Zy := Ry/Zoom
Return

*~$^+Alt::
If StageScope := !StageScope
  Gosub, ZoomSC
Else
  Gosub, RedDotSC
Return

*~$Escape::
;esc 1 sec = reload, esc 3 sec = exit
KeyWait, Escape, T0.8
If ErrorLevel
{
  KeyWait, Escape, T2.8
  If ErrorLevel
  {
    SoundBeep, 600, 80
    SoundBeep, 400, 80
    SoundBeep, 350, 80
    DllCall("gdi32.dll\DeleteObject", UInt,hbm_buffer)
    DllCall("gdi32.dll\DeleteDC", UInt,hdc_frame )
    DllCall("gdi32.dll\DeleteDC", UInt,hdd_frame )
    DllCall("gdi32.dll\DeleteDC", UInt,hdc_buffer)
    ExitApp
  }
  SoundBeep, 600, 80
  Reload
}
Return