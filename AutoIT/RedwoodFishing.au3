#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <Misc.au3>
#Include <WinAPIShellEx.au3>
#Include <WinAPI.au3>
#Include <WinAPISys.au3>
#include <WinAPIConstants.au3>
#include <Array.au3>
#include <MsgBoxConstants.au3>

; zoom in all the way with your character

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
;SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
;'SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

HotKeySet("{pause}", "Quit") ; Hotkey for exiting the script at any time
HotKeySet("{SCROLLLOCK}", "Pause") ; Hotkey for exiting the script at any time
;!q:: ; Hotkey to execute the script - remove this if you want to run the script as soon as you execute the file

;0xE69489 Dalaran at noon
;0x8C6F8E Dalaran at dusk
;0x566457 Highmountain at night
;0xCCDAB7 Stormheim at night
;Global $OriginalColor[$Colors] = [ _ ; No Bobber Mod
;"0x270A04", _ ; Highmountain 2am
;"0x7F1D18", _ ; Spires of Arak 8am
;"0x481114", _ ; Spires of Arak 4am
;"0xFAE5B0", _ ; Spires of Arak 5:00pm
;"0x2F0602", _ ; Spires of Arak 12:00pm
;"0x73637D", _ ; Garrison 10:30pm
;"0xCDA0C7", _ ; Dalaran 3:30am
;"0x4D574F", _
;"0xFBEF9B", _
;"0xCCDAB7", _
;"0xB89C77", _
;"0x566457", _
;"0x8C6F8E", _
;"0xE69489", _
;"0xFFECA6"] ; Highmountain at noon
Global $Colors = 8
Global $OriginalColor[$Colors] = [ _ ; Rubber Ducky Bobber
"0x839F1D", _ ; Surumar 3am
"0x795B11", _ ; Surumar 4am
"0x979C0E", _ ; Asuna 2am
"0xF9F314", _ ; Asuna 1pm
"0x627911", _ ; Highmountain 1am
"0xFFFD1D", _ ; Highmountain 10am
"0xFFD813", _ ; Highmountain 7pm
"0xFFFF13"] ; Highmountain 10am
Global $SplashColors = 4
Global $SplashOC[$SplashColors] = [ _
"0xA0A9A6", _ ; Highmountain 10am
"0x796C64", _ ; Spires of Arak 5:00pm
"0xFFFFE8", _ ; "0x5F588E", _
"0xA2BFFF" ] ; Garrison 10:30pm
Global $SampledColor = $OriginalColor
Global $SearchLeft = 736 ; top left X coordinate of the search area (you have to set this and the others to an area suitable for your wow window - the area where the blobber will land)
Global $SearchTop = 277 ; top left Y coordinate of the search area
Global $SearchRight = 1095 ; bottom right X coordinate of the search area
Global $SearchBottom = 400 ; bottom right Y coordinate of the search area
Global $variation = 15 ; the color value variations to allow the color of "thecolor" to be
Global $variationStart = 20 ; the color value variations to allow the color of "thecolorStart" to be

Global $AuraColors = 4
Global $Auras[$AuraColors] = [ _
"0xFFF016", _ ; Rubber Ducky Bobber, 0xE8B60B , 0xF9E713
"0xF45307", _ ; Fishing Pole Buff, 0x896F4C , 0xF24F03
"0x5B6F84", _ ; Rare Fish Bait, 0x9BA278 , 0x494D37, 0x9BA171
"0xB08FE3" ] ; Arcane Lure
;"0x935061" ] ; Fishing , 0xB85D6F , 0xD49DB4

Global $RareAuras[4] = [ _
"0x8D936D", _ ;
"0x16170D", _ ;
"0x5B6F84", _ ; Rare Fish Bait, 0x9BA278 , 0x494D37, 0x9BA171
"0x9BA171" ] ;

Global $ArcaneAuras[4] = [ _
"0xEEEDF6", _ ;
"0xE0DBE7", _ ;
"0xD6C9E9", _ ; Rare Fish Bait, 0x9BA278 , 0x494D37, 0x9BA171
"0xA28CB9" ] ;

Global $WindowTitle = "World of Warcraft"
;Global $WindowHandle = WinGetHandle( $WindowTitle )
Global $BaitDuration = 1 ; Time in Minutes
Global $BaitType = 1
Global $Baittimer, $BobTimer, $dll, $Timer, $FoundColor, $CastCount, $CastFails, $CastFound, $FailsInRow, $LastFailCount, $splash
Global $bobber[2] = [ 100, 100 ]

