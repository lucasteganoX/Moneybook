#!/bin/bash
set -euo pipefail

Logging_Is_Possible() { # synopsis: Logging_Is_Possible # note: It checks everything is set in order to log something. # returns: 0 if everything is fine, 1 if the file doesn't exist, 2 if it is not a regular file, 3 if it's not writable.
		declare -r Log_Directory_Path='/data/data/com.termux/files/usr/var/log'
		declare -r Log_File_Path="${Log_Directory_Path}/moneybook.log"

		if [[ ! -a "$Log_File_Path" ]] ; then return 1 ; fi
		if [[ ! -f "$Log_File_Path" ]] ; then return 2 ; fi
		if [[ ! -w "$Log_File_Path" ]] ; then return 3 ; fi
		return 0
}

Log_Purchase() { # synopsis: Log_Purchase Account_Name Purchase_Cost Purchase_Message # note: write a purchase entry to the log file. It needs the name of the account the purchase was made over, its cost and optionally a message to describe the purchase 
		if [[ ${1+IsSet} != "IsSet" ]] ; then echo "Couldn't log purchase, missing argument: Account of the purchase. Status 1" > /dev/stderr ; return 1 ; fi
		if [[ ${2+IsSet} != "IsSet" ]] ; then echo "Couldn't log purchase, missing argument: Cost of the purchase. Status 2" > /dev/stderr; return 2 ; fi
		if [[ $# -gt 3 ]] ; then echo "Couldn't log purchase, excess of arguments. Status 3" > /dev/stderr ; return 3 ; fi

		declare -r Log_Directory_Path='/data/data/com.termux/files/usr/var/log'
		declare -r Log_File_Path="${Log_Directory_Path}/moneybook.log"
		declare -r Account_Name="$1"
		declare -r +i Purchase_Cost="$2"
		declare -r Purchase_Message="${3-}" # might be empty
		declare -r Purchase_DateTime=$( date '+%a %b %e %Y %H:%Mhs' ) # The datetime might look like `Sat Aug 31 2024 16:20:57`
		declare Purchase_Log_Line # The line that will be written to the log file

		# Sourcing aka Imports
		if ! . ~/moneybook/lib/Account_Methods.bash
		then
				echo "Logging_methods: Couldn't log purchase, couldn't source \`~/moneybook/lib/Account_Methods\`. Status 4"
				return 4
		fi

		# Argument checks
		if [[ ! "$Purchase_Cost" =~ ^[0-9]+$ ]] ; then echo "Couldn't log purchase, the Cost argument is not a (positive) integer. Status 5" > /dev/stderr ; return 5 ; fi
		if ! File_Is_Account ~/moneybook/${Account_Name} ; then "Couldn't log purchase, the specified Account name couldn't be tracked to an Account File of the same name. Status 6" > /dev/stderr ; return 6 ; fi
		
		# Log file check
		Logging_Is_Possible # Should return 0
		case $? in
		1) echo "Couldn't log purchase, log file \`${Log_File_Path}\` doesn't exist. Status 7" > /dev/stderr ; return 7 ;;
		2) echo "Couldn't log purchase, log file \`${Log_File_Path}\` is not a regular file. Status 8" > /dev/stderr ; return 8 ;;
		3) echo "Couldn't log purchase, log file \`${Log_File_Path}\` is not writable. Status 9" > /dev/stderr ; return 9
		esac

		# Logging the purchase
		Purchase_Log_Line=" [Purchase] ${Purchase_DateTime}, over the Account \`${Account_Name}\` with a cost of \`${Purchase_Cost}\`"
		if [[ "$Purchase_Message" != "" ]] ; then Purchase_Log_Line+=": ${Purchase_Message}" ; fi
		echo "$Purchase_Log_Line" >> "$Log_File_Path"
		return 0
}