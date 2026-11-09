-- Toggles NordVPN Meshnet off and back on through the app's UI.
-- Needs Accessibility for whatever runs osascript. Leaves Meshnet alone if it
-- is already off, so a deliberate "off" is never overridden.

on findById(theId)
	tell application "System Events" to tell process "NordVPN"
		if (count of windows) is 0 then return missing value
		set ec to entire contents of window 1
		repeat with i from 1 to (count of ec)
			set e to item i of ec
			try
				if value of attribute "AXIdentifier" of e is theId then return e
			end try
		end repeat
	end tell
	return missing value
end findById

on waitForValue(sw, wanted)
	repeat 40 times
		tell application "System Events"
			if (value of sw as integer) is wanted then return true
		end tell
		delay 0.25
	end repeat
	return false
end waitForValue

-- Posts a macOS notification either way, so a toggle (or a failed one) is
-- never silent.
on run
	try
		set msg to my toggle()
	on error errMsg
		display notification errMsg with title "Meshnet toggle failed"
		error errMsg
	end try
	if msg is not "" then display notification msg with title "Meshnet watchdog"
	return msg
end run

on toggle()
	tell application "System Events"
		set prevApp to name of first process whose frontmost is true
		set hadWindow to (count of windows of process "NordVPN") > 0
	end tell

	-- The deeplink does not reopen a closed window, but a plain reopen does.
	if not hadWindow then
		do shell script "open -a NordVPN"
		repeat 20 times
			tell application "System Events" to if (count of windows of process "NordVPN") > 0 then exit repeat
			delay 0.5
		end repeat
	end if
	-- Shows the Meshnet page. Clicking the sidebar item via System Events does
	-- not navigate, so don't bother with that.
	do shell script "open nordvpn://meshnet"
	set sw to missing value
	repeat 20 times
		set sw to my findById("meshnetToggle")
		if sw is not missing value then exit repeat
		delay 0.5
	end repeat
	if sw is missing value then error "Meshnet switch not found in the NordVPN window"

	tell application "System Events" to set isOn to (value of sw as integer) is 1
	if isOn then
		tell application "System Events" to perform action "AXPress" of sw
		if not my waitForValue(sw, 0) then error "Meshnet did not turn off"
		delay 3
		tell application "System Events" to perform action "AXPress" of sw
		if not my waitForValue(sw, 1) then error "Meshnet did not turn back on"
	end if

	-- The window is left open on purpose, as a sign that a toggle happened.
	tell application "System Events" to set frontmost of process prevApp to true
	if isOn then return "Meshnet toggled off and on"
	return "Meshnet is off; leaving it off"
end toggle
