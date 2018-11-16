#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <Misc.au3>
#Include <WinAPIShellEx.au3>
#Include <WinAPI.au3>
#Include <WinAPISys.au3>
#include <WinAPIConstants.au3>
#include <Array.au3>
#include <MsgBoxConstants.au3>
#include <ScreenCapture.au3>


#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

HotKeySet("{pause}", "Quit") ; Hotkey for exiting the script at any time
HotKeySet("{SCROLLLOCK}", "Pause") ; Hotkey for exiting the script at any time
;!q:: ; Hotkey to execute the script - remove this if you want to run the script as soon as you execute the file



Global $Droid4X = "Droid4X 0.10.5 Beta"                  ; Current Droid Window Title
Global $t = 1000                                         ; Standard Sleep intervale
Global $D4XClass = "Qt5QWindowIcon"
Global $D4XTitle = "Qt5QWindowIcon11"
Global $D4XTitleText = "widgetTitleWindow"
Global $D4XMenu = "Qt5QWindowIcon1"
Global $D4XMenuText = "widgetToolbarFormWindow"
Global $D4XWindow = "Qt5QWindowIcon9"
Global $D4XWindowText = "screenWindow"
Global $hwnd
StartGame($t)
ControlMove( $Droid4X,"","", 0, 0)
$WindowSize = WinGetClientSize($Droid4X)
Global $YR = $WindowSize[1] / 1040
Global $XR = $WindowSize[0] / 627
If($WindowSize[0] <> 627)Then
	ConsoleWrite('@@ WARNING! WINDOW WIDTH IS NOT 627 ' & @CRLF)
 EndIf
 If($WindowSize[1] <> 1040)Then
	ConsoleWrite('@@ WARNING! WINDOW HEIGHT IS NOT 1040 ' & @CRLF)
EndIf
AutoItSetOption("SendKeyDelay", 60)
AutoItSetOption("MouseCoordMode", 0)
AutoItSetOption("PixelCoordMode", 0)
Prep($t)
While -1 ; set this to whatever you want - this determines how often you fish before you have to hit the start hotkey again
	ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : START SQUENCE !!! '  & @CRLF)
	StartSequence()
	ConsoleWrite(@CRLF)
WEnd
Quit("EOF")


