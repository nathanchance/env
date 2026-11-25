#!/usr/bin/osascript

on run argv
	set local_remotes to true
	set prepare_only to false
	set default_remotes to true
	repeat with arg in argv
		if arg as text is equal to "-n" or arg as text is equal to "--no-local-remotes" then
			set local_remotes to false
		end if
		if arg as text is equal to "-p" or arg as text is equal to "--prepare-only" then
			set prepare_only to true
		end if
		if arg as text is equal to "-s" or arg as text is equal to "--no-default-remotes" then
			set default_remotes to false
		end if
	end repeat

	tell application "Ghostty"
		set win to front window

		if default_remotes is equal to true
			# Hetzner
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh hetzner" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if

			# OrbStack
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh orb" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if
		end if

		if local_remotes is equal to true
			# Framework Desktop
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh framework-desktop" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if

			# AADP
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh aadp" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if

			# AMD Beelink
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh amd-desktop-8745HS" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if

			# Intel i7-11700
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh intel-desktop-11700" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if

			# Intel laptop
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh intel-laptop" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if

			# Honeycomb
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh honeycomb" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if

			# Beelink N100
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh intel-desktop-n100" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if

			# Chromebox
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh chromebox" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if

			# Mac Studio
			set ntab to new tab in win
			set term to focused terminal of ntab
			input text "msh mac-studio" to term
			if prepare_only is equal to false
				send key "enter" to term
			end if
		end if
	end tell
end run