Opt("SendKeyDelay", 60)
Opt("MouseCoordMode", 2)
WinActivate($WindowTitle) ; activate World of Warcraft Window
Sleep(1500) ; wait a bit
MouseMove($SearchLeft, $SearchTop)
MouseMove($SearchRight, $SearchBottom)
Prep()
ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Prep Complete  ' & @CRLF )
While -1 ; set this to whatever you want - this determines how often you fish before you have to hit the start hotkey again
	ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Checking Bait  ')
	CheckBait()
	ConsoleWrite(@CRLF)
	ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Checking Bobber  ')
	CheckBobber()
	ConsoleWrite(@CRLF)
	ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Fishing  '  )
	Fish() ; go fishing
	ConsoleWrite(@CRLF)
	ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Checking Combat  ' )
	CheckCombat(0)
	ConsoleWrite(@CRLF)
	ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Checking Fails ' & @CRLF )
	CheckFails()
	Sleep(Random(75,175))
WEnd
Quit("EOF")
Func Fish() ; the main fishing routine
	Local $Found = 0
	;Send( "^z") ; Clear any targets or open windows
	Cast(1)
	$CastCount += 1
	sleep(2000)
	$Timer = TimerInit()
	While -1
		For $i = 0 to $Colors - 1
			$bobber = BobberSearch($OriginalColor[$i])
			If @error <> 1 Then
				ConsoleWrite(': c' & $i & ' <' & $OriginalColor[$i] & '>')
				;MsgBox(0,"color found", "Color: " & $OriginalColor[$i])
				ExitLoop 2; When color is found, bail out of the loop to start looking for splash
			EndIf
		Next
		$bobber = BobberSearch($SampledColor)
		If @error <> 1 Then
			ConsoleWrite(': SampleColor <' & Hex($SampledColor) & '>')
			ExitLoop ; When color is found, bail out of the loop to start looking for splash
		EndIf
		If TimerDiff($Timer) > 9000 Then
			$Found = 1
			$CastFails += 1
			ConsoleWrite(': Cast Failed <' & $CastFails & '>')
			ExitLoop
		EndIf
		Sleep(50)
	WEnd

	if $Found <> 1 Then
		UpdateColor()
		WinActivate($WindowTitle)
		MouseMove($bobber[0]+5, $bobber[1]+5)
		$CastFound += 1
		While -1
			$splash = PixelSearch($bobber[0]-10,$bobber[1]-10,$bobber[0]+10,$bobber[1]+10,$FoundColor,10,1) ; Search a tiny 20x20 square for the bobber color
			If @error = 1 Then ; When the color isn't found, the bobber just bobbed (Splash Detected!)
				WinActivate($WindowTitle)
				MouseMove($bobber[0]+5, $bobber[1]+25)
				WinActivate($WindowTitle)
				MouseMove($bobber[0]+5, $bobber[1]+5)
				For $x = 0 To $SplashColors - 1
					$splash = BobberSearch($SplashOC[$x])
					;If @error <> 1 Then
					;	Sleep(Random(75,175))
					;	MouseMove($bobber[0], $bobber[1])
					;	ControlClick($WindowTitle, "", 0, "right", 1, $bobber[0], $bobber[1])
					;	ExitLoop 2 ; Splash confirmed, loot the bobber
					;EndIf
				Next
						ControlClick($WindowTitle, "", 0, "right", 1, $bobber[0], $bobber[1])
						ExitLoop
			EndIf
			If TimerDiff($Timer) > 20000 Then Exitloop
			Sleep(20)
		WEnd
		;WinActivate($WindowTitle)
		;MouseMove($bobber[0]+5, $bobber[1]+5)
		Sleep(2000)
	EndIf
EndFunc

Func Cast($fly)
	For $i = 1 To $fly
		ControlClick($WindowTitle, "", 0, "right", 1, 850, 350) ;center screen
		Sleep(250)
		ControlClick($WindowTitle, "", 0, "right", 1, 850, 350) ;center screen
		Sleep(800)
	Next
EndFunc


Func CheckBobber()
	$TimeBob = TimerDiff($BobTimer)
	ConsoleWrite(': Bait timer <' & $TimeBob & '>')
	If $TimeBob >= 30 * 60 * 1000 Or $BobTimer = "" Then
		ConsoleWrite(': Timer Reached')
		ControlSend( $WindowTitle, "", 0, "{CTRLDOWN}", 0 )
		ControlSend( $WindowTitle, "", 0, "9", 0 )
		ControlSend( $WindowTitle, "", 0, "{CTRLUP}", 0 )
		Sleep(2500)
		ConsoleWrite(': Bobber Applied')
		$BobTimer = TimerInit()
	EndIf
EndFunc