Func StartSequence()
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickHome '  & @CRLF )
   ClickHome($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickBack  '  & @CRLF )
   ClickBack($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : DokkanReroll  '  & @CRLF )
   DokkanReroll($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickHercule  '  & @CRLF )
   ClickHercule(2000)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : StartDokkan  '  & @CRLF )
   StartDokkan($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickSkip  '  & @CRLF )
   ClickSkip($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickOK  '  & @CRLF )
   ClickOK($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickSkip  '  & @CRLF )
   ClickSkip($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickClose  '  & @CRLF )
   ClickClose($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickOKGifts  '  & @CRLF )
   ClickOKGifts($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickClose  '  & @CRLF )
   ClickClose($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickClose  '  & @CRLF )
   ClickClose($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickClose  '  & @CRLF )
   ClickClose($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickSummonClose  '  & @CRLF )
   ClickSummonClose($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickBannerClose  '  & @CRLF )
   ClickBannerClose($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickSkip  '  & @CRLF )
   ClickSkip($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickRecruitOK  '  & @CRLF )
   ClickRecruitOK($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : OpenGifts  '  & @CRLF )
   OpenGifts($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : AcceptAll  '  & @CRLF )
   AcceptAll($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : AcceptAllOK  '  & @CRLF )
   AcceptAllOK($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : AcceptAllOK2  '  & @CRLF )
   AcceptAllOK2($t)

   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : OpenStore  '  & @CRLF )
   OpenStore($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : BabaShop  '  & @CRLF )
   BabaShop(2000)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickSkip  '  & @CRLF )
   ClickSkip($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : AddTradePoints  '  & @CRLF )
   AddTradePoints($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickSkip  '  & @CRLF )
   ClickSkip($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : AwakenPoints  '  & @CRLF )
   AwakenPoints($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : SelectAwaken  '  & @CRLF )
   SelectAwaken($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmSale  '  & @CRLF )
   ConfirmSale($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmSale2  '  & @CRLF )
   ConfirmSale2($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ExchangeComplete  '  & @CRLF )
   ExchangeComplete($t)

   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : OpenStore  '  & @CRLF )
   OpenStore($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : BabaShop  '  & @CRLF )
   BabaShop($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ExpandShop  '  & @CRLF )
   ExpandShop($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : UnlockSlot  '  & @CRLF )
   UnlockSlot($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : UnlockSlot  '  & @CRLF )
   UnlockSlotOK(2000)

   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : OpenMenu  '  & @CRLF )
   OpenMenu($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : BackupCode  '  & @CRLF )
   BackupCode($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : CreateCode  '  & @CRLF )
   CreateCode($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : CreateCodeOK  '  & @CRLF )
   CreateCodeOK($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickZHome  '  & @CRLF )
   ClickZHome($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickMission  '  & @CRLF )
   ClickMission($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickKorinMission  '  & @CRLF )
   ClickKorinMission($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClaimReward  '  & @CRLF )
   ClaimReward($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmKorinReward  '  & @CRLF )
   ConfirmKorinReward($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmRecieved  '  & @CRLF )
   ConfirmRecieved($t)

   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClaimReward  '  & @CRLF )
   ClaimReward($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmKorinReward  '  & @CRLF )
   ConfirmKorinReward($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmRecieved  '  & @CRLF )
   ConfirmRecieved($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClaimReward  '  & @CRLF )
   ClaimReward($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmKorinReward  '  & @CRLF )
   ConfirmKorinReward($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmRecieved  '  & @CRLF )
   ConfirmRecieved($t)

 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : StartSummon  '  & @CRLF )
 ;  StartSummon($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ScrollDown  '  & @CRLF )
 ;  ScrollDown($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : SingleSummon '  & @CRLF )
 ;  SingleSummon($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmSummon  '  & @CRLF )
 ;  ConfirmSummon($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Pull  '  & @CRLF )
 ;  Pull($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickScreen '  & @CRLF )
 ;  ClickScreen($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickAgain  '  & @CRLF )
 ;  ClickAgain($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : AcceptReward  '  & @CRLF )
 ;  AcceptReward($t)

   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : StartSummon  '  & @CRLF )
   StartSummon($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ScrollDown  '  & @CRLF )
   ScrollDown($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ScrollDown  '  & @CRLF )
   ScrollDown($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : SingleSummon  '  & @CRLF )
   SingleSummon($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmSummon  '  & @CRLF )
   ConfirmSummon($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Pull '  & @CRLF )
   Pull($t)
   For $i = 1 To 9
	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickScreen  '  & @CRLF )
	  ClickScreen(1000)
	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickAgain  '  & @CRLF )
	  ClickAgain($t)
   Next
	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickAgain  '  & @CRLF )
	  ClickAgain($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : SummonReward  '  & @CRLF )
   ;SummonReward($t)

 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : StartSummon  '  & @CRLF )
 ;  StartSummon($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ScrollDown  '  & @CRLF )
 ;  ScrollDown($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : SingleSummon  '  & @CRLF )
 ;  SingleSummon($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ConfirmSummon  '  & @CRLF )
 ;  ConfirmSummon($t)
 ;  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Pull '  & @CRLF )
 ;  Pull($t)
 ;  For $i = 1 To 7
;ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickScreen  '  & @CRLF )
;	  ClickScreen($t)
;	  ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ClickAgain  '  & @CRLF )
;	  ClickAgain($t)
 ;  Next
  ; ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : SummonReward  '  & @CRLF )
  ; Sleep(1000)
   ;SummonReward($t)

   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : OpenTeam  '  & @CRLF )
   OpenTeam($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : ViewChars  '  & @CRLF )
   ViewChars($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : CharScreenShot  '  & @CRLF )
   CharScreenShot(5000)

   WinActivate($Droid4X)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : OpenMenu  '  & @CRLF )
   OpenMenu($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : BackupCode  '  & @CRLF )
   BackupCode($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : CreateCode  '  & @CRLF )
   CreateCode($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : CreateCodeOK  '  & @CRLF )
   CreateCodeOK($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : CodeScreenShot  '  & @CRLF )
   CodeScreenShot($t)

   CloseGame(2000)
   StartGame($t)
   ControlMove( $Droid4X,"","", 0, 0)
EndFunc
Func CloseGame($t)
   WinClose($Droid4X)
   WinWaitClose($Droid4X)
   Sleep($t)
EndFunc
Func StartGame($t)
   Run("C:\Program Files (x86)\Droid4X\Droid4X.exe")
   WinWaitActive($Droid4X)
   Sleep($t)
EndFunc
Func FindXStart($Y=80, $Color="0xEE0000")
   $Searching = True
   $X = 0
   While($Searching)
	  $FoundColor = PixelGetColor( $X, $Y, $hwnd )
	  If($Color=$FoundColor)Then
		 $Searching = False
	  EndIf
	  $X += 1
   Wend
   return $X - 250
EndFunc
Func Prep($t)
   ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : Started  '& $D4XMenu  & @CRLF )
   $hwnd = WinActivate( $Droid4X )
   $dll = DllOpen("user32.dll") ; Read somewhere thats User32.ddl speeds up _IsPressed detection?
   Sleep($t)
EndFunc
Func Pull($t)
   SearchColor(360, 590, 385, 615, "0xF7ECDE")
   Sleep(500)
   WinActivate($Droid4X)
   MouseMove( 340 * $XR, 625 * $YR )
   MouseDown( "left" )
   MouseMove( 340 * $XR, 900 * $YR )
   MouseUp( "left" )
   Sleep($t * 3)
EndFunc
Func ConfirmRecieved($t)
   SearchColor(250, 700, 440, 740, "0xF3B36A")
   ClickAt(300, 710 )
   Sleep($t)
EndFunc
Func ConfirmKorinReward($t)
   SearchColor(375, 800, 575, 840, "0xF5B466")
   ClickAt(470, 820 )
   Sleep($t)
EndFunc
Func ClaimReward($t)
   SearchColor(480, 370, 570, 410, "0xFF5253")
   ClickAt(530, 390 )
   Sleep($t)
EndFunc
Func ClickKorinMission($t)
   SearchColor(300, 210, 340, 240, "0xC62228")
   ClickAt(200, 375 )
   Sleep($t)
EndFunc
Func ClickMission($t)
   SearchColor(540, 530, 620, 580, "0x02CC33")
   ClickAt(575, 550 )
   Sleep($t)
EndFunc
Func ClickZHome($t)
   SearchColor(310, 975, 340, 995, "0xFF4872")
   ClickAt(120, 985 )
   Sleep($t)
EndFunc
Func DownloadComplete($t)
   ClickAt(514, 601 )
   Sleep($t)
EndFunc
Func CodeScreenShot($t)
   _ScreenCapture_Capture(@MyDocumentsDir & "\" & @HOUR & @MIN & @SEC & ".jpg", 0 , 0 , 640, 1040)
   ;SearchColor(125, 735, 310, 785, "0xF7B46D")
   ;ClickAtMenu( 35, 70 )
   ;Sleep($t * 2)
   ;ClickAtMenu( 180, 75 )
   Sleep($t * 5)
EndFunc
Func CreateCodeOK($t)
   SearchColor(240, 735, 440, 770, "0xF3B16D")
   ClickAt(340, 750 )
   Sleep($t)
EndFunc
Func CreateCode($t)
   SearchColor(150, 850, 210, 895, "0xAAC480")
   ClickAt(340, 385 )
   Sleep($t)
EndFunc
Func BackupCode($t)
   If(CheckColor(135, 360, 175, 405, "0x3A383A")) Then
   Else
	  OpenMenu($t)
   EndIf
   SearchColor(135, 360, 175, 405, "0x3A383A")
   ClickAt(340, 385 )
   Sleep($t * 2)
EndFunc
Func UnlockSlotOK($t)
   SearchColor(250, 700, 440, 740, "0xF5B36F")
   ClickAt(350, 720 )
   Sleep($t)
EndFunc
Func UnlockSlot($t)
   SearchColor(370, 680, 560, 720, "0xF8B26A")
   ClickAt(460, 700 )
   Sleep($t)
EndFunc
Func ExpandShop($t)
   NowLoading($t)
   SearchColor(280, 605, 330, 640, "0x664667")
   ClickAt(345, 580 )
   Sleep($t)
EndFunc
Func ExchangeComplete($t)
   SearchColor(240, 585, 435, 630, "0xF5B36F")
   ClickAt(340, 605 )
   Sleep($t)
EndFunc
Func ConfirmSale2($t)
   SearchColor(370, 745, 560, 790, "0xEEB370")
   ClickAt(470, 770 )
   Sleep($t)
EndFunc
Func ConfirmSale($t)
   SearchColor(470, 750, 600, 800, "0xFF4B50")
   ClickAt(470, 765 )
   Sleep($t)
EndFunc
Func SelectAwaken($t)
   SearchColor(85, 370, 150, 440, "0x514F4E")
   ClickAt(265, 400 )
   Sleep($t)
EndFunc
Func AwakenPoints($t)
   SearchColor(80, 840, 215, 900, "0xB0C483")
   ClickAt(340, 600 )
   Sleep($t)
EndFunc
Func AddTradePoints($t)
   SearchColor(550, 190, 600, 225, "0xCEDDAA")
   ClickAt(575, 210 )
   Sleep($t)
EndFunc
Func BabaShop($t)
   NowLoading($t)
   SearchColor(450, 750, 610, 860, "0xAF62C8")
   ClickAt(520, 800 )
   Sleep($t)
EndFunc
Func TradePoints($t)
   SearchColor(550, 190, 600, 230, "0x8839A6")
   ClickAt(580, 210 )
   Sleep($t)
EndFunc
Func OpenStore($t)
   SearchColor(310, 975, 340, 995, "0xFF4872")
   ClickAt(460, 990 )
   Sleep($t)
EndFunc
Func OpenMenu($t)
   SearchColor(310, 975, 340, 995, "0xFF4872")
   ClickAt(570, 990 )
   Sleep($t)
EndFunc
Func CharScreenShot($t)
   _ScreenCapture_Capture(@MyDocumentsDir & "\" & @HOUR & @MIN & @SEC & ".jpg", 0 , 0 , 640, 1040)
   ;SearchColor(475, 840, 600, 890, "0xD8D481")
  ; ClickAtMenu( 35, 70 )
  ; Sleep($t * 2)
  ; ClickAtMenu( 180, 75 )
   Sleep($t * 3 )
EndFunc
Func ViewChars($t)
   SearchColor(440, 490, 520, 510, "0x353535")
   ClickAt(490, 480 )
   Sleep($t)
EndFunc
Func OpenTeam($t)
   SearchColor(310, 975, 340, 995, "0xFF4872")
   ClickAt(230, 990 )
   Sleep($t)
EndFunc
Func DokkanSingleSummon($t)
   SearchColor(220, 765, 315, 780, "0xFFFE41")
   ClickAt(260, 760 )
   Sleep($t)
EndFunc
Func DokkanFestSummon($t)
   SearchColor(225, 705, 300, 715, "0xFFFD45")
   ClickAt(260, 690 )
   Sleep($t)
EndFunc
Func SummonReward($t)
   SearchColor(310, 680, 500, 720, "0xF8AF72")
   ClickAt( 405, 700 )
   Sleep($t)
EndFunc
Func AcceptReward($t)
   SearchColor(240, 760, 440, 800, "0xF8AF72")
   ClickAt( 340, 785 )
   Sleep($t)
EndFunc
Func ClickAgain($t)
   SearchColor(100, 760, 180, 790, "0x006939")
   ClickAt(405, 785 )
   Sleep($t)
EndFunc
Func ConfirmSummon($t)
   SearchColor(360, 675, 555, 710, "0xF5B26D")
   ClickAt(470, 700 )
   Sleep($t)
EndFunc
Func SingleSummon($t)
   SearchColor(500, 540, 550, 600, "0xEE4400")
   ClickAt(400, 690 )
   Sleep($t)
EndFunc
Func ScrollDown($t)
   Sleep($t)
   ClickAt(345, 880 )
   Sleep($t * 2)
EndFunc
Func StartSummon($t)
   SearchColor(310, 975, 340, 995, "0xFF4872")
   ClickAt(340, 985 )
   Sleep($t)
EndFunc
Func AcceptAllOK2($t)
   SearchColor(250, 815, 440, 850, "0xF6B26F")
   ClickAt(340, 830 )
   Sleep($t)
EndFunc
Func AcceptAllOK($t)
   SearchColor(370, 650, 560, 685, "0xF6B26F")
   ClickAt(470, 670 )
   Sleep($t)
EndFunc
Func AcceptAll($t)
   SearchColor(525, 160, 610, 195, "0xDBCF88")
   ClickAt(575, 180 )
   Sleep($t)
EndFunc
Func OpenGifts($t)
   NowLoading($t)
   SearchColor(540, 685, 570, 715, "0xC62127")
   ClickAt(520, 725 )
   Sleep($t)
EndFunc
Func ClickRecruitOK($t)
   SearchColor(250, 950, 450, 985, "0xF7B272")
   ClickAt(340, 965 )
   Sleep($t * 1)
EndFunc
Func ClickBannerClose($t)
   SearchColor(370, 820, 560, 855, "0xF1B170")
   ClickAt(470, 840 )
   Sleep($t * 2)
EndFunc
Func ClickSummonClose($t)
   SearchColor(250, 775, 435, 815, "0xF7B26F")
   ClickAt(340, 800 )
   Sleep($t * 2)
EndFunc
Func ClickOKGifts($t)
   NowLoading($t)
   SearchColor(260, 725, 445, 750, "0xF8B369")
   ClickAt(340, 745 )
   Sleep($t * 2)
EndFunc
Func ClickClose($t)
   NowLoading($t)
   SearchColor(250, 950, 440, 985, "0xF4B36B")
   Sleep($t * 3)
   ClickAt(340, 975 )
   Sleep($t * 2)
EndFunc
Func ClickOK($t)
   SearchColor(250, 590, 440, 625, "0xF5B26F")
   ClickAt(340, 600 )
   Sleep($t)
EndFunc
Func ClickSkip($t=1000)
   SearchColor(520, 75, 610, 120, "0xDFDFDF")
   ClickAt(560, 100 )
   Sleep($t)
EndFunc
Func ClickScreen($t)
   ControlClick($Droid4X ,$D4XWindowText, "","left", 1 )
   Sleep($t)
EndFunc
Func StartDokkan($t)
   SearchColor(460, 640, 515, 660, "0xCC0011")
   ClickAt(400, 540 )
   Sleep($t)
EndFunc
Func ClickHercule($t)
   SearchColor(330, 900, 380, 940, "0x7D3330")
   Sleep($t)
   ClickAt(400, 540 )
   Sleep($t)
EndFunc
Func DokkanReroll($t)
   ClickAt(400, 210 )
   Sleep($t)
EndFunc
Func ClickHome($t)
   SearchColor(140, 175, 200, 240, "0xFEE45B")
   ClickAtMenu( 35 , 950 )
   Sleep($t)
EndFunc
Func ClickBack($t)
   ClickAtMenu( 35, 890 )
   Sleep($t)
EndFunc
Func NowLoading($t)
   $Found = 0
   Sleep($t)
   While(CheckColor(330, 550, 370, 600, "0xF4C18E"))
	  If ($Found = 0 ) Then
		 ConsoleWrite('Loading Screen Detected '  )
	  EndIf
	  $Found = 1
	  Sleep($t & 2)
	  ConsoleWrite('. ' )
   WEnd
	  ConsoleWrite( @CRLF )
EndFunc
Func LookupColor($x, $y, $color)
   $Pixel = 0
   $Counter = 0
	  ConsoleWrite('color: ' & $color & @CRLF )
   While ($Pixel <> $color)
	  $Pixel = PixelGetColor( $x * $XR, $y * $YR, $hwnd )
	  Sleep(1000)
	  ConsoleWrite('Pixel: ' & hex($Pixel) & ' x: ' & $x & ' y: ' & $y  & @CRLF )
	  $Counter += 1
	  If ( $Counter > 60 ) Then
		 $Pixel = $color
	  EndIf
   Wend
EndFunc
Func ClickAtMenu($X, $Y)
   ControlClick($Droid4X ,$D4XMenuText, "","left", 1, $X * $XR, $Y * $YR )
EndFunc
Func ClickAt($X, $Y)
   ControlClick($Droid4X ,$D4XWindowText, "","left", 1, $X * $XR, $Y * $YR )
EndFunc
Func SearchColor($l, $t, $r, $b,  $color)
   $Pixel = 0
   $Counter = 0
	  ConsoleWrite('color: ' & $color & ' l: ' & $l & ' t: ' & $t & ' b: ' & $b & ' r: ' & $r & @CRLF )
   While ($Pixel <> $color)
	  $Search = PixelSearch($l * $XR, $t * $YR, $r * $XR, $b * $YR,$color,1,2, $hwnd)
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
	  $Search = PixelSearch($l * $XR, $t * $YR, $r * $XR, $b * $YR,$color,1,2, $hwnd)
	  If @error <> 0 Then
		  Return False
		 ConsoleWrite('No Loading Screen' & @CRLF )
	  Else
		  Return True
	  EndIf
EndFunc
Func Quit($why = "Hotkey")
	MsgBox(0,"exit","program quit: " & $why)
	Exit
EndFunc
Func Pause()
	Sleep(10000)
EndFunc