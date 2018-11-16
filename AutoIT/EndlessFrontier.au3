#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <Misc.au3>
#Include <WinAPIShellEx.au3>
#Include <WinAPI.au3>
#Include <WinAPISys.au3>
#include <WinAPIConstants.au3>
#include <Array.au3>
#include <MsgBoxConstants.au3>
#include <EndlessFrontierFingerprints.au3>
#include <Date.au3>

ConsoleWrite('@@ Includes Loaded, setting globals'  & @CRLF)

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
AutoItSetOption("SendKeyDelay", 60)
AutoItSetOption("MouseCoordMode", 0)
AutoItSetOption("PixelCoordMode", 0)

HotKeySet("{pause}", "HotKeyPressed") ; Hotkey for em xiting the script at any time
HotKeySet("{END}", "HotKeyPressed") ; Hotkey for exiting the script at any time
HotKeySet("{Esc}", "HotKeyPressed") ; Hotkey for exiting the script at any time
HotKeySet("{NumPadMult}", "HotKeyPressed") ; Hotkey for exiting the script at any time
HotKeySet("{F6}", "HotKeyPressed") ; Hotkey for exiting the script at any time
HotKeySet("{F7}", "HotKeyPressed") ; Hotkey for exiting the script at any time
;!q:: ; Hotkey to execute the script - remove this if you want to run the script as soon as you execute the file


Func Initialize()
   SetError(0)

   ;Window Settings
   Global $Emulator = "X001"
   Global $Window = WinActivate($Emulator)
   Global $Handle = WinGetHandle($Emulator)
   Global $WindowSize = WinGetClientSize($Emulator)
   Global $YR = $WindowSize[1] / 1020
   Global $XR = $WindowSize[0] / 559
   ControlMove( $Emulator,"","", 0, 0)
   Sleep(500)
   ControlClick ( $Emulator,"","[CLASS:Qt5QWindowIcon; INSTANCE:6]", "left", 1, 100, 10 )
   Global $t = 1 ; Play stage X times a second
   ;Timers
   Global $Timer = TimerInit() ; time since last initialize
   Global $tRevive = $Timer ; time since last revive
   Global $tBuyUnit = $Timer ; time until menu refresh
   Global $tDungeon = $Timer ; time until next ticket
   Global $tBattleArena = $Timer ; time until next ticket
   Global $tDoubleSpeed = $Timer ; time left on speed buff
   Global $tGoldAd = $Timer ; time left on speed buff
   Global $tRaid = $Timer	; time since raid
   Global $tAction = $Timer ; delay between actions
   Global $tTower = $Timer ; time until last ticket
   Global $tStage = $Timer ; time since last stage
   Global $tAbility1 = $Timer ; time since last use
   Global $tAbility2 = $Timer ; time since last use
   Global $tAbility3 = $Timer ; time since last use
   Global $tHertzTimer = $Timer ; time since last use
   Global $tReport = $Timer ; time since last use
   Global $tQuesting = $Timer ; time since last Quest
   Global $tQuestTime = $Timer ; time since clicking start quest
   Global $tUnitLevel = $Timer ; time since last Quest
   Global $tQuestState = $Timer ; time since last UpdateQuest
   Global $tSpiritRest = $Timer ; time since last SpiritRest Available Check
   Global $tSpiritRestEnd = $Timer ; time since SpiritRest started
   Global $tSpiritRestPrint = $Timer ; time since SpiritRest started
   Global $tRetryAction = $Timer ; time since action last completed
   Global $tError = $Timer ; time since action last completed
   ;State
   Global $sAbility1 = False
   Global $sAbility2 = False
   Global $sAbility3 = False
   Global $restStarted = False
   Global $sSpeedBuff = False
   Global $sGemBuff = False
   Global $sBonusGold = False
   Global $sAutoQuest = 0
   Global $sQuest = 0
   Global $sQuestY = 720			;Location of Current Quest Gold Coin
   Global $sQuestBorder = 0 ; Location of Current Quest frame border
   Global $sSpiritRestPrint[1][3] = [["0","0","00000000"]]

   Global $sStagePlayable = True
   Global $sQuesting = True
   Global $sHoldUnitLeveling = True
   Global $sQuestUpgrading = True
   Global $sQuestStatus = "Start"
   Global $sGameLagRating = 0
   Global $sErrorCount = 0
   Global $sErrors = 0
   Global $sAction = "UpdateState"
   Global $sActionValue = 0
   Global $sActionQueue = 0
   Global $sActionSubValue = 0
   Global $sPaused = False
   Global $sCurrentView = ""
   If(IsResting()) Then
	  ConsoleWrite('Spirt Rest Active ' & @CRLF)
	  $sStagePlayable = False
	  SpiritPrint()
   Else
	  ConsoleWrite('Not Resting ' & @CRLF)
   EndIf

   $sActionValue = 0

   Global $dll = DllOpen("user32.dll") ; Read somewhere thats User32.ddl speeds up _IsPressed detection?

   ConsoleWrite('(' & @ScriptLineNumber & ') : Time: '& _NowTime() & @CRLF )
   If($WindowSize[0] <> 559)Then
	   ConsoleWrite('@@ WARNING! WINDOW WIDTH IS NOT 559 ' & @CRLF)
	EndIf
	If($WindowSize[1] <> 1020)Then
	   ConsoleWrite('@@ WARNING! WINDOW HEIGHT IS NOT 1020 ' & @CRLF)
   EndIf
EndFunc

Initialize()
While -1 ; Endless Loop, must break via hotkey
   HealthCheck() ; Decide if game nees restarted
   PlayStage()  ; Click Chests, Use Abilities
   LaunchAction($sAction) ; Perform a specific Action
   UpdateAction() ; Decide the next Action
WEnd
ConsoleWrite(@CRLF)
Quit("EOF")


;Action Functions
Func SpiritRest($Action)
   If ($Action <> 0) Then
	  ConsoleWrite('<'  & $Action)
   EndIf

   Switch $Action
   Case 0
	  HealthCheck()
	  $sActionValue += 1
	  $tRetryAction = TimerInit()
   Case 1
	  If (RetryAction(10)) Then
		 If (NoOverlay()) Then
			$sActionValue += 1
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>   Overlay Detected, Escaping '  & @CRLF)
		 Escape()
	  EndIf
   Case 2
	  ;Check if Resting
	  If (IsResting())Then
		 $sActionValue = -1
		 $sStagePlayable = False
		 ;SpiritPrint()
	  Else
		 $sActionValue += 1
	  EndIf
   Case 3
	  ;Select Shop Tab
	  ClickRange(470,950,550,1015)
	  $tSpiritRestEnd = TimerInit() ; Reset Spirit Rest Timer as we're not resting
	  $sActionValue += 1
	  $tRetryAction = TimerInit()
   Case 4
	  ;Check the Shop Tabl loaded
	  If (RetryAction(5)) Then
		 If (IsBright(GetColor( 510,969)))Then
			;Select Premium Page
			ClickRange(135,415,220,430)
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Failed to Load Shop Tab '  & @CRLF)
	  EndIf
   Case 5
	  ;Check if Premium Page loaded
	  If (RetryAction(5)) Then
		 If (IsBright(GetColor( 166,416 )))Then
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Premium Page Not Loading '  & @CRLF)
	  EndIf
   Case 6
	  ;If already at bottom of page
	  If (RetryAction(5)) Then
		 If (IsYellow(GetColor( 56,725)))Then
			$sActionValue += 2
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sActionValue += 1
	  EndIf
   Case 7
	  ;Scroll Down
	  ;WinActivate($Window)
	  ScrollDown()
	  ScrollDown()
	  $sActionValue += 1
	  $tRetryAction = TimerInit()
   Case 8
	  If (RetryAction(5)) Then
	  ;Check for accidental secret skill click
		 If (TestPixel($secretSkillDetail))Then
			ClickRange(210,870,350,900)
			$sActionValue -= 1
		 EndIf
	  Else
		 $tRetryAction = TimerInit()
		 $sActionValue  += 1
	  EndIf
   Case 9
	  If (RetryAction(5)) Then
		 ;Click Rest Start
		 If (IsYellow(GetColor( 56,725)))Then
			ClickRange(425,690,540,730)
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Spirit Rest Icon not found '  & @CRLF)
	  EndIf
   Case 10
	  If (RetryAction(5)) Then
		 ;Check if Rest Start is available
		 $Color = GetColor( 189,549)
		 If (IsYellow($Color,80))Then
			ClickRange(200,560,360,600)
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sActionValue = -1
		 ConsoleWrite(' :  Spirit Rest Not Ready '  & @CRLF)
		 ClickRange(500,235,540,280)
	  EndIf
   Case 11
	  If (RetryAction(5)) Then
		 ;Click Rest Start
		 $Color = GetColor( 140,469)
		 If (IsBright($Color,80))Then
			ClickRange(145,475,250,510)
			$restStarted = True
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Failed to Confirm Rest '  & @CRLF)
	  EndIf
   Case 12
	  If (RetryAction(5)) Then
		 ; Clear Confirmation Window
		 $Color = GetColor( 206,448)
		 If (IsBright($Color,80))Then
			ClickRange(210,450,340,490)
			$sActionValue = -1
			ConsoleWrite(': Spirit Rest Complete '  & @CRLF)
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>   Clear Confirm Rest Failed '  & @CRLF)
	  EndIf
	  $tSpiritRestEnd = TimerInit() ; Start Spirit Rest End Timer
	  $sStagePlayable = False
   EndSwitch
EndFunc
Func LaunchAction($Action)
   Switch $Action
   Case "UpdateState"
	  UpdateState()
   Case "Quest"
	  QuestDetail()
	  Questing($sActionValue)
   Case "BuyUnit"
	  BuyUnit($sActionValue)
   Case "UnitLevels"
	  UnitLevels($sActionValue)
   Case "DoubleSpeed"
	  DoubleSpeed($sActionValue)
   Case "SpiritRest"
	  SpiritRest($sActionValue)
   Case "SpiritRestEnd"
	  SpiritRestEnd($sActionValue)
   Case "SpiritPrint"
	  SpiritPrint()
   Case Else
	  ;UPDATE STATE
	  ConsoleWrite('(' & @ScriptLineNumber & ') : No Launch Action '  & @CRLF)
   EndSwitch
