; -----------------------------------------------------------------------------------------
; Clicker Heroes Sw1ft Bot
; by Sw1ftb
; -----------------------------------------------------------------------------------------

#Persistent
#NoEnv
#InstallKeybdHook

#Include %A_ScriptDir%
#Include ch_bot_lib.ahk
SetWorkingDir %A_ScriptDir%

SetControlDelay, -1

scriptName=CH Troggobot (based on Sw1ft bot)
scriptVersion=2.41
minLibVersion=1.32
heroConfig := []

script := scriptName . " v" . scriptVersion

scheduleReload := false
scheduleStop := false

endRound := false
currentRoundTime := 0

; -----------------------------------------------------------------------------------------

; Load user settings
#Include *i ch_bot_settings.ahk

if (libVersion != minLibVersion) {
	showWarningSplash("The bot lib version must be " . minLibVersion . "!")
	ExitApp
}

if (useConfigurationAssistant) {
	configurationAssistant()
}
	
clientCheck()

Run, monster_clicker.ahk,, UseErrorLevel
if (ErrorLevel != 0) {
	playWarningSound()
    msgbox,,% script,% "Failed to auto-start monster_clicker.ahk (system error code = " . A_LastError . ")!"
}

handleAutorun()

; -----------------------------------------------------------------------------------------
; -- Hotkeys (+=Shift, !=Alt, ^=Ctrl)
; -----------------------------------------------------------------------------------------

; Suspend/Unsuspend all other Hotkeys
^Esc::Suspend, Toggle
return

; Show the cursor position with Alt+Middle Mouse Button
!mbutton::
	mousegetpos, xpos, ypos
	msgbox,,% script,% "Cursor position: x" xpos-leftMarginOffset " y" ypos-topMarginOffset
return

; Pause/Unpause script
Pause::
Pause
scrollToBottom()
return

; Abort speed/deep runs and auto ascensions with Alt+Pause
!Pause::
	showSplashAlways("Aborting...")
	monsterClickerOff()
	exitThread := true
	exitDRThread := true
return

+^k:: 
	updateBuyColor()
return

+^up::
	currentRoundTime := currentRoundTime + roundModifier
return

+^down::
	newRoundTime := currentRoundTime - roundModifier
	if (newRoundTime > 0) {
		currentRoundTime := newRoundTime
	} else {
		showSplashAlways("Cannot decrease round time below 0")
	}
return

; Quick tests:
; Ctrl+Alt+F1 should scroll down to the bottom
; Ctrl+Alt+F2 should switch to the relics tab and then back

^!F1::
	scrollToBottom()
return

^!F2::
	switchToRelicTab()
	switchToCombatTab()
return

; Alt+F1 to F4 are here to test the individual parts of the full speed run loop

!F1::
	getClickable()
return

!F2::
	initRun()
return

!F3::
	switchToCombatTab()
	speedRun()
return

!F4::
	ascend(autoAscend)
return

; Reload script with Alt+F5
!F5::
	global scheduleReload := true
	handleScheduledReload()
return

; Speed run loop
^F1::
	loopSpeedRun()
return

; Stop looping when current speed run finishes with Shift+Pause
+Pause::
	toggleFlag("scheduleStop", scheduleStop)
return	

; Autosave the game
^F11::
	critical
	monsterClickerTogglePause()
	save()
return

; Toggle boolean (true/false) flags

+^F1::
	toggleFlag("autoAscend", autoAscend)
return

+^F2::
	toggleFlag("screenShotRelics", screenShotRelics)
return

+^F5::
	toggleFlag("scheduleReload", scheduleReload)
return

+^F6::
	toggleFlag("playNotificationSounds", playNotificationSounds)
return

+^F7::
	toggleFlag("playWarningSounds", playWarningSounds)
return

+^F8::
	toggleFlag("showSplashTexts", showSplashTexts)
return

+^F11::
	toggleFlag("saveBeforeAscending", saveBeforeAscending)
return

+^F12::
	toggleFlag("debug", debug)
return

; -----------------------------------------------------------------------------------------
; -- Functions
; -----------------------------------------------------------------------------------------

; Automatically configure initDownClicks and yLvlInit settings.
configurationAssistant() {
	global

	if (irisLevel < 145) {
		playWarningSound()
		msgbox,,% script,% "Your Iris do not fulfill the minimum level requirement of 145 or higher!"
		exit
	}

	if (irisThreshold(2010)) { ; Astraea
		initDownClicks := [6,5,6,5,6,3]
		yLvlInit := 241
	} else if (irisThreshold(1760)) { ; Alabaster
		; [6,6,6,5,6,3], 227
		; [6,5,6,6,6,3], 260
		; [5,6,6,5,6,3], 293
		initDownClicks := [6,6,6,5,6,3]
		yLvlInit := 227
	} else if (irisThreshold(1510)) { ; Cadmia
		initDownClicks := [6,6,6,6,6,3]
		yLvlInit := 240
	} else if (irisThreshold(1260)) { ; Lilin
		initDownClicks := [6,6,6,6,6,3]
		yLvlInit := 285
	} else if (irisThreshold(1010)) { ; Banana
		initDownClicks := [6,7,6,7,6,3]
		yLvlInit := 240
	} else if (irisThreshold(760)) { ; Phthalo
		initDownClicks := [6,7,7,6,7,3]
		yLvlInit := 273
	} else if (irisThreshold(510)) { ; Terra
		initDownClicks := [7,7,7,7,7,3]
		yLvlInit := 240
	} else if (irisThreshold(260)) { ; Atlas
		initDownClicks := [7,7,7,8,7,3]
		yLvlInit := 273
	} else { ; Dread Knight
		initDownClicks := [7,8,7,8,7,4]
		yLvlInit := 257
	}

	if (irisLevel < optimalLevel - 1001) {
		local levels := optimalLevel - 1001 - irisLevel
	}
}

; Check if Iris is within a certain threshold that can cause a toggling behaviour between different settings
irisThreshold(lvl) {
	global
	return irisLevel > lvl 
}

; Level up and upgrade all heroes
initRun() {
	global

	switchToCombatTab()
	clickPos(xHero, yHero) ; prevent fails

	upgrade(initDownClicks[1],2,,2) ; cid --> brittany
	upgrade(initDownClicks[2]) ; fisherman --> leon
	upgrade(initDownClicks[3]) ; seer --> mercedes
	upgrade(initDownClicks[4],,,,2) ; bobby --> king
	upgrade(initDownClicks[5],2,,,2) ; ice --> amenhotep
	upgrade(initDownClicks[6],,,2) ; beastlord --> shinatobe
	upgrade(0,,,,,true) ; grant & frostleaf

	scrollToBottom()
	buyAvailableUpgrades()
}

upgrade(times, cc1:=1, cc2:=1, cc3:=1, cc4:=1, skip:=false) {
	global

	if (!skip) {
		ctrlClick(xLvl, yLvlInit, cc1)
		ctrlClick(xLvl, yLvlInit + oLvl, cc2)
	}
	ctrlClick(xLvl, yLvlInit + oLvl*2, cc3)
	ctrlClick(xLvl, yLvlInit + oLvl*3, cc4)

	scrollDown(times)
}

loopSpeedRun() {
	global

	showDebug()
	DebugAppend("Starting speed runs")
	monsterClickerOn()
	monsterClickerTogglePause() ; pause
	
	loop
	{
		getClickable()
		sleep % coinPickUpDelay * 1000
		initRun()
		activateSkills(speedRunStartCombo[2])
		
		speedRun()

		if (saveBeforeAscending) {
			save()
		}
		ascend(autoAscend)
		handleScheduledStop()
		handleScheduledReload(true)
	}
}

speedRun() {
	global

	DebugAppend("Starting new speed run`r`n")
	
	switchToCombatTab()
	scrollToBottom()
	
	toggleMode() ; toggle to progression mode
	
	local i := duration * 60 ; seconds to run after we reach gilded ranger
	local t := 0 ; total time
	local heroCount := 0 ; increase when switching to next ranger
	local y := yLvl + oLvl * (2 - 1) ; 2 is second button
	local d := 0 ; duration on one hero
	
	DebugAppend("duration = " duration ", heroCounter = " heroCounter)
	
	monsterClickerTogglePause() ; resume
	while ( i > 0 || heroCount <> heroCounter){

		if (herCount <> heroCounter && d >= 900) { ; if we are not at last hero and spent more than 15 minutes we force move to next one
			heroCount := heroCount + 1
			d := 0
			monsterClickerTogglePause()
			scrollToTop()
			scrollToBottom()
			monsterClickerTogglePause()
		}

		if (mod(t, lvlUpDelay) = 0) {
			monsterClickerTogglePause()
			
			maxClick(xLvl, y)
			if (heroCount <> heroCounter && isBuyVisible() = 0) {
				heroCount := heroCount + 1
				if (heroCount = heroCounter) {
					DebugAppend("Reached last hero after " d // 60 " minutes")
				} else {
					DebugAppend("Moving to next hero: " heroCount " after " d // 60 " minutes")
				}
				
				d := 0
				scrollToTop() ; in case scroll bar gets bugged
				scrollToBottom()
			}
			
			monsterClickerTogglePause()
		}
		
		if (mod(t, clickableAndUpgradeDelay) = 0) {
		    monsterClickerTogglePause()
			buyAvailableUpgrades()
			
			if (i >= 1500) { ; pick only if more than 25 minutes are left
				getClickable()
			}
			
			monsterClickerTogglePause()
		}
		
		sleep 1000
		t := t + 1
		updateProgress(t)
		if (heroCount = heroCounter) { ; start counting down when we reach last gilded ranger
			i := i - 1
			updateRemaining(i)
		} else {
			d := d + 1 ; time spent on current hero
		}
	}
	
	monsterClickerTogglePause() ; Pause

	DebugAppend("Finished run in " t // 60 " minutes")
}

monsterClickerOn(isActive:=true) {
	global
	send {shift down}{f1 down}{f1 up}{shift up}
}

monsterClickerTogglePause() {
	global
	send {shift down}{f2 down}{f2 up}{shift up}
}

monsterClickerOff() {
	global
	send {shift down}{f3 down}{f3 up}{shift up}
}

save() {
	global
	local fileName := "ch" . A_NowUTC . ".txt"
	local newFileName := ""

	clickPos(xSettings, ySettings)
	sleep % zzz * 3
	clickPos(xSave, ySave)
	sleep % zzz * 4

	; Change the file name...
	if (saveMode = 1) {
		ControlSetText, Edit1, %fileName%, ahk_class %dialogBoxClass%
	} else {
		ControlSend, Edit1, %fileName%, ahk_class %dialogBoxClass%
	}
	sleep % zzz * 4
	; ... and double-check that it's correct
	ControlGetText, newFileName, Edit1, ahk_class %dialogBoxClass%
	if (newFileName = fileName) {
		ControlClick, %saveButtonClassNN%, ahk_class %dialogBoxClass%,,,, NA
	} else {
		ControlSend,, {esc}, ahk_class %dialogBoxClass%
	}

	sleep % zzz * 3
	clickPos(xSettingsClose, ySettingsClose)
}

ascend(autoYes:=false) {
	global
	exitThread := false
	local extraClicks := 6
	local y := yAsc - extraClicks * buttonSize

	if (autoYes) {
		if (autoAscendDelay > 0) {
			showWarningSplash(autoAscendDelay . " seconds till ASCENSION! (Abort with Alt+Pause)", autoAscendDelay)
			if (exitThread) {
				exitThread := false
				showSplashAlways("Ascension aborted!")
				exit
			}
		}
	} else {
		playWarningSound()
		msgbox, 260,% script,Salvage Junk Pile & Ascend? ; default no
		ifmsgbox no
			exit
	}

	salvageJunkPile() ; must salvage junk relics before ascending

	switchToCombatTab()
	scrollDown(ascDownClicks)
	sleep % zzz * 2

	; Scrolling is not an exact science, hence we click above, center and below
	loop % 2 * extraClicks + 1
	{
		clickPos(xAsc, y)
		y += buttonSize
	}
	sleep % zzz * 4
	clickPos(xYes, yYes)
	sleep % zzz * 2
}

salvageJunkPile() {
	global

	switchToRelicTab()

	if (autoAscend) {
		if (screenShotRelics || displayRelicsDuration > 0) {
			clickPos(xRelic, yRelic) ; focus
		}

		if (screenShotRelics) {
			screenShot()
		}

		if (displayRelicsDuration > 0) {
			showWarningSplash("Salvaging junk in " . displayRelicsDuration . " seconds! (Abort with Alt+Pause)", displayRelicsDuration)
			if (exitThread) {
				exitThread := false
				showSplashAlways("Salvage aborted!")
				exit
			}
		}

		if (screenShotRelics || displayRelicsDuration > 0) {
			clickPos(xRelic+100, yRelic) ; remove focus
		}
	}

	clickPos(xSalvageJunk, ySalvageJunk)
	sleep % zzz * 4
	clickPos(xDestroyYes, yDestroyYes)
	sleep % zzz * 2
}

buyAvailableUpgrades() {
	global
	clickPos(xBuy, yBuy)
	sleep % zzz
}

; Toggle between farm and progression modes
toggleMode() {
	global
	ControlSend,, {a down}{a up}, % winName
	sleep % zzz
}

activateSkills(skills) {
	global
	clickPos(xHero, yHero) ; prevent fails
	loop,parse,skills,-
	{
		ControlSend,,% A_LoopField, % winName
		sleep 100
	}
	sleep 1000
}

startMouseMonitoring() {
	setTimer, checkMousePosition, 250
}

stopMouseMonitoring() {
	setTimer, checkMousePosition, off
}

handleScheduledReload(autorun := false) {
	global
	if(scheduleReload) {
		showSplashAlways("Reloading bot...", 1)

		autorun_flag := autorun = true ? "/autorun" : ""
		Run "%A_AhkPath%" /restart "%A_ScriptFullPath%" %autorun_flag%
	}
}

handleScheduledStop() {
	global
	if(scheduleStop) {
		showSplashAlways("Scheduled stop. Exiting...")
		scheduleStop := false
		exit
	}
}

handleAutorun() {
	global
	param_1 = %1%
	if(param_1 = "/autorun") {
		showSplash("Autorun speedruns...", 1)
		loopSpeedrun()
	}
}

loadHeroConfig() {
	global
	FileRead, data, heroconfig.txt
	heroConfig := StrSplit(data, ",")
}

saveHeroConfig() {
	global
	data := ""
	for i, value in heroConfig {
		data := data value ","
	}

	StringTrimRight, data, data, 1
	
	FileDelete, heroconfig.txt
	FileAppend, %data%, heroconfig.txt
}

; -----------------------------------------------------------------------------------------
; -- Subroutines
; -----------------------------------------------------------------------------------------

; Safety zone around the in-game tabs (that triggers an automatic script pause when breached)
checkMousePosition:
	MouseGetPos,,, window
	if (window = WinExist(winName)) {
		WinActivate
		MouseGetPos, x, y

		xL := getAdjustedX(xSafetyZoneL)
		xR := getAdjustedX(xSafetyZoneR)
		yT := getAdjustedY(ySafetyZoneT)
		yB := getAdjustedY(ySafetyZoneB)

		if (x > xL && x < xR && y > yT && y < yB) {
			playNotificationSound()
			msgbox,,% script,Click safety pause engaged. Continue?
		}
	}
return
