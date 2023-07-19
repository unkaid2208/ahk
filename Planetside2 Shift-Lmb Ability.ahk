;Hold LShift+LeftMouseButton - Ability (F)
;Esc - Hold 1 sec (Reload), 3 sec (Exit) 
;Works with Heavy Assault (Shields), Medic (Nano-regen Device), Infiltratror (Hunter Cloak)


#SingleInstance, Force
#Persistent

SetBatchLines,-1
ListLines, Off


*~<+LButton::
Loop 
{
  Send, {F Down}
  If !(GetKeyState("LButton", "P") && GetKeyState("LShift", "P"))
    Break
}
Send, {F Up}{F}
Return


*~$Escape::
KeyWait, Escape, T0.8
If ErrorLevel
{
  KeyWait, Escape, T2.8
  If ErrorLevel
  {
    SoundBeep, 600, 80
    SoundBeep, 400, 80
    SoundBeep, 350, 80
    ExitApp
  }
  SoundBeep, 600, 80
  Reload
}
Return