EndFunc
Func UpdateAction()
   If($sActionValue = -1) Then
	  ReportState()
	  If( TimerDiff($tBuyUnit) > (5 * 60 * 1000) ) Then
		 $sAction = "BuyUnit"
		 $sActionValue = 0
		 $tBuyUnit = TimerInit()
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Starting Buy Unit Action'  & @CRLF)
	  ElseIf( TimerDiff($tDoubleSpeed) > ( 60 * 1000) ) Then
		 $sAction = "DoubleSpeed"
		 $sActionValue = 0
		 $tDoubleSpeed = TimerInit()
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Starting DoubleSpeed Action'  & @CRLF)
	  ElseIf( TimerDiff($tUnitLevel) > ( 5 * 60 * 1000) And $sAutoQuest > 25 ) Then
		 $sAction = "UnitLevels"
		 $sActionValue = 0
		 $tUnitLevel = TimerInit()
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Starting Unit Level Up Action'  & @CRLF)
	  ElseIf( TimerDiff($tSpiritRest) > (  12 * 60 * 1000) And $sAutoQuest = 28 ) Then
		 $sAction = "SpiritRest"
		 $sActionValue = 0
		 $tSpiritRest = TimerInit()
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Starting Spirit Rest Action'  & @CRLF)
	  ElseIf( TimerDiff($tSpiritRestPrint) > (  5 * 60 * 1000) And IsResting() ) Then
		 $sAction = "SpiritPrint"
		 $sActionValue = 0
		 $tSpiritRestPrint = TimerInit()
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Starting Spirit Print Action'  & @CRLF)
	  ElseIf( TimerDiff($tSpiritRestEnd) > ( 4 * 60 * 60 * 1000) ) Then
		 $sAction = "SpiritRestEnd"
		 $sActionValue = 0
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Starting End Spirit Rest Action'  & @CRLF)
	  Else
		 $sAction = "Quest"
		 $sActionValue = 0
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Starting Quest Action'  & @CRLF)
	  EndIf
	  $tRetryAction = TimerInit()
   EndIf
EndFunc
Func Questing($Action)
   If ($Action <> 0) Then
	  ConsoleWrite('<'  & $Action)
   EndIf

   If($sQuesting) Then
	  ;Check if Quest Tab is active without Overlay
	  If Not (IsBright( GetColor(50,970), 200)) Then
		 HealthCheck()
		 ClickRange(10,960,80,1010)
	  EndIf
	  ;Hold Questing to buy Auto Quest
	  If( TimerDiff($tQuestState) > (15 * 60 * 1000) And $sQuestStatus = "Start" ) Then
		 $sQuestUpgrading = False
		 $sQuestStatus = "Hold"
		 $sHoldUnitLeveling = True
		 $tQuestState = TimerInit()
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Disabling Quest Upgrades '  & @CRLF)
	  ;Resume Questing
	  ElseIf ($sQuestStatus = "Hold" And ($sAutoQuest = 28 )) Then
		 $sQuestUpgrading = True
		 $sHoldUnitLeveling = False
		 $sQuestStatus = "Pushing"
		 $tQuestState = TimerInit()
	  ;Hold Questing to buy next Quest
	  ElseIf ( TimerDiff($tQuestState) > (15 * 60 * 1000) And $sQuestStatus = "Pushing" ) Then
		 $sQuestUpgrading = False
		 $sHoldUnitLeveling = True
		 $sQuestStatus = "Last"
		 $tQuestState = TimerInit()
	  ;Resume Questing
	  ElseIf(IsYellow(GetColor(450,726)) Or IsYellow(GetColor(450,712))) Then
		 If ($sQuestStatus = "Last") Then
			ClickRange(430,690,540,730)
			$sHoldUnitLeveling = False
			$sQuestStatus = "Done"
			$sQuestUpgrading = True
			$tQuestState = TimerInit()
		 EndIf
	  ElseIf ( TimerDiff($tQuestState) > (30 * 60 * 1000) And $sQuestStatus = "Done" ) Then
			$sQuestStatus = "UnitLeveling"
			$sQuestUpgrading = False
			$tQuestState = TimerInit()
	  ElseIf ( TimerDiff($tQuestState) > (15 * 60 * 1000) And $sQuestStatus = "UnitLeveling" ) Then
			$sQuestStatus = "Done"
			$sQuestUpgrading = True
			$tQuestState = TimerInit()
	  EndIf
   Else
	  $sActionValue = -1
   EndIf

   Switch $Action
   ;Click Questing Tab
   Case 0
	  If (RetryAction(10)) Then
		 If (IsBright( GetColor(50,970), 200)) Then
			$tQuesting = TimerInit()
			$sActionValue += 1
		 Else
			ClickRange(10,960,80,1010)
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Quest Load Failed '  & @CRLF)
	  EndIf
   ;Buy Auto Quest
   Case 1
	  If (IsBright( GetColor(450,516), 200)) Then
		 ClickRange(430,480,540,520)
		 UpdateAutoQuest()
	  EndIf
	  $tRetryAction = TimerInit()
	  $sActionValue += 1
   ;Scroll down maybe
   Case 2
	  If (RetryAction(20)) Then
		 If ($sAutoQuest > 25) Then
			If (IsPurple(GetColor(80,550), 30) Or IsPurple(GetColor(80,550),30) Or IsPurple(GetColor(77,548),30)) Then
			   $sActionValue += 1
			   $tRetryAction = TimerInit()
			Else
			   ScrollDown()
			EndIf
		 Else
			   $sActionValue += 2
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Too Much Scrolling '  & @CRLF)
	  EndIf
   Case 3
	  If (RetryAction(30)) Then
		 StartQuest()
		 If($sQuestUpgrading) Then
			BuyQuest()
		 EndIf
	  Else
		 $sActionValue = -1
	  ConsoleWrite(': Questing Action Complete'  & @CRLF)
	  EndIf
   Case 4
	  UpdateCurrentQuest($sActionSubValue)
	  If($sActionSubValue = -1) Then
		 $sActionValue = 0
		 $sActionSubValue = 0
	  EndIf
	  ConsoleWrite(': Questing Action Complete'  & @CRLF)
   Case Else
	  $sErrorCount += 1
	  ConsoleWrite('(' & @ScriptLineNumber & ') : Questing Error '  & @CRLF)
   EndSwitch
EndFunc
Func BuyQuest($multiple = 0)
   If (IsBright(GetColor(37,716)) Or IsBright(GetColor(450,712))) Then
	  If(IsBright(GetColor(175,720)))Then
		 ClickRange(190,690,300,740, 2)
	  ElseIf(IsBright(GetColor(333,720)))Then
		 ClickRange(310,690,430,740, 2)
	  Else
		 ClickRange(430,690,540,740, 2)
	  EndIf
   ElseIf (IsBright(GetColor(50,602))) Then
	  If(IsBright(GetColor(182,627)))Then
		 ClickRange(190,590,300,640, 2)
	  ElseIf(IsBright(GetColor(316,625)))Then
		 ClickRange(310,590,430,640, 2)
	  Else
		 ClickRange(430,590,540,640, 2)
	  EndIf
   Else
	  If(IsBright(GetColor(450,618),150))Then
		 ClickRange(430,590,540,640, 2)
	  Else
		 ClickRange(430,545,540,550, 2)
		 ClickRange(190,545,300,550, 10)
	  EndIf
	  If($sAutoQuest = 0) Then
		 $sAutoQuest = 26
	  EndIf

   EndIf
EndFunc
Func UnitLevels($Action)
   If ($Action <> 0) Then
	  ConsoleWrite('<'  & $Action)
   EndIf
   If (IsResting() Or $sHoldUnitLeveling) Then
	  $sActionValue = -1
	  Return
   EndIf

   ;Close Unit Details if misclicked
   If(TestPixel($UnitDetailClose)) Then
	  ClickRange(500,195,550,240)
   EndIf

   Switch $Action
   Case 0
	  ClickRange(100,960,180,1010)
	  $sActionValue += 1
	  $tRetryAction = TimerInit()
   Case 1
	  If (RetryAction(10)) Then
		 ; Check Unit Page Loaded
		 If(IsBright(GetColor(133,964))) Then
			$sActionValue += 1
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>   Unit Page Load Failed '  & @CRLF)
	  EndIf
   Case 2
	  ;Check Senior Upgrades
	  If(IsBright(GetColor(460,582))) Then
		 ClickRange(300,480,360,520)
		 $sStagePlayable = False
		 $sActionValue += 1
		 $tRetryAction = TimerInit()
	  Else
		 $sActionValue = -1
	  EndIf
   Case 3
	  If (RetryAction(10)) Then
		 ; Check Upgrade All Window
		 If(IsRed(GetColor(495,195))) Then
			$sActionValue += 1
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>   Upgrade All Failed '  & @CRLF)
	  EndIf
   Case 4
	  ; Click on +1000
	  If(IsBright(GetColor(48,376),150)) Then
		 ClickRange(25,335,140,345)
	  Else
		 $sActionValue += 1
	  EndIf
   Case 5
	  ; Click on +100
	  If(IsBright(GetColor(177,377),150)) Then
		 ClickRange(160,335,270,345)
	  Else
		 $sActionValue += 1
	  EndIf
   Case 6
	  ; Click on +10
	  If(IsBright(GetColor(309,375),150)) Then
		 ClickRange(285,335,400,345)
	  Else
		 $sActionValue += 1
	  EndIf
   Case 7
	  ; Click on +1
	  If(IsBright(GetColor(439,375),150)) Then
		 ClickRange(415,335,530,345)
	  Else
		 $sActionValue += 1
	  EndIf
   Case 8
	  ;Close Upgrade All Window
	  ClickRange(490,175,530,210)
	  If Not(IsResting()) Then
		 $sStagePlayable = True
	  EndIf
	  $sActionValue += 1
	  $tRetryAction = TimerInit()
   Case 9
	  If (RetryAction(5)) Then
		 ; Check Upgrade All Window
		 If(IsBright(GetColor(492,503))) Then
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>   Close Upgrade All Failed '  & @CRLF)
	  EndIf
   Case 10
	  If (RetryAction(5)) Then
		 ; Check Upgrade All Window
		 If(IsYellow(GetColor(459,584))) Then
			ClickRange(450,560,540,600)
		 EndIf
	  Else
		 $sActionValue = -1
		 ConsoleWrite(': Unit Levels Complete '  & @CRLF)
	  EndIf
   EndSwitch
