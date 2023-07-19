;F10 - Start/Stop
;F10 - Hold 1 sec (Reload), 3 sec (Exit) 


#SingleInstance, Force
#Persistent
#MaxThreadsPerHotkey 2

Process, Priority, , High

Global t

*~$F10::
If t := !t
Loop
{
  Go(RndMove())
}


KeyWait, F10, T2.8
If ErrorLevel
{
  SoundBeep, 600, 80
  SoundBeep, 400, 80
  SoundBeep, 350, 80
  Send, {%key% Up}
  ExitApp
}
Return


Go(key)
{
  Random, StepLength, 123, 456
  Random, StepDelay, 12345, 23456
  Send, {%key% Down}
  Sleep, %StepLength%
  Send, {%key% Up}
  Sleep, %StepDelay%
  If !t
  {
    Exit
  }
}


RndMove()
{
  RandArray = w,a,s,d
  Sort, RandArray, Random D,
  RandChar := SubStr(RandArray, 1, InStr(RandArray, ",") - 1)
  Return % RandChar
}