Func CheckBait()
	$TimeMil = TimerDiff($Baittimer)
	ConsoleWrite(': Bait timer <' & $TimeMil & '>')
	If $TimeMil>= $BaitDuration * 60 * 1000 Or $Baittimer = "" Then
		ConsoleWrite(' : Timer Reached')
		For $x = 0 To $AuraColors - 1
			$AuraFound = PixelSearch(32,36,450,65,$Auras[$x],1,1)
			If @error <> 0 Then
				ApplyBait($x)
			Else
				ConsoleWrite(' : Found <' & $x & '>')
			EndIf
		Next
		$RareFound = 0
		For $i = 0 To 3
			$RareAuraFound = PixelSearch(32,36,450,65,$RareAuras[$i],1,1)
			If @error <> 0 Then
				$RareFound = 1
				ConsoleWrite(' : Rare Aura Not Found <' & $RareAuras[$i] & '>' & @CRLF )
			Else
				ConsoleWrite(' : Rare Aura Found <' & $RareAuras[$i] & '>' & @CRLF )
			EndIf
		Next
		If $RareFound Then
			ApplyBait(2)
			ConsoleWrite(' : Rare Bait Applied')
		Else
			ConsoleWrite(' : Rare Aura Found')
		EndIf

		$ArcaneFound = 0
		For $i = 0 To 3
			$RareAuraFound = PixelSearch(32,36,450,65,$ArcaneAuras[$i],1,1)
			If @error <> 0 Then
				$ArcaneFound = 1
				ConsoleWrite(' : Arcane Aura Not Found <' & $ArcaneAuras[$i] & '>' & @CRLF )
			Else
				ConsoleWrite(' : Arcane Aura Found <' & $ArcaneAuras[$i] & '>' & @CRLF )
			EndIf
		Next
		If $ArcaneFound Then
			ApplyBait(3)
			ConsoleWrite(' : Arcane Lure Applied')
		Else
			ConsoleWrite(' : Arcane Aura Found')
		EndIf

		$Baittimer = TimerInit()
	EndIf
EndFunc

Func ApplyBait($bait)
	ConsoleWrite(': Applying Bate <' & $bait & '>')
	ControlSend( $WindowTitle, "", 0, "{CTRLDOWN}", 0 )
	if $bait = 0 Then ControlSend( $WindowTitle, "", 0, "9", 0 ) ; Bobber
;~ 	if $bait = 1 Then
;~ 		ConsoleWrite(': PoleBuff Color <' & PixelGetColor( 36, 629 ) & '>')
;~ 		if PixelGetColor( 36, 629 ) = "0xA63810" Then
;~ 			ControlSend( $WindowTitle, "", 0, "0", 0 ) ; Pole
;~ 			ConsoleWrite(': Clicking Pole')
;~ 		Else
;~ 			ControlSend( $WindowTitle, "", 0, "8", 0 ) ; Hat
;~ 			ConsoleWrite(': Clicking Hat')
;~ 		EndIf
;~ 	EndIf
	if $bait = 2 Then
			ControlSend( $WindowTitle, "", 0, "6", 0 ) ; Rare Bait
			ConsoleWrite(': Ctrl 6')
	EndIf
	if $bait = 3 Then
		if PixelGetColor( 32, 569 ) = "0xD7C2FC" Then
			ControlSend( $WindowTitle, "", 0, "7", 0 ) ; Arcane
			ConsoleWrite(': Arcane Lure')
		EndIf
	EndIf
	ControlSend( $WindowTitle, "", 0, "{CTRLUP}", 0 )
EndFunc

Func AuraFound($x)
	$AuraCheck = PixelSearch(32,36,245,65,$Auras[$x],10,1)
	If @error <> 1 Then Return False
EndFunc

Func Prep()
	ControlFocus( $WindowTitle, "", 0 )
	;Send(  "^-" ) ; Equip fishing pole
	ControlSend( $WindowTitle, "", 0, "{CTRLDOWN}", 0 )
	ControlSend( $WindowTitle, "", 0, "-", 0 )
	ControlSend( $WindowTitle, "", 0, "9", 0 )
	ControlSend( $WindowTitle, "", 0, "{CTRLUP}", 0 )
	ControlSend( $WindowTitle, "", 0, "{HOME}", 0 ) ; Set camera view (Make sure home is bound to a zoomed in view)
	ControlSend( $WindowTitle, "", 0, "{F1}", 0 ) ; Set target to self
	ControlSend( $WindowTitle, "", 0, "{F11}", 0 ) ; Open/Close window
	ControlSend( $WindowTitle, "", 0, "{F12}", 0 ) ; Open/Close window
	Sleep(250)
	ControlSend( $WindowTitle, "", 0, "{ESC}", 0 ) ; Clear any targets or open windows
	Sleep(250)
	ControlSend( $WindowTitle, "", 0, "{ESC}", 0 ) ; Clear any targets or open windows
	$dll = DllOpen("user32.dll") ; Read somewhere thats User32.ddl speeds up _IsPressed detection?
	Cast(3)
	CheckCombat(1)