EndFunc
Func PlayStage()
   Local $ClickDelay = 1500 ;Length of time to wait after new stage detected
   If $sStagePlayable Then
	  Local $temp = GetColor(80, 140)
	  If("00333333" = $temp) Then
		 $sGameLagRating = 0
		 While (hex(PixelGetColor(80, 140, $Handle )) = "00333333")
			$sGameLagRating += 1
		 Wend
		 ;ConsoleWrite('(' & @ScriptLineNumber & ') : New Stage! Lag: ' & $sGameLagRating  & @CRLF)
		 If($sSpeedBuff) Then
			$ClickDelay = $ClickDelay / 2
		 EndIf
		 $tStage = TimerInit()
	  EndIf
	  If(TimerDiff($tStage) > 3000 )Then
		 UseAbility(1)
	  EndIf
	  If(TimerDiff($tStage) > $ClickDelay )Then
		 ClickRange(70,300,105,320)
		 Sleep(100)
		 ClickRange(170,300,205,320)
		 Sleep(100)
		 ClickRange(270,300,305,320)
	  EndIf
   EndIf
   ScriptHertz( $t , $tHertzTimer ) ; Slow the script down, so it doesn't peg CPU
   $tHertzTimer = TimerInit()
EndFunc
Func UpdateAutoQuest()
   Local $PixelColor = ""
   Local $qArray[3] = ['','','']
   For $i = 0 To UBound($qAuto) - 1 Step 1
	  $qArray[0] = $qAuto[$i][1]
	  $qArray[1] = $qAuto[$i][2]
	  $qArray[2] = $qAuto[$i][3]
	  $PixelColor = TestPixel( $qArray )
	  If($PixelColor) Then
		 $sAutoQuest = $qAuto[$i][0]
	  EndIf
   Next
EndFunc
Func UpdateCurrentQuest($Action)
   If ($Action <> 0) Then
	  ConsoleWrite('('  & $Action & ')')
   EndIf
   Local $Search = True
   Local $Y = 935
   Local $Color = ""
   Switch $Action
   Case 0
	  While($Search) ;  Look for Affordable Quest
		 $Color =  GetColor( 450, $Y)
		 If(IsBright($Color, 100))Then
			$Search = False
			$sActionSubValue += 2
		 EndIf
		 $Color =  GetColor( 50, $Y)
		 If(IsBright($Color, 100))Then
			$Search = False
			$sActionSubValue += 2
		 EndIf
		 If($Y < 540) Then
			$Search = False
			$sActionSubValue += 1
		 EndIf
		 $Y -= 5
	  WEnd
	  If ($Y > $sQuestY) Then
		 $sQuestY = $Y
	  EndIf
   Case 1
	  ScrollUp()
	  $sActionSubValue -= 1
   Case 2
	  $Y = 540
	  For $i = 0 To 7 Step 1
		 ClickRange(430, $Y, 540, $Y + 10)
		 ClickRange(20, $Y, 80, $Y + 10)
		 Sleep(20)
		 $Y += 40
	  Next
	  $sActionSubValue += 1
   Case 3
	  ScrollDown()
	  $sActionSubValue += 1
   Case 4
	  If (GetColor(80,550) = "00721D5A" Or GetColor(80,550) = "00711D5A") Then
		 $sActionSubValue += 1
	  Else
		 $sActionSubValue -= 2
	  EndIf
   Case 5
	  UpdateAutoQuest()
	  $sActionSubValue = -1
   EndSwitch
EndFunc
Func DoubleSpeed($Action)
   If ($Action <> 0) Then
	  ConsoleWrite('<'  & $Action)
   EndIf

   Switch $Action
   Case 0
	  HealthCheck()
	  $sActionValue += 1
	  $tRetryAction = TimerInit()
   Case 1
	  If (RetryAction(10)) Then
		 If (NoOverlay()) Then
			$sActionValue += 1
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>   Overlay Detected, Escaping '  & @CRLF)
		 Escape()
	  EndIf
   Case 2
	  ;Check if Buff Currently Active
	  If (IsRed(GetColor(80,48)))Then
		 $sActionValue = -1
		 ConsoleWrite(': Buff active '  & @CRLF)
	  Else
		 $sActionValue += 1
	  EndIf
   Case 3
	  ;Select Shop Tab
	  ClickRange(470,950,550,1015)
	  $sActionValue += 1
	  $tRetryAction = TimerInit()
   Case 4
	  ;Check the Shop Tabl loaded
	  If (RetryAction(5)) Then
		 If (IsBright(GetColor( 510,969)))Then
			;Select Item Page
			ClickRange(240,415,320,420)
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>   Shop Load Failed '  & @CRLF)
	  EndIf
   Case 5
	  If (RetryAction(5)) Then
		 ;Check if Item Page loaded
		 If(IsRed(GetColor(  37,499), 150)) Then
			;Click View Ad
			ClickRange(430,470,540,530)
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>   Shop Item Page Load Failed '  & @CRLF)
	  EndIf
   Case 6
	  ;Check if Item Page loaded
		 ;Click View Ad
		 ClickRange(430,750,540,800)
		 $sActionValue = -1
		 ConsoleWrite( ' :DoubleSpeed Complete '  & @CRLF)
   EndSwitch
EndFunc
Func UpdateState()
   If ($sActionValue <> 0) Then
	  ConsoleWrite('<'  & $sActionValue)
   EndIf

   Switch $sActionValue
   Case 0
	  ReportState(1)
	  $sActionValue += 1
	  If Not(NoOverlay()) Then
		 Escape()
	  EndIf
   Case 1
	  ClickRange(5,955,85,1015)
	  $sActionValue += 1
   Case 2
	  UpdateAutoQuest()
	  $sActionValue += 2
   Case 3
	  UpdateCurrentQuest($sActionSubValue)
	  If($sActionSubValue = -1) Then
		 $sActionValue += 1
		 $sActionSubValue = 0
	  EndIf
   Case 4
	  ;Update Current Quest Level
	  $sQuestLevel = 56400
	  $sActionValue = -1
	  ConsoleWrite(' Update State Complete '  & @CRLF)
   Case 5
	  ;Update Current Quest Reward
	  $sQuestReward = 96200000
	  $sActionValue += 1
   Case 6
	  ;Update Current Quest Active
	  $sQuestActive = False
	  $sActionValue += 1
   Case 7
	  ;Update Current Quest Upgrade Cost
	  $sQuestCost = 382100
	  $sActionValue += 1
   Case 8
	  ;Update Current Quest Time
	  $sQuestTime = 38
	  $sActionValue += 1
   Case 9
	  ;Update Next Quest Cost
	  $sNextQuestCost = 1000000000000000000
	  $sActionValue += 1
   Case 10
	  ;Update Current Gems
	  $sGems = 7295
	  $sActionValue += 1
   Case 11
	  ;Update Current Gold
	  $sGold = 3000000000
	  $sActionValue += 1
   Case 12
	  ;Update Tribe
	  $sTribe = "Human"
	  $sActionValue += 1
   Case 13
	  ;Update Speed buff
	  $sSpeedBuff = False
	  $sActionValue += 1
   Case 14
	  ;Update Gem Buff
	  $sGemBuff = False
	  $sActionValue += 1
   Case 15
	  ;Update Switch Unit Tab
	  ;Update Current View
	  $sActionValue += 1
   Case 16
	  ;Update Ability 1
	  $sActionValue += 1
   Case 17
	  $sCore1Level = 1837
	  ;Update Core 1 Level
	  $sActionValue += 1
   Case 18
	  ;Update Core 2 Level
	  $sCore2Level = 1832
	  $sActionValue += 1
   Case 19
	  ;Update T3 Level
	  $sT3Unit1Level = 1825
	  $sActionValue += 1
   Case 20
	  $sSeniorUnitLevel = 1584
	  ;Update Senior Level
	  $sActionValue += 1
   Case 21
	  ;Update Switch Buy Unit
	  ;Update Current View
	  $sActionValue += 1
   Case 22
	  ;Update Refresh Timer
	  $sActionValue += 1
   Case 23
	  ;Update Switch Dungeon Tab
	  ;Update Current View
	  $sActionValue += 1
   Case 24
	  ;Update Ability 2
	  $sActionValue += 1
   Case 25
	  ;Update Ability 2
	  $sActionValue += 1
   Case 26
	  ;Update Dungeon Tickets
	  ;Set Dungeon by Schedule
	  $sActionValue += 1
   Case 27
	  ;Update Update Dungeon Rewards
	  $sActionValue += 1
   Case 28
	  ;Update Update Dungeon Rewards
	  $sActionValue += 1
   Case 29
	  ;Update Switch Artifact Tab
	  ;Update Current View
	  $sActionValue += 1
   Case 30
	  ;Update Switch Artifact Tab
	  ;Update Current View
	  $sActionValue += 1
   Case 31
	  ;Update Update Ability 3
	  $sActionValue += 1
   Case 32
	  ;Update Switch Battle Tab
	  ;Update Current View
	  $sActionValue += 1
   Case 33
	  ;Update Battle Arena Tickets
	  $sActionValue += 1
   Case 34
	  ;Update Tower of Trial Tickets
	  $sActionValue += 1
   Case 35
	  ;Update Outland Battle Tickets
	  $sActionValue += 1
   Case 36
	  ;Update Honor Coins
	  $sActionValue += 1
   Case 37
	  ;Update Switch Guild Tab
	  ;Update Current View
	  ;Set StagePlayable False
	  $sActionValue += 1
   Case 38
	  ;Update Switch Guild Quest Tab
	  ;Update Current View
	  $sActionValue += 1
   Case 39
	  ;Update Switch Guild War Tab
	  ;Update Current View
	  $sActionValue += 1
   Case 40
	  ;Update Switch Ongoing Guild War Tab
	  ;Update Current View
	  $sActionValue += 1
   Case 41
	  ;Update War Tickets
	  ;Switch Guild Quest Tab
	  ;Update Current View
	  $sActionValue += 1
   Case 42
	  ;Update Switch Guild Boss Raid
	  ;Update Current View
	  $sActionValue += 1
   Case 43
	  ;Update Switch Guild Boss Raid
	  ;Update Current View
	  $sActionValue += 1
   Case 44
	  ;Update Switch Ancient Ruins
	  ;Update Current View
	  $sActionValue += 1
   Case 45
	  ;Update Update Tickets
	  ;StagePlayable true
	  $sActionValue += 1
   Case 46
	  ;Update Switch Guild Members
	  ;Update Current View
	  $sActionValue += 1
   Case 47
	  ;Update Guild Gifts
	  ;Close Guild Tab
	  ;Update Current View
	  ;StagePlayable true
	  $sActionValue += 1
   Case 48
	  ;Update Switch Pet View
	  ;Update Current View
	  ;Stage Playble False
	  $sActionValue = 49
   Case 49
	  ;Update Switch Spirit Highlands Tab
	  ;Update Current View
	  $sActionValue = 50
   Case 50
	  ;Update Update Pet Tickets
	  ;Close Pet Tab
	  ;Update Current View
	  ;StagePlayable true
	  $sActionValue = 51
   Case 51
	  ;Update Switch Settings Tab
	  ;Update Current View
	  ;Stage Playble False
	  $sActionValue = 52
   Case 52
	  ;Update Switch Quiz Tab
	  ;Update Current View
	  $sActionValue = 53
   Case 53
	  ;Update Quiz Status
	  ;Switch Routlette Tab
	  ;Update Current View
	  $sActionValue = 54
   Case 54
	  ;Update Update Roulette Status
	  ;Close Roulette Tab
	  ;Update Current View
	  $sActionValue = 55
   Case 55
	  ;Update Close Settings Tab
	  ;Update Current View
	  ;StagePlayable true
	  $sActionValue = -1
   Case Else
	  $sErrorCount +=1
	  ConsoleWrite('(' & @ScriptLineNumber & ') : Update State Error '  & @CRLF)
   EndSwitch

   ReportState()
EndFunc
Func StartQuest()
   Switch $sAutoQuest
	  Case 26
		 If(TimerDiff($tQuestTime > 1000)) Then
			ClickRange(20,543,75,550)
			$tQuestTime = TimerInit()
		 EndIf
	  Case 27
		 If(TimerDiff($tQuestTime > 3000)) Then
			ClickRange(20,590,75,640)
			$tQuestTime = TimerInit()
		 EndIf
	  Case 28
		 If(TimerDiff($tQuestTime > 18000)) Then
			ClickRange(20,680,75,740)
			$tQuestTime = TimerInit()
		 EndIf
   EndSwitch
EndFunc
Func BuyUnit($Action)
   If ($Action <> 0) Then
	  ConsoleWrite('<'  & $Action)
   EndIf

   Switch $Action
   Case 0
	  HealthCheck()
	  $sActionValue += 1
	  $tRetryAction = TimerInit()
   Case 1
	  If (RetryAction(10)) Then
		 If (NoOverlay()) Then
			$sActionValue += 1
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>   Overlay Detected, Escaping '  & @CRLF)
		 Escape()
	  EndIf
   Case 2
	  ;Select Unit Tab
	  ClickRange(100,950,180,1015)
	  $sActionValue += 1
	  $tRetryAction = TimerInit()
   Case 3
	  If (RetryAction(5)) Then
		 ;Check if Unit Tab is loaded, Click Buy Unit Button
		 If (IsBright(GetColor(133,964)))Then
			ClickRange(475,475,540,515)
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Failed to Load Unit Tab '  & @CRLF)
	  EndIf
   Case 4
	  If (RetryAction(5)) Then
		 ;Check if Buy Unit Menu Close button is displayed
		 If(IsRed(GetColor(525,515))) Then
			If(IsBright(GetColor(293,488)) ) Then
			   ;Buy All
			   ClickRange(290,480,340,510)
			   $sActionValue += 3
			Else
			   ClickRange(375,480,480,515)
			   $sStagePlayable = False
			   $sActionValue += 1
			EndIf
			$tRetryAction = TimerInit()
			ConsoleWrite('<<R>>')
		 Else
			ConsoleWrite('<<NR>>')
		 EndIf
	  Else
		 $sActionValue += 1
	  EndIf
   Case 5
	  If (RetryAction(10)) Then
		 If Not(IsRed(GetColor(525,515), 100)) Then
			;Cancel Refresh if Gems are required
			ClickRange(310,640,440,650)
			$sActionValue += 4
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sActionValue += 1
		 $tRetryAction = TimerInit()
	  EndIf
   Case 6
	  If (RetryAction(5)) Then
		 If(IsBright(GetColor(293,488))) Then
			;Buy All
			ClickRange(280,480,340,510)
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Failed to Buy All Units '  & @CRLF)
	  EndIf

   Case 7
	  If (RetryAction(10)) Then
		 If (IsYellow(GetColor(7,446)) And IsYellow(GetColor(551,633))) Then
			;Accept Buy All
			ClickRange(155,560,250,600)
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Failed to Accept Buy All Units '  & @CRLF)
	  EndIf
   Case 8
	  If (RetryAction(10)) Then
		 If (IsYellow(GetColor(7,446)) And IsYellow(GetColor(549,653))) Then
			;Confirm Purchase
			ClickRange(230,575,320,600)
			$sActionValue += 1
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Failed to Confirm Buy All Units '  & @CRLF)
	  EndIf
   Case 9
	  If (RetryAction(10)) Then
		 ;Exit Buy Unit Menu
		 If(IsRed(GetColor(525,515), 100)) Then
			ClickRange(500,480,540,520)
			If Not (IsResting()) Then
			   $sStagePlayable = True
			   ConsoleWrite(': Not Resting '  )
			EndIf
			$sActionValue = -1
			ConsoleWrite(': Buy Unit Complete '  & @CRLF)
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Failed to Exit Buy Unit Page '  & @CRLF)
	  EndIf
   EndSwitch
EndFunc
Func SpiritPrint()
   If (IsResting()) Then
	  ConsoleWrite('Spirit Printing ' & @CRLF)
	  Local $Print = GetPrint(278,248,328,263,5)
	  Local $Match = True
	  Local $PrintSize = UBound($Print, $UBOUND_ROWS)
	  Local $sPrintSize = UBound($sSpiritRestPrint, $UBOUND_ROWS)
	  If ($PrintSize = $sPrintSize) Then
		 For $i = 0 To $PrintSize - 1 Step 1
			If Not( $Print[$i][2] = $sSpiritRestPrint[$i][2]) Then
			   $Match = False
			   ConsoleWrite('Differs: ' & $Print[$i][2] & ' : ' & $sSpiritRestPrint[$i][2] & @CRLF)
			Else
			   ConsoleWrite('Matches: ' & $Print[$i][2] & ' : ' & $sSpiritRestPrint[$i][2] & @CRLF)
			EndIf
		 Next
	  Else
		 $Match = False
	  EndIf

	  If ( $Match ) Then
		 ConsoleWrite('Print Matches! ' & @CRLF)
		 $sActionValue = 0
		 $sAction = "SpiritRestEnd"
		 SpiritRestEnd($sActionValue)
	  Else
		 $sSpiritRestPrint = $Print
		 ConsoleWrite('Match Failed ' & @CRLF)
		 $sActionValue = -1
	  EndIf
   EndIf
EndFunc
Func SpiritRestEnd($Action)
   If ($Action <> 0) Then
	  ConsoleWrite('<'  & $Action)
   EndIf
   Switch $Action
   Case 0
	  ;Check if Resting. Test for Red Info button of Spirit Rest Display
	  If (IsRed(GetColor( 510,167)))Then
		 $sStagePlayable = False
		 $sActionValue += 1
	  Else
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Spirit Rest NOT Active '  & @CRLF)
		 $sActionValue = -1
	  EndIf
   Case 1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Spirit Rest END? '  & @CRLF)
	  ;Click Rest End
	  If($restStarted And TimerDiff($tSpiritRestEnd) > 4 * 60 * 1000) Then
		 ClickRange(150,350,360,380)
		 $sActionValue += 1
		 $tRetryAction = TimerInit()
		 $tSpiritRestEnd = TimerInit()
	  Else
		 $sActionValue = -1
	  EndIf
   Case 2
	  If (RetryAction(10)) Then
		 ;Confirm Rest End
		 If (IsRed(GetColor( 127,334)))Then
			ClickRange(320,655,480,700)
			$sActionValue += 1
			$tSpiritRest = TimerInit()
			$tRetryAction = TimerInit()
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Failed to Confirm Rest End '  & @CRLF)
		 ClickRange(320,655,480,700)
	  EndIf
   Case 3
	  If (RetryAction(10)) Then
	  ;Confirm Rest End 2
		 If (IsYellow(GetColor( 7,340)) And IsYellow(GetColor( 549,531)))Then
			ClickRange(210,450,340,490)
			$sActionValue = -1
			ConsoleWrite('(' & @ScriptLineNumber & ') : Clicking Rest End 2 Confirm '  & @CRLF)
		 EndIf
	  Else
		 $sErrorCount += 1
		 $sActionValue = -1
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Failed to Accept Confirmation '  & @CRLF)
		 ClickRange(210,450,340,490)
	  EndIf
   EndSwitch
EndFunc

;Logic Functions
Func HealthCheck()
   Local $temp = hex(PixelGetColor(300, 475, $Handle ))
   Local $BadSwitch = False
   ;WinActivate($Window)
   ; Check if View Ad for Gems
   $temp = hex(PixelGetColor(110, 530, $Handle ))
   If (IsBlue($temp )) Then
	  ClickRange(126,580,256,634)
	  ConsoleWrite('(' & @ScriptLineNumber & ') : Gems! '  & @CRLF)
   EndIf
   ; Check if Outland Distortion
   $temp = GetColor(102, 502)
   If (IsBlue($temp, 150)) Then
	  ClickRange(230,740,330,780)
	  ConsoleWrite('(' & @ScriptLineNumber & ') : Outland Distortion! '  & @CRLF)
   EndIf
    ; Check for Unit Details
   If (IsRed(GetColor(510, 215)) And IsRed(GetColor(524, 525))) Then
	  ClickRange(500,195,545,240)
	  ConsoleWrite('(' & @ScriptLineNumber & ') : Unit Details Again! '  & @CRLF)
	  $sActionValue = -1
		 Sleep(500)
   EndIf
    ; Check for Unactivated Quest
   If (IsYellow(GetColor(9, 471)) And IsYellow(GetColor(549, 662))) Then
	  ClickRange(210,580,340,620)
	  ConsoleWrite('(' & @ScriptLineNumber & ') : Quest Not Active! '  & @CRLF)
		 Sleep(500)
   EndIf
    ; Check for Not Responding
   If (GetColor(430, 450) = "00282828") Then
	  If(GetColor(420, 600) = "00282828") Then
		 If(GetColor(420, 600) = "00282828") Then
			ClickRange(125,575,210,610)
			ConsoleWrite('(' & @ScriptLineNumber & ') : Not Responding '  & @CRLF)
			Sleep(3000)
		 EndIf
	  EndIf
   EndIf
    ; Check for Server connection Lost
   If (IsYellow(GetColor(60, 402))) Then
	  If(IsYellow(GetColor(496, 645))) Then
			ClickRange(210,530,340,560)
			CloseGame()
	  EndIf
   EndIf
    ; Check for Unit Details
   ;$temp = GetColor(275, 403)
   ;If (IsBright($temp, 170)) Then ;B9B9B9
	  ;ClickRange(200,530,350,570)
	  ;ConsoleWrite('(' & @ScriptLineNumber & ') : Server connection lost '  & @CRLF)
	;  CloseGame()
	;  $sActionValue = -1
	;	 Sleep(500)
   ;EndIf
   ;Check Game Lag
   If ($sGameLagRating > 40) Then
	  $sErrorCount += 1
	  $sGameLagRating = 0
	  ConsoleWrite('(' & @ScriptLineNumber & ') : ERROR:<'&$sErrorCount&'>  Game Lag '  & @CRLF)
   EndIf
   CheckErrors()
EndFunc
Func CheckErrors($Count=10)
   ;Set $Count to force game close at specific Error Count
   If($sErrorCount > $Count) Then
	  ConsoleWrite('(' & @ScriptLineNumber & ') : ErrorCount over 100 '  & @CRLF)
	  $sErrorCount = 0
	  CloseGame()
   EndIf
   If(TimerDiff($tError) > 2 * 60 * 1000) Then
	  $tError = TimerInit()
	  If($sErrorCount > $Count) Then
		 $sErrorCount = 0
		 ConsoleWrite('(' & @ScriptLineNumber & ') : ErrorCount too fast '  & @CRLF)
		 CloseGame()
	  EndIf
	  $sErrorCount = 0
   EndIf

EndFunc
Func CloseGame()
   $sErrorCount = 0
   ;Close Nox Window
   ControlClick($Window,"","","left",1, 543, 17 )
   ConsoleWrite('@@ Clicking Close Window ' & @CRLF )
   ConsoleWrite('Waiting: ' )
   ;Wait until restart dialog opens
   Do
	  $Handle = WinGetHandle("Dialog")
	  Sleep(1000)
	  $sErrorCount += 1
	  If($sErrorCount > 60 ) Then
		 ConsoleWrite('@@ HARD CLOSE ' & @CRLF )
		 HardClose()
		 ExitLoop
	  EndIf
	  ConsoleWrite('(' & $sErrorCount & ')' )
   Until(IsCyan(GetColor(100,170)) And IsCyan(GetColor(175,185)))

   If($sErrorCount < 61) Then
	  ConsoleWrite(' : Found' & @CRLF )

	  $Window = WinActivate("Dialog")

	  ConsoleWrite('@@ Clicking Restart ' & @CRLF )
	  ControlClick($Window,"","","left",1, 260, 175 )
	  ConsoleWrite('Waiting: ' )
	  Sleep(30000)
   EndIf
   $sErrorCount = 0

   ;Wait until google play logo loads in search bar
   Do
	  $Window = WinActivate("X001")
	  $Handle = WinGetHandle("X001")
	  Sleep(1000)
	  $sErrorCount += 1
	  ConsoleWrite('(' & $sErrorCount & ')' )
	  If($sErrorCount > 60 ) Then
		 ExitLoop
	  EndIf
   Until(IsCyan(GetColor(340,272)) And IsRed(GetColor(349,272)))
   ConsoleWrite(' : Found' & @CRLF )

   ;Wait until Endless Frontier Icon loads
   ConsoleWrite('@@ Waiting for icon: ' )
   $sErrorCount = 0
   Do
	  Sleep(1000)
	  $sErrorCount += 1
	  ConsoleWrite('(' & $sErrorCount & ')' )
	  If($sErrorCount > 60 ) Then
		 ExitLoop
	  EndIf
   Until(IsBright(GetColor(820,493)) And IsBright(GetColor(862,530)))
   ConsoleWrite(' : Found' & @CRLF )

   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Clicking Icon ' & @CRLF )
   ControlClick($Window,"","","left",1, 845, 360 )
   ;Wait until Endless Frontier loads
   ConsoleWrite('@@ Waiting for EF: ' )
   $sErrorCount = 0
   Do
	  Sleep(1000)
	  $sErrorCount += 1
	  ConsoleWrite('(' & $sErrorCount & ')' )
	  If($sErrorCount > 90 ) Then
		 ExitLoop
	  EndIf
   Until(IsYellow(GetColor(291,471)) And IsYellow(GetColor(829,867)))
   ConsoleWrite(' : Game Loaded' & @CRLF )

   $Handle = WinGetHandle($Emulator)
   $Window = WinActivate($Emulator)
   ControlMove( $Emulator,"","", 0, 0)
   Sleep(500)
   ControlClick ( $Emulator,"","[CLASS:Qt5QWindowIcon; INSTANCE:6]", "left", 1, 100, 10 )

   ;Close Offline details
   ClickRange(490,790,620,830)

   ;Close News
   $sErrorCount = 0
   Do
	  Sleep(1000)
	  $sErrorCount += 1
	  If($sErrorCount > 10 ) Then
		 ExitLoop
	  EndIf
   Until(IsRed(GetColor(755,830)))
   ClickRange(748,823,760,839)

   ;Clear any unexpected windows
   If Not (IsBright(GetColor(331,972))) Then
	  Escape()
   EndIf
EndFunc
Func ScriptHertz($Hertz, $HertzTimer) ; try to rate limit script speed
   Local $SleepLength = 0
   Local $HertzDiff = TimerDiff($HertzTimer)
   If $HertzDiff < (1000 / $Hertz) Then
	  $SleepLength = (1000 / $Hertz) - $HertzDiff
   EndIf
   Sleep($SleepLength)
EndFunc
Func ClickRange($x1,$y1,$x2,$y2,$clicks=0,$speed=0)
   Local $x = $x1
   Local $y = $y1
   For $i = 0 To $clicks Step 1
	  $x = Random($x1, $x2, 1)
	  $y = Random($y1, $y2, 1)
	  ControlClick($Window,"","","left",1, $x, $y )
	  Sleep($speed)
   Next
EndFunc
Func RetryAction($Seconds=1)
   If(TimerDiff($tRetryAction) > ($Seconds * 1000)) Then
	  Return False
   Else
	  Return True
   EndIf
EndFunc
Func IsResting()
   If (IsRed(GetColor( 510,167)))Then
	  $sStagePlayable = False
	  Return True
   Else
	  Return False
   EndIf
EndFunc
Func NoOverlay()
   Local $Overlay = False
   If (IsBright( GetColor(50,970), 200)) Then
	  $Overlay = True
   ElseIf (IsBright(GetColor(134,964), 200)) Then
	  $Overlay = True
   ElseIf (IsBright(GetColor(227,968), 200)) Then
	  $Overlay = True
   ElseIf (IsBright(GetColor(321,960), 200)) Then
	  $Overlay = True
   ElseIf (IsBright(GetColor(422,969), 200)) Then
	  $Overlay = True
   ElseIf (IsBright(GetColor(512,978), 200)) Then
	  $Overlay = True
   EndIf
   Return $Overlay
EndFunc
Func ScrollDown($Distance = 350)
   WinActivate($Window)
   MouseMove( 432, 935 )
   Sleep(100)
   MouseDown("left")
   MouseMove( 432, (935 - $Distance) )
   Sleep(100)
   MouseUp("left")
EndFunc
Func ScrollUp($Distance = 350)
   WinActivate($Window)
   MouseMove( 432, 550 )
   Sleep(100)
   MouseDown("left")
   MouseMove( 432, (550 + $Distance) )
   Sleep(100)
   MouseUp("left")
EndFunc
Func ReportState($force = 0)
   if( TimerDiff($tReport) > (30 * 1000)  ) or ($force = 1) Then
	  ;ConsoleWrite('Abils:<'&Time2Seconds(TimerDiff($tAbility1))&'><'&Time2Seconds(TimerDiff($tAbility2))&'><'&Time2Seconds(TimerDiff($tAbility3))&'> DoubleSpeed:<'&Time2Seconds(TimerDiff($tDoubleSpeed))&'> GoldAd:<'&Time2Seconds(TimerDiff($tGoldAd))&'>' & @CRLF)
	  ;ConsoleWrite('GemBf:<'&$sGemBuff&'> HonorCoins:<'&$sHonorCoins&'>GuildCoins:<'&$sGuildCoins&'>Gold:<'&$sGold&'>Gems:<'&$sGems&'>Level:<'&$sLevel&'>'& @CRLF)
	  ;ConsoleWrite('Quest:<'&$sQuest&'> AutoQuest:<'&$sAutoQuest&'> QuestTime:<'&$sQuestTime&'> QuestReward:<'&$sQuestReward&'> QuestCost:<'&$sQuestCost&'> QuestLevel:<'&$sQuestLevel&'>QLp:<'&$sQuestLevelPerMinute&'>NQ:<'&$sNextQuestCost&'>QY:<'&$sQuestY&'>' & @CRLF)
	  ;ConsoleWrite('Core1:<'&$sCore1Level&'> Core2:<'&$sCore2Level&'>T3:<'&$sT3Unit1Level&'>Senior:<'&$sSeniorUnitLevel&'>' & @CRLF)
	  ;ConsoleWrite('Stage:<'&$sStage&'> StartStage:<'&$sStartStage&'> Dungeon:<'&$sDungeon&'> DungeonTickets:<'&$sDungeonTickets&'>'& @CRLF)
	  ConsoleWrite( @CRLF & 'Action#:<'&$sActionValue&'> CurrentView:<'&$sCurrentView&'> Action:<'&$sAction&'> Errors:<'&$sErrorCount&'> PlayStage:<'&$sStagePlayable&'> AutoQuest:<'&$sAutoQuest&'>'&@CRLF)
	  ConsoleWrite('SpiritRestEnd:<'&((4 * 60 * 60) - Time2Seconds(TimerDiff($tSpiritRestEnd)))&'>'& 'QuestStatus:<'& $sQuestStatus & '>' & @CRLF)
	  $tReport = TimerInit()
   EndIf
EndFunc
Func Escape()
   While Not TestPixels($ExitWindow)
	  ControlSend($Window,"","","{ESC}")
	  Sleep(1000)
   Wend
   ClickRange(300,560,444,590)
   Sleep(1000)
EndFunc
Func HardClose()
   ProcessClose("NoxVMHandle.exe")
   Sleep(30000)
   Run ("C:\Program Files (x86)\Nox\bin\Nox.exe")
   Sleep(30000)
EndFunc

;Pixel Functions
Func IsRed(Const $RGB, Const $Contrast = 75)
   local $red = Dec(StringRight(StringLeft($RGB, 4), 2))
   local $green = Dec(StringRight(StringLeft($RGB, 6), 2))
   local $blue = Dec(StringRight($RGB, 2))
   If ( ($red - $green) > $Contrast And ($red - $blue) > $Contrast ) Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc
Func IsBlue(Const $RGB, Const $Contrast = 75)
   local $red = Dec(StringRight(StringLeft($RGB, 4), 2))
   local $green = Dec(StringRight(StringLeft($RGB, 6), 2))
   local $blue = Dec(StringRight($RGB, 2))
   If ( ($blue - $green) > $Contrast And ($blue - $red) > $Contrast ) Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc
Func IsGreen(Const $RGB, Const $Contrast = 75)
   local $red = Dec(StringRight(StringLeft($RGB, 4), 2))
   local $green = Dec(StringRight(StringLeft($RGB, 6), 2))
   local $blue = Dec(StringRight($RGB, 2))
   If ( ($green - $blue) > $Contrast And ($green - $red) > $Contrast ) Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc
Func IsYellow(Const $RGB, Const $Contrast = 75)
   local $red = Dec(StringRight(StringLeft($RGB, 4), 2))
   local $green = Dec(StringRight(StringLeft($RGB, 6), 2))
   local $blue = Dec(StringRight($RGB, 2))
   If ( ($red - $blue) > $Contrast And ($green - $blue) > $Contrast ) Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc
Func IsPurple(Const $RGB, $Contrast = 75)
   local $red = Dec(StringRight(StringLeft($RGB, 4), 2))
   local $green = Dec(StringRight(StringLeft($RGB, 6), 2))
   local $blue = Dec(StringRight($RGB, 2))
   If ( ($red - $green) > $Contrast And ($blue - $green) > $Contrast ) Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc

Func IsCyan(Const $RGB, Const $Contrast = 75)
   local $red = Dec(StringRight(StringLeft($RGB, 4), 2))
   local $green = Dec(StringRight(StringLeft($RGB, 6), 2))
   local $blue = Dec(StringRight($RGB, 2))
   If ( ($blue - $red) > $Contrast And ($green - $red) > $Contrast ) Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc
Func IsBright(Const $RGB, Const $Contrast = 100)
   local $red = Dec(StringRight(StringLeft($RGB, 4), 2))
   local $green = Dec(StringRight(StringLeft($RGB, 6), 2))
   local $blue = Dec(StringRight($RGB, 2))
   If ( $green > $Contrast ) Then
		; ConsoleWrite('(' & @ScriptLineNumber & ') :Bright Green '  & @CRLF)
	  Return True
   ElseIf ($red > $Contrast ) Then
		; ConsoleWrite('(' & @ScriptLineNumber & ') :Bright Red '  & @CRLF)
	  Return True
   ElseIf ($blue > $Contrast ) Then
		; ConsoleWrite('(' & @ScriptLineNumber & ') :Bright Blue '  & @CRLF)
	  Return True
   Else
		 ;ConsoleWrite('(' & @ScriptLineNumber & ') : green: ' & $green & ' blue: ' & $blue & ' red: ' & $red  & @CRLF)
	  Return False
   EndIf
EndFunc
Func GetColor(Const $X, Const $Y, $Verbose = False)
   local $Color = Hex(PixelGetColor( $X, $Y, $Handle))
   If ( $Verbose ) Then
	  ConsoleWrite('(' & @ScriptLineNumber & ') : Color: <'&$Color&'> '  & @CRLF)
   EndIf
   Return $Color
EndFunc
Func TestPixel($Color, $Shades = 5)
   Local $Match = False
   Local $PixelColor = GetColor( $Color[0], $Color[1])
   Local $R = Dec(StringRight(StringLeft($Color[2],4),2))
   Local $G = Dec(StringLeft(StringRight($Color[2],4),2))
   Local $B = Dec(StringRight($Color[2],2))
   Local $R2 = Dec(StringRight(StringLeft($PixelColor,4),2))
   Local $G2 = Dec(StringLeft(StringRight($PixelColor,4),2))
   Local $B2 = Dec(StringRight($PixelColor,2))
  ; WinActivate($Window)
   If(Abs($R - $R2) <  $Shades ) And (Abs($G - $G2) < $Shades) And (Abs($B - $B2) <  $Shades ) Then
	  $Match = True
   EndIf
   return $Match
EndFunc
Func GetPrint($x1, $y1, $x2, $y2, $dpi)
   $xloop = ($x2 - $x1) / $dpi
   $yloop = ($y2 - $y1) / $dpi
   $increment = 0
   $size = ($dpi + 1) ^ 2
   Local $Map[$size][3]
    WinActivate($Window)
   For $i = $x1 To $x2 Step $xloop
	  For $i2 = $y1 To $y2 Step $yloop
		 $Map[$increment][0] = round($i)
		 $Map[$increment][1] = round($i2)
		 $Map[$increment][2] = hex(PixelGetColor( round($i), round($i2), $Handle ))

		 If ( $increment <> $size - 1 ) Then
		 EndIf
		 $increment += 1
	  Next
   Next
   Return $Map
EndFunc
Func WritePrint($Print)
   Local $Size = UBound($Print)
   If ($Size > 0) Then
	  For $i = 0 To $Size - 1 Step 1
		 ConsoleWrite('["' & $Print[$i][0]  & '","' & $Print[$i][1]  & '","' & $Print[$i][2]  & '"]')
		 If ( $i <> $Size - 1 ) Then
			ConsoleWrite(', _' & @CRLF)
		 EndIf
	  Next
   Else
	  ConsoleWrite('Not an Array' & @CRLF)
   EndIf
EndFunc


Func FindCurrentView()
    WinActivate($Window)
   If(TestPixel($qTab1)) Then
	  $sCurrentView = "qTab1"
   ElseIf(TestPixel($qTab2)) Then
	  If(TestPixel($qGem))Then
		 $sCurrentView = "Quest1"
	  ElseIf(TestPixel($qOffline)) Then
		 $sCurrentView = "Quest2"
	  ElseIf(TestPixel($qDetail)) Then
		 $sCurrentView = "Quest3"
	  ElseIf(TestPixel($qNews)) Then
		 $sCurrentView = "Quest4"
	  EndIf
   ElseIf(TestPixel($uTab1)) Then
		 $temp = hex(PixelGetColor( $uUnits[0], $uUnits[1], $Handle ))
	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : UnitTAB ' & $uUnits[0] & " " & $uUnits[1] & " " & $temp & @CRLF)

	  If(TestPixel($uUnits))Then
		 $sCurrentView = "Unit0"
	  ElseIf(TestPixel($uBuyUnits)) Then
		 $sCurrentView = "Unit1"
	  EndIf
   ElseIf(TestPixel($uTab2)) Then
	  If(TestPixel($uBuyMedal))Then
		 $sCurrentView = "Unit2"
	  ElseIf(TestPixel($uBuyGem)) Then
		 $sCurrentView = "Unit3"
	  ElseIf(TestPixel($uSkill)) Then
		 $sCurrentView = "Unit4"
	  ElseIf(TestPixel($uEvent)) Then
		 $sCurrentView = "Unit5"
	  EndIf
   ElseIf(TestPixel($dTab1)) Then
	  If(TestPixel($dTab))Then
		 $sCurrentView = "Dungeon0"
	  ElseIf(TestPixel($dMole)) Then
		 $sCurrentView = "Dungeon1"
	  ElseIf(TestPixel($dFlower)) Then
		 $sCurrentView = "Dungeon2"
	  ElseIf(TestPixel($dSlime)) Then
		 $sCurrentView = "Dungeon3"
	  ElseIf(TestPixel($dToad)) Then
		 $sCurrentView = "Dungeon4"
	  ElseIf(TestPixel($dHermit)) Then
		 $sCurrentView = "Dungeon5"
	  EndIf
   ElseIf(TestPixel($dTab2)) Then
	  If(TestPixel($dSkill))Then
		 $sCurrentView = "Dungeon6"
	  ElseIf(TestPixel($dCleared)) Then
		 $sCurrentView = "Dungeon7"
	  ElseIf(TestPixel($dDetail)) Then
		 $sCurrentView = "Dungeon8"
	  EndIf

   ElseIf(TestPixel($aTab1)) Then
   ElseIf(TestPixel($aTab2)) Then
   ElseIf(TestPixel($bTab1)) Then
   ElseIf(TestPixel($bTab2)) Then
   ElseIf(TestPixel($sTab1)) Then
   ElseIf(TestPixel($sTab2)) Then
   EndIf

EndFunc
Func Time2Seconds($Time)
	  $Time = Round ($Time)
	  $Time = $Time / 1000
	  $Time = Round ($Time)
	  Return $Time
EndFunc
Func QuestDetail()
	  If (TestPixel($questDetail))Then
		 ClickRange(220,730,330,780)
		 ConsoleWrite('(' & @ScriptLineNumber & ') : Detail Found'  )
	  EndIf
EndFunc



Func UseAbility($mode)
   Local $LagDelay = 1000
   If $mode = 1 Then
	  If TimerDiff($tAbility1) > (36000 + $LagDelay) Then
		 ClickRange(195,75,210,95)
		 ConsoleWrite('(Spear 1)' )
		 $tAbility1 = TimerInit()
	  ElseIf TimerDiff($tAbility2) > (43000 + $LagDelay) Then
		 ClickRange(245,75,260,95)
		 ConsoleWrite('(Spear 2)' )
		 $tAbility2 = TimerInit()
	  ElseIf TimerDiff($tAbility3) > (52000 + $LagDelay) Then
		 ClickRange(295,75,310,95)
		 ConsoleWrite('(Spear 3)' )
		 $tAbility3 = TimerInit()
	  EndIf
   Else
	  If TimerDiff($tAbility1) > 36000 Then
		 ControlClick($Window,"","","left",1, 50, 495 )
		 $tAbility1 = TimerInit()
	  ElseIf TimerDiff($tAbility2) > 43000 Then
		 ControlClick($Window,"","","left",1, 140, 495 )
		 $tAbility2 = TimerInit()
	  ElseIf TimerDiff($tAbility3) > 52000 Then
		 ControlClick($Window,"","","left",1, 220, 495 )
		 $tAbility3 = TimerInit()
	  EndIf
   EndIf
EndFunc

Func PushUnits($First)
	  ;Select Unit Tab
	  ControlClick($Window,"","","left",1, 140, 980 )
	  WinActivate($Window)
   If $First = 0 Then

	  ;Wait for Page to load, checks for Buy Unit Menu button
	  If Not LoadPage($BuyUnitMenu, "Unit Menu") Then Return

	  ;Scroll to top
	  For $i = 0 To 3 Step 1
		 MouseMove(386, 550)
		 MouseDown("left")
		 MouseMove(386, 920)
		 MouseUp("left")
		 Sleep(200)
	  Next
	  Sleep(1000)
   EndIf

   $UpgradeUnit =  PixelSearch(438, 540, 438, 730,0xFDBE1B,2,1, $Handle)
   If Not @error Then
	  ControlClick($Window,"","","left",3, 480, $UpgradeUnit[1])
	  Sleep(500)
	  $BigUpgrades =  PixelSearch(190, $UpgradeUnit[1], 225, $UpgradeUnit[1],0x090909,1,1, $Handle)
	  If Not @error Then
		 ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Found Big Upgrades  ' & @CRLF )
		 ControlClick($Window,"","","left",4,190, $UpgradeUnit[1])
	  EndIf
	  ControlClick($Window,"","","left",5, 480, $UpgradeUnit[1])
   EndIf
   SetError(0)
   Sleep(100)
   If (TestPixels($TopUnitMax)) Then
	  If (TestPixels($NextUnitMax))Then
		 ;Set Unitpush timer out 10 minutes
		 $PushTimer = TimerDiff($Timer) + 1000 * 60 * 1000
		 $QuestPushTimer = TimerDiff($Timer) + 200 * 60 * 1000
	  EndIf
   EndIf

   ControlClick($Window,"","","left",3,45,980)
   For $i=0 To 50 Step 1
	  ControlClick($Window,"","","left",3,50,595)
	  Sleep(100)
	  ControlClick($Window,"","","left",3,50,695)
	  Sleep(100)
	  ControlClick($Window,"","","left",3,50,795)
	  Sleep(100)
	  ControlClick($Window,"","","left",3,130,310)
	  Sleep(100)
   Next



EndFunc


Func QuestPushing()
   WinActivate($Window)
   ;Look for active quest below 750 y axis
   Local $AffordableQuest =  PixelSearch(438, 945, 439, 750,0xF7BE20,1,1, $Handle)
   If Not @error Then
	  ;Buy the new quest
	  ControlClick($Window,"","","left",3,475, $AffordableQuest[1])
	  ;Set Unitpush timer out 10 minutes
	  $PushTimer = TimerDiff($Timer) + $PushMinutes * 60 * 1000
	  ;Add 30 minutes to Quest TimerDiff
	  $QuestPushTimer = $PushTimer + $qPushMinutes * 60 * 1000
   Else
	  ;Look for the current quest and launch it
	  SetError(0)
	  Local $CurrentQuest =  PixelSearch(438, 750, 439, 540,0xF7BE20,1,1, $Handle)
	  If Not @error Then ControlClick($Window,"","","left",3,50, $CurrentQuest[1])
   EndIf
   SetError(0)

EndFunc
Func TestPixels ($Colors)
   Local $Match = True
   WinActivate($Window)
   For $fi = 0 To UBound($Colors) - 1 Step 1
		 $temp = hex(PixelGetColor( $Colors[$fi][0], $Colors[$fi][1], $Handle ))
		 if($Colors[$fi][2] <> $temp) Then
			$Match = False
		 EndIf
		; MouseMove($Colors[$fi][0], $Colors[$fi][1])
   Next
   return $Match
EndFunc

Func FindChest($ChestColor)
   $ChestLocation =  PixelSearch(0, 310, 340, 311,0xF9BF2B,1,1, $Handle)
   If Not @error Then
	  ControlClick($Window,"","","left",1, $ChestLocation[0], $ChestLocation[1] )
	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Found Chest!!!!  ' & hex($ChestColor) & @CRLF )
   Else
	  SetError(0)
   EndIf


EndFunc
Func Dungeon()
   ;Select Dungeon Tab
   ControlClick($Window,"","","left",1, 230, 980 )

   ;Wait for Page to load, checks for Tab color to change
   If Not LoadPage($DungeonLoaded, "Dungeon Menu") Then Return
   ;Find Dungeons
   ;$TopDungeon = PixelSearch(468, 540, 468, 950,0xDF0202,1,1, $Handle)
   ;$LowerDungeon = PixelSearch(468, 950, 468, $TopDungeon[1] + 60 ,0xDF0202,1,1, $Handle)
   ;If @error Then
   ;  $LowerDungeon = $TopDungeon
	;  $LowerDungeon[1] = 945
   ;EndIf
   ;SetError(0)
   ;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Top:  ' & $TopDungeon[1] & ' Lower: ' & $LowerDungeon[1] & @CRLF )

   ;If available Dungeon is Horn Toad (No Elves) Then set both dungeons the same
   ;IF $TopDungeon[1] > 640 And $TopDungeon[1] < 720 Then
	;  $TopDungeon = $LowerDungeon
   ;ElseIf $LowerDungeon[1] > 640 And $LowerDungeon[1] < 720 Then
	;  $LowerDungeon = $TopDungeon
   ;EndIf
   ;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Top:  ' & $TopDungeon[1] & ' Lower: ' & $LowerDungeon[1] & @CRLF )

	  ;$TopDungeon[1] = 680
	  ;$LowerDungeon[1] = 680
   $MoreTickets = True
   While $MoreTickets
	  If TestPixels($DungeonTickets0) Then
		 ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : No Tickets' & @CRLF )
		 ExitLoop
	  ElseIf TestPixels($DungeonTickets1) Then
		 $MoreTickets = False
		 ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Last Ticket' & @CRLF )
	  EndIf
	  If LoadPage($OrcFlower, "OrcFlower") Then
		 ControlClick($Window,"","","left",1, 500, 870 )
		 SelectDungeonLevel(3)
	  ElseIf LoadPage($DarkHermit, "DarkHermet") Then
		 ControlClick($Window,"","","left",1, 500, 940 )
		 SelectDungeonLevel(3)
	  ElseIf LoadPage($KingSlime, "KingSlime") Then
		 ControlClick($Window,"","","left",1, 500, 580 )
		 SelectDungeonLevel(2)
	  ElseIf LoadPage($HammerMole, "HammerMole") Then
		 ControlClick($Window,"","","left",1, 500, 775 )
		 SelectDungeonLevel(3)
	  EndIf
	  Sleep(2000)
   WEnd
EndFunc
Func SelectDungeonLevel($Dungeon)

   ;Wait for Page to load, checks for Red X Button
   If Not LoadPage($DungeonLevels, "Dungeon Levels") Then Return

   If $Dungeon = 1 Then
	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Entering Dungeon Level 33' & @CRLF )
	  ControlClick($Window,"","","left",1, 483, 595 )
   ElseIf  $Dungeon = 2  Then
	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Entering Dungeon Level 34' & @CRLF )
	  ControlClick($Window,"","","left",1, 483, 680 )
   ElseIf $Dungeon = 3  Then
	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Entering Dungeon Level 35' & @CRLF )
	  ControlClick($Window,"","","left",1, 483, 780 )
   EndIf

   ;Wait for Page to load, checks for Red X Button
   Local $Counting = 0
   While Not LoadPage($DungeonComplete, "Dungeon Completion", 2)
	  UseAbility(2)
	  Sleep(1000)
	  $Counting += 1
	  If $Counting > 120 Then Return
   WEnd

   ;Click Dungeon Confirmation Button
   ControlClick($Window,"","","left",1, 275, 840 )
   Sleep(2000)
EndFunc
Func Raid($Level, $Stage, $Boss)
   Escape()
   ;Wait for Page to load, checks for Red X Button
   If LoadPage($GuildUp, "Guild Menu Up", 1) Then
	  ControlClick($Window,"","","left",1, 426, 54 )
   ElseIf LoadPage($GuildDown, "Guild Menu Down", 1) Then
	  ControlClick($Window,"","","left",1, 426, 101 )
   EndIf
   ControlClick($Window,"","","left",1, 426, 54 )

   If LoadPage($GuildQuest, "Guild Quest Button") Then
	  ControlClick($Window,"","","left",1, 170, 990 )
   Else
	  Return
   EndIf

   If LoadPage($GuildRaid, "Guild Boss Raid Button") Then
	  ControlClick($Window,"","","left",1, 480, 510 )
   Else
	  Return
   EndIf

   If LoadPage($GuildRaidLevel, "Guild Raid Red Button") Then
	  If $Level = 1 Then
		 ControlClick($Window,"","","left",1, 500, 330 )
	  ElseIf $Level = 2 Then
		 ControlClick($Window,"","","left",1, 500, 420 )
	  ElseIf $Level = 3 Then
		 ControlClick($Window,"","","left",1, 500, 510 )
	  EndIf
   Else
	  Return
   EndIf

   If LoadPage($GuildRaidStage, "Guild Raid Stage Icon") Then
	  If $Stage = 1 Then
		 ControlClick($Window,"","","left",1, 500, 330 )
	  ElseIf $Stage = 2 Then
		 ControlClick($Window,"","","left",1, 500, 420 )
	  ElseIf $Stage = 3 Then
		 ControlClick($Window,"","","left",1, 500, 510 )
	  EndIf
   Else
	  Return
   EndIf

   If LoadPage($GuildRaidBoss, "Guild Raid Boss Give Up Button") Then
	  If $Boss = 1 Then
		 ControlClick($Window,"","","left",1, 500, 330 )
	  ElseIf $Boss = 2 Then
		 ControlClick($Window,"","","left",1, 500, 420 )
	  ElseIf $Boss = 3 Then
		 ControlClick($Window,"","","left",1, 500, 510 )
	  ElseIf $Boss = 4 Then
		 ControlClick($Window,"","","left",1, 500, 600 )
	  EndIf
   Else
	  Return
   EndIf

   If LoadPage($GuildRaidPrepare, "Guild Raid Prepare Battle Button") Then
	  ControlClick($Window,"","","left",1, 280, 970 )
   Else
	  Return
   EndIf

   Sleep(5000)
   ;Change orientation
   ControlClick($Window,"","","left",1, 523, 60 )
   Sleep(10000)
   ControlClick($Window,"","","left",1, 310, 85 )
   Sleep(8000)
   ControlClick($Window,"","","left",1, 255, 85 )
   ControlClick($Window,"","","left",1, 205, 85 )
   Sleep(49000)
   ControlClick($Window,"","","left",1, 255, 85 )
   ControlClick($Window,"","","left",1, 205, 85 )
   Sleep(8000)
   ControlClick($Window,"","","left",1, 310, 85 )


   ;Wait for Page to load, checks for Red X Button
   If Not LoadPage($RaidComplete, "Raid Completion", 600) Then Return

   ;Click Dungeon Confirmation Button
   ControlClick($Window,"","","left",1, 280, 880 )
   Sleep(2000)
   Escape()
EndFunc

Func BattleArena()
   ;Select Battle Tab
   ControlClick($Window,"","","left",1, 420, 980 )

   ;Wait for Page to load, checks for Tab color to change
   If Not LoadPage($BattleTab, "Battle Menu") Then Return

   ;Click Battle Arena
   ControlClick($Window,"","","left",1, 480, 580 )

   ;Wait for Arena to load, checks for Red X button
   If Not LoadPage($BattleArena, "Battle Arena") Then Return

   ;Check if there's at least 1 ticket, tries to match 0 tickets.
   While Not LoadPage($BattleArenaTickets0, "Battle Tickets", 10)
	  ;Click Battle Arena
	  ControlClick($Window,"","","left",1, 400, 870 )

	  ;Wait for Page to load, checks for Confirm Button
	  If Not LoadEitherPage($BattleArenaConfirmation, $BattleArenaConfirmation2, "Arena Battle Confirmation", 600) Then Return

	  ;Accept Confirmation
	  ControlClick($Window,"","","left",1, 285, 790 )

	  ;Wait for Arena to load, checks for Red X button
	  If Not LoadPage($BattleArena, "Battle Arena") Then Return
   WEnd
EndFunc
Func LoadPage(Const $Fingerprint, Const $Description, Const $Timer = 40)
   Local $Counter = 0
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Loading ' & $Description & @CRLF )
   While Not TestPixels($Fingerprint)
	  Sleep(100)
	  If $Counter > $Timer Then
		 ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Too Long, quitting' & @CRLF )
		 Return False
	  EndIf
	  $Counter += 1
   WEnd
   Return True
EndFunc
Func LoadEitherPage(Const $Fingerprint, Const $Fingerprint2, Const $Description, Const $Timer = 40)
   Local $Counter = 0
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Loading ' & $Description & @CRLF )
   Local $Searching = True
   While $Searching
	  If TestPixels($Fingerprint) Then $Searching = False
	  If TestPixels($Fingerprint2) Then $Searching = False
	  Sleep(100)
	  If $Counter > $Timer Then
		 ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Too Long, quitting' & @CRLF )
		 Escape()
		 Return False
	  EndIf
	  $Counter += 1
   WEnd
   Return True
EndFunc

Func Revive()
   $LastQuest = 0
EndFunc



Func PlayRoulette($t=430)
   ;450 = 1 too far with 2 used
   ;450 = 2 too far first try
   ;400 = 2 short second try
   Local $MousePos = MouseGetPos()
   Local $Searching = True
   While $Searching
	  $Pixel = PixelGetColor( $MousePos[0], $MousePos[1], $Handle )
	  if ($Pixel = 0xFFC800) Then $Searching = False
	  if ($Pixel = 0xD8AB07) Then $Searching = False
	  if ($Pixel = 0x816A18) Then $Searching = False
	  if ($Pixel = 0x927200) Then $Searching = False
   WEnd
   Sleep($t)
   ControlClick($Window,"","","left",1,280, 526)
   ConsoleWrite('color: ' & hex($Pixel) & @CRLF )
EndFunc

Func TestFingerPrint(Const $FingerPrint)
   Local $Match = LoadPage($FingerPrint, "Test Print", 1)
   If $Match Then
	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Fingerprint Matches' & @CRLF )
   Else
	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : FingerPrint not found' & @CRLF )
   EndIf
EndFunc
Func RedGTE(Const $Pixel, Const $Reference)
   local $r1 = StringRight(StringLeft($Pixel, 4), 2)
   local $r2 = StringRight(StringLeft($Reference, 4), 2)
   If ( Dec($r1) >= Dec($r2)) Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc
Func BlueGTE(Const $Pixel, Const $Reference)
   local $b1 = StringRight($Pixel, 2)
   local $b2 = StringRight($Reference, 2)
   If ( Dec($b1) >= Dec($b2)) Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc
Func GreenGTE(Const $Pixel, Const $Reference)
   local $g1 = StringRight(StringLeft($Pixel, 6), 2)
   local $g2 = StringRight(StringLeft($Reference, 6), 2)
   If ( Dec($g1) >= Dec($g2)) Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc
Func GreenGT(Const $Pixel, Const $Reference)
   local $g1 = StringRight(StringLeft($Pixel, 6), 2)
   local $g2 = StringRight(StringLeft($Reference, 6), 2)
   If ( Dec($g1) > Dec($g2)) Then
	  Return True
   Else
	  Return False
   EndIf
EndFunc
Func StartGame($g, $t)
   Run($g)
   WinWaitActive($Emulator)
   Sleep($t)
EndFunc
Func ClickAt($X, $Y)
   ControlClick($Emulator ,"", "","left", 1, $X, $Y )
   ConsoleWrite(' X:  <' & $X & '>' & ' Y:  <' & $Y & '>' )
EndFunc
Func SearchColor($l, $t, $r, $b,  $color)
   $Pixel = 0
   $Counter = 0
	  ConsoleWrite('color: ' & $color & ' l: ' & $l & ' t: ' & $t & ' b: ' & $b & ' r: ' & $r & @CRLF )
   While ($Pixel <> $color)
	  $Search = PixelSearch($l * $XR, $t * $YR, $r * $XR, $b * $YR,$color,1,2, $Handle)
			If @error <> 0 Then
			Else
				ConsoleWrite(' : Found Result <' & $Search & '>' )
				$Pixel = $color
			EndIf
	  Sleep(500)
	  ConsoleWrite('.' )
	  $Counter += 1
	  If ( $Counter > 60 ) Then
		 $Pixel = $color
	  EndIf
   Wend
	  ConsoleWrite( @CRLF )
EndFunc
Func CheckColor($l, $t, $r, $b,  $color)
   $Pixel = 0
    WinActivate($Window)
	  $Search = PixelSearch($l * $XR, $t * $YR, $r * $XR, $b * $YR,$color,1,2, $Handle)
	  If @error <> 0 Then
		  Return False
		 ConsoleWrite('No Loading Screen' & @CRLF )
	  Else
		  Return True
	  EndIf
EndFunc
Func Quit($why="Hotkey")
	MsgBox(0,"exit","program quit: " & $why)
	Exit
EndFunc
Func HotKeyPressed()
   Switch @HotKeyPressed
	  Case "{PAUSE}"
		 $sPaused = Not $sPaused
		 While $sPaused
			Sleep(100)
			ToolTip('Script is "Paused"', 0, 0)
		 WEnd
		 ToolTip("")

	  Case "{F6}"
		 $sPaused = Not $sPaused
		 While $sPaused
			Sleep(100)
			ToolTip('Script is "Paused"', 0, 0)
		 WEnd
		 ToolTip("")

	  Case "{F7}"
		 $sQuesting = Not $sQuesting
		 If($sQuesting) Then
			ToolTip("")
		 Else
			ToolTip('Skipping Questing', 0, 0)
		 $sActionValue = -1
		 EndIf


	  Case "{ESC}"
		 ;Exit
		 MsgBox($MB_SYSTEMMODAL, "QUIT","Program Quit: Hotkey Press")
		 Exit

	  Case "{END}"
		 ;Restart the Game
		 ConsoleWrite('(' & @ScriptLineNumber & ') : END hotkey pressed '  & @CRLF)
		 CloseGame()

	  Case "{NumPadMult}"
		 ;Start Pushing Quests
		  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Time: '& _NowTime() & @CRLF )
		 ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Saving for Better Quests  ' & @CRLF )
		 $QuestPushTimer = TimerDiff($Timer)
		 $PushTimer = $QuestPushTimer + 1800000
   EndSwitch
EndFunc