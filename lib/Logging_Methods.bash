#!/bin/bash
# set -euo pipefail

Logging_Is_Possible() { # synopsis: Logging_Is_Possible # note: It checks everything is set in order to log something. # returns: 0 if everything is fine, 1 if the file doesn't exist, 2 if it is not a regular file, 3 if it's not writable.
		declare -r Log_Directory_Path='/data/data/com.termux/files/usr/var/log'
		declare -r Log_File_Path="${Log_Directory_Path}/moneybook.log"

		if [[ ! -a "$Log_File_Path" ]] ; then return 1 ; fi
		if [[ ! -f "$Log_File_Path" ]] ; then return 2 ; fi
		if [[ ! -w "$Log_File_Path" ]] ; then return 3 ; fi
		return 0
}

Log_Purchase() { # synopsis: Log_Purchase Account_Name Purchase_Cost Purchase_Message Moment_Of_Monetary_Change # note: write a purchase entry to the log file. It needs the name of the account the purchase was made over, its cost and optionally a message to describe the purchase. Update: Now you can supply the moment in which the money was moved as separate from the moment in which the event is recorded. 
		if [[ ${1+IsSet} != "IsSet" ]] ; then echo "Couldn't log purchase, missing argument: Account of the purchase. Status 1" > /dev/stderr ; return 1 ; fi
		if [[ ${2+IsSet} != "IsSet" ]] ; then echo "Couldn't log purchase, missing argument: Cost of the purchase. Status 2" > /dev/stderr; return 2 ; fi
		if [[ $# -gt 4 ]] ; then echo "Couldn't log purchase, excess of arguments. Status 3" > /dev/stderr ; return 3 ; fi

		declare -r Log_Directory_Path='/data/data/com.termux/files/usr/var/log'
		declare -r Log_File_Path="${Log_Directory_Path}/moneybook.log"
		declare -r Account_Name="$1"
		declare -r +i Purchase_Cost="$2"
		declare -r Purchase_Message="${3-}" # might be empty
		declare -r Monetary_Change_DateTime="${4-}" # might be empty
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

		if [[ "$Monetary_Change_DateTime" != '' ]]
		then
				# Monetary change datetime check
				declare +r 24_Hour_Regex='([0-1]?[0-9]|2[0-4]):[0-5][0-9]'
				declare +r Monetary_DateTime_Format_Regex="^(Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) ([0-2][0-9]|3[0-1]) [1-2][0-9][0-9][0-9] (${24_Hour_Regex}|N/A)hs$"
				if [[ "$Monetary_Change_DateTime" != '' && "$Monetary_Change_DateTime" =~ $Monetary_DateTime_Format_Regex ]] ; then echo "Couldn't log purchase, the moment of monetary change couldn't be parsed as such. Status 10" ; return 10 ; fi
				unset Monetary_DateTime_Format_Regex
				unset 24_Hour_Regex
		fi

		# Logging the purchase
		Purchase_Log_Line=" [Purchase] ${Purchase_DateTime}, over the Account \`${Account_Name}\` with a cost of \`${Purchase_Cost}\`"
		if [[ "$Purchase_Message" != "" ]] ; then Purchase_Log_Line+=": ${Purchase_Message}" ; fi
		echo "$Purchase_Log_Line" >> "$Log_File_Path"
		return 0
}

Log_Injection() { 
# Synopsis: Log_Injection <+Int>InjectedMoney <IndexedArray>AccountStates [<String(No_Escape_Interpretation)>Log_Message]
# Note:	 Each element of the indexed array represents the state of an account
#		   and is parsed as follows: AccountName//<Int>AccountPreviousFunds//<Int>AccountNewFunds
#		   For example: savings//1234//2435
#		   Which reads that the account `savings` previously had a balance of `1234` *money* and now ot has `2435` *money*
#		   When invoking the function, simply expand the array as this: "${Accounts[@]}"
#		   Which could expand for example to: "savings//1234//2435 allowance//5450//10000 selfinvestment//3000//6000"		   
		Parameter_Is_Account_Object() {
				declare -r Correct_Object_Syntax='^.+//[0-9]+//[0-9]+$'
				declare -r Account_Object="$1"

				[[ "$Account_Object" =~ $Correct_Object_Syntax ]]
				return # This will return the result of the previous expression
		}

		if [[ ${1+IsSet} != 'IsSet' ]] ; then echo "Couldn't log injection, missing argument: amount of injected money. Status 1" > /dev/stderr ; return 1 ; fi
		if ! [[ "$1" =~ ^[0-9]+$ ]] ; then echo "Couldn't log injection, couldn't parse the first argument as a positive, integer, amount of money. Status 2" > /dev/stderr ; return 2 ; fi
		if [[ $# -lt 2 ]] ; then echo "Couldn't log injection, not enough parameters were given. Status 3" > /dev/stderr ; return 3 ; fi
		if [[ "$1" -eq 0 ]] ; then "Couldn't log injection, the injection amount was given a value of 0. Status 4" > /dev/stderr ; return 4 ; fi

		# Account objects format check
		for Parameter in "${@:2}"
		do
				if ! Parameter_Is_Account_Object "$Parameter" 
				then
						if [[ "$Parameter" = "${@: -1}" ]]
						then
								# This means the last parameter is the
								# log message, and not an Account Object
								continue
						fi
						echo "Couldn't log injection, the argument \`${Parameter}\` couldn't be parsed as an Account Object. Status 5" > /dev/stderr
						return 5
				fi
		done

		# Sourcing aka Imports
		if ! . ~/moneybook/lib/Account_Methods.bash
		then
				echo "Logging_methods: Couldn't log purchase, couldn't source \`~/moneybook/lib/Account_Methods\`. Status 6"
				return 6
		fi

		declare -r Log_Directory_Path='/data/data/com.termux/files/usr/var/log'
		declare -r Log_File_Path="${Log_Directory_Path}/moneybook.log"
		declare -r -i Injection_Value="$1"
		if ! Parameter_Is_Account_Object "${@: -1}"
		then
				declare -r Log_Message="${@: -1}"
				declare -r -a Account_Objects=( "${@:2:$#-2}" )
		else
				declare -r Log_Message=''
				declare -r -a Account_Objects=( "${@:2}" )
				
		fi # This correctly handles both not passing the message argument, and passing an empty string instrad.
		declare -r Injection_DateTime="$( date '+%a %b %e %Y %H:%Mhs' )" # The datetime might look like `Sat Aug 31 2024 16:20:57`

		# Log file check
		Logging_Is_Possible
		Check_Exit_Status=$?
		Return_Value_Perhaps=$(( 6 + Check_Exit_Status )) # '6' is the last error code, this way the lowest possible error code would be '7'.
		case $Check_Exit_Status in
		0) ;;
		1) echo "Couldn't log injection, log file doesn't exist. Status ${Return_Value_Perhaps}" > /dev/stderr ; return $Return_Value_Perhaps ;;
		2) echo "Couldn't log injection, log file is not a regular file. Status ${Return_Value_Perhaps}" > /dev/stderr ; return $Return_Value_Perhaps ;;
		3) echo "Couldn't log injection, log file is not writable. Status ${Return_Value_Perhaps}" > /dev/stderr ; return $Return_Value_Perhaps ;;
		*) echo "Couldn't log injection, an unexpected error occurred while making sure everything is fine with the log file, aborting." > /dev/stderr ; return $Return_Value_Perhaps ;;
		esac
		unset Check_Exit_Status
		unset Return_Value_Perhaps

		# Accounts exist check
		for Account_Object in "${Account_Objects[@]}"
		do
				declare Account_Name="$( echo "$Account_Object" | sed 's|//.*$||' )"
				declare Account_File_Path="${HOME}/moneybook/${Account_Name}"
				if ! File_Is_Account "$Account_File_Path"
				then
						echo "Couldn't log injection, failed Account file check over \`${Account_File_Path}\`. Status 10" > /dev/stderr
						return 10
				fi
		done
		unset Account_Name
		unset Account_File_Path

		# Logging the purchase
		declare Injection_Log_Line
		Injection_Log_Line=" [Injection] ${Injection_DateTime}, with a value of \`${Injection_Value}\` *money*; "
		
		## Record the state of the accounts in the log line
		for Account_Object in "${Account_Objects[@]}"
		do
				declare Account_Name="$(
					echo "$Account_Object" |
					sed 's|//.*$||'
				)"
				declare Account_Old_Balance="$(
					echo "$Account_Object" |
					sed -e 's|^[^/]*//||' -e 's|//.*$||'
				)"
				declare Account_New_Balance="$(
					echo "$Account_Object" |
					sed -e 's|^.*//||' -e 's|//.*$||'
				)"

				Injection_Log_Line+="\`${Account_Name}\`( \`${Account_Old_Balance}\` > \`${Account_New_Balance}\`)"
				if [[ "$Account_Object" != "${Account_Objects[-1]}" ]] ; then Injection_Log_Line+=', ' ; fi
		done
		if [[ "$Log_Message" != '' ]] ; then Injection_Log_Line+=": ${Log_Message}" ; fi
		# At this point the log line might look like: [Injection] Sun Sep 4 2026 13:36hs, with a value of `21000` *money*; `savings`( `9000` > `12321` ), `allowance`( `2345` > `32123` ), `selfinvestment`( `10000` > `20000` )
		unset Account_Name Account_Old_Balance Account_New_Balance

		## Write the line to the log
		echo "$Injection_Log_Line" >> "$Log_File_Path"
		unset Injection_Log_Line
		return 0
}