EndFunc

Func BobberSearch($color)
	Local $Coordinates
	$FoundColor = $color
	$Coordinates = PixelSearch($SearchLeft,$SearchTop,$SearchRight,$SearchBottom,$color,10,1)
	If @error = 1 Then SetError(1)
	return $Coordinates
EndFunc

Func SplashSearch($color)
	Local $Coordinates
	$FoundColor = $color
	$Coordinates = PixelSearch($bobber[0]-30,$bobber[1]-100,$bobber[0]+30,$bobber[1]+15,$color,10,1)
	If @error = 1 Then SetError(1)
	return $Coordinates
EndFunc

Func UpdateColor()
	Local $NewSample, $Results
	WinActivate($WindowTitle)
	Sleep(100)
	$NewSample = PixelGetColor($bobber[0], $bobber[1])
	$Results = _ArraySearch($OriginalColor, $NewSample)
	if $Results = -1 Then
		_ArrayAdd($OriginalColor, $NewSample)
	EndIf
	$SampledColor = $NewSample
EndFunc

Func CheckCombat($first)
	Local $TargetColor = PixelGetColor(1033,736 )
	ConsoleWrite(': Combat Color <' & $TargetColor & '>')
	If $TargetColor = "0x313131" Then
			If $First Then
				ControlSend( $WindowTitle, "", 0, "{ESC}", 0 ) ; Clear target again
				Return
			EndIf
			ConsoleWrite(': Equiping Weapon')
			ControlSend( $WindowTitle, "", 0, "{CTRLDOWN}", 0 )
			ControlSend( $WindowTitle, "", 0, "=", 0 )
			ControlSend( $WindowTitle, "", 0, "{CTRLUP}", 0 )
			ConsoleWrite(': Turning')
			for $a = 0 to 15
			ConsoleWrite(': Equiping Weapon')
				ControlSend( $WindowTitle, "", 0, "{RIGHT}", 0 )
				Sleep(200)
			Next
			ConsoleWrite(': Shear')
			ControlSend( $WindowTitle, "", 0, "6", 0 ) ; shear
			Sleep(1000)
			ConsoleWrite(': immolation')
			ControlSend( $WindowTitle, "", 0, "8", 0 ) ; immolation
			Sleep(1000)
			ConsoleWrite(': fiery brand')
			ControlSend( $WindowTitle, "", 0, "{SHIFT}7", 0 ) ; fiery brand
			Sleep(1000)
			ConsoleWrite(': soul carver')
			ControlSend( $WindowTitle, "", 0, "{SHIFT}8", 0 )  ; soul carver
			Sleep(1000)
			ConsoleWrite(': Shear')
			ControlSend( $WindowTitle, "", 0, "6", 0 )  ; shear
			Sleep(1000)
			ConsoleWrite(': soul cleave')
			ControlSend( $WindowTitle, "", 0, "7", 0 ) ; soul cleave
			Sleep(1000)
			ConsoleWrite(': Shear')
			ControlSend( $WindowTitle, "", 0, "6", 0 ) ; shear
			Sleep(1000)
			ConsoleWrite(': Soul Cleave')
			ControlSend( $WindowTitle, "", 0, "7", 0 )  ; soul cleave
			Sleep(10000)
			ConsoleWrite(': equip pole')
			ControlSend( $WindowTitle, "", 0, "{CTRLDOWN}", 0 )
			ControlSend( $WindowTitle, "", 0, "-", 0 )
			ControlSend( $WindowTitle, "", 0, "{CTRLUP}", 0 )
			Sleep(100)
			ConsoleWrite(': loot body')
			ControlClick($WindowTitle, "", 0, "right", 1, 960, 875) ;loot
			Sleep(1000)
			ConsoleWrite(': turning back')
			for $a = 0 to 15
				ControlSend( $WindowTitle, "", 0, "{LEFT}", 0 )
				Sleep(100)
			Next
			ControlSend( $WindowTitle, "", 0, "{ESC}", 0 )
	EndIf
	; Quit("Combat")
EndFunc

Func CheckFails()
	If $LastFailCount = $CastFails Then $FailsInRow = 0
	If $LastFailCount < $CastCount Then $FailsInRow += 1
	If $FailsInRow = 10 Then Quit("Fail Count")
	$LastFailCount = $CastFails
EndFunc
Func Quit($why = "Hotkey")
	MsgBox(0,"exit","program quit: " & $why)
	Exit
EndFunc
Func Pause()
	Sleep(10000)
EndFunc