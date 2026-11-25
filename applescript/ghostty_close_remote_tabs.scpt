#!/usr/bin/osascript

on run
	tell application "Ghostty"
		set win to front window
		set ctab_id to id of selected tab of win
		set win_tabs to tabs of win
		repeat with t in win_tabs
			set tab_id to id of t

			# do not close the current tab
			if tab_id is not equal to ctab_id
				set term to focused terminal of t
				focus term

				# disconnect from tmux
				send key "space" modifiers "control" to term
				send key "d" to term

				# wait for remote fish shell prompt backgrounded task
				delay 0.75

				# kill remote fish shell
				send key "d" modifiers "control" to term

				# wait for local fish shell prompt backgrounded task
				delay 0.75

				# close tab
				send key "w" modifiers "command" to term
			end if
		end repeat
	end tell
end run
