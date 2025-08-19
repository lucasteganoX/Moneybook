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
		declare +r Monetary_Change_DateTime="${4-}" # might be empty
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

		# Handle datetime flag
		if [[ "$Monetary_Change_DateTime" != '' ]]
		then
				# Monetary change datetime check
				declare +r TwentyFourHour_Regex='([0-1]?[0-9]|2[0-4]):[0-5][0-9]'
				declare +r Monetary_DateTime_Format_Regex="^(Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) ([0-2][0-9]|3[0-1]) [1-2][0-9][0-9][0-9] (${TwentyFourHour_Regex}|N/A)hs$"
				if ! grep -E "$Monetary_DateTime_Format_Regex" <<< "$Monetary_Change_DateTime" &> /dev/null
				then
						echo "Couldn't log purchase, the moment of monetary change couldn't be parsed as such. Status 10"
						return 10
				fi
				unset Monetary_DateTime_Format_Regex
				unset TwentyFourHour_Regex

				# Monetary change formating
				Monetary_Change_DateTime="(${Monetary_Change_DateTime})"
		fi

		# Logging the purchase
		Purchase_Log_Line=" [Purchase] ${Purchase_DateTime}${Monetary_Change_DateTime}, over the Account \`${Account_Name}\` with a cost of \`${Purchase_Cost}\`"
		if [[ "$Purchase_Message" != "" ]] ; then Purchase_Log_Line+=": ${Purchase_Message}" ; fi
		echo "$Purchase_Log_Line" >> "$Log_File_Path"
		return 0
}

Log_Injection() { 
# Synopsis: Log_Injection <+Int>InjectedMoney <IndexedArray>AccountStates [<String(No_Escape_Interpretation)?>Log_Message] [<DateTime?>Moment_Of_Monetary_Change]
# Note:	 Each element of the indexed array represents the state of an account
#		   and is parsed as follows: AccountName//<Int>AccountPreviousFunds//<Int>AccountNewFunds
#		   For example: savings//1234//2435
#		   Which reads that the account `savings` previously had a balance of `1234` *money* and now ot has `2435` *money*
#		   When invoking the function, simply expand the array as this: "${Accounts[@]}"
#		   Which could expand for example to: "savings//1234//2435 allowance//5450//10000 selfinvestment//3000//6000"
# Note:	 The moment of monetary change means "when did my money change other than the moment I am recording the event into moneybook?".
#		   It must be formated as: %a %b %d %Y %H:%Mhs
#		   Alternatively, the time of day might be replaced with `N/A`...
#		   For example: Mon Jan 27 2025 N/Ahs
# Note: 	You might invoke the function passing an empty string ''(as indicated by the question mark in the synopsis) in the place of either the log message or the moneyary change datetime, or not supply them at all.
#   		Internally, the function gets rid of the empty strings. Don't alter the order tho of those two tho.
		Parameter_Is_Account_Object() {
				declare -r Correct_Object_Syntax='^[^/]+//[0-9]+//[0-9]+$'
				declare -r Account_Object="$1"

				[[ "$Account_Object" =~ $Correct_Object_Syntax ]]
				return # This will return the result of the previous expression
		}

		declare +r Injection_Value
		declare +r -a Account_Objects
		declare +r Log_Message
		declare Monetary_Change_DateTime

		if [[ ${1+IsSet} != 'IsSet' ]] ; then echo "Couldn't log injection, missing argument: amount of injected money. Status 1" > /dev/stderr ; return 1 ; fi
		if ! [[ "$1" =~ ^[0-9]+$ ]] ; then echo "Couldn't log injection, couldn't parse the first argument as a positive, integer, amount of money. Status 2" > /dev/stderr ; return 2 ; fi
		if [[ $# -lt 2 ]] ; then echo "Couldn't log injection, not enough parameters were given. Status 3" > /dev/stderr ; return 3 ; fi
		if [[ "$1" -eq 0 ]] ; then "Couldn't log injection, the injection amount was given a value of 0. Status 4" > /dev/stderr ; return 4 ; fi

		# § Assigning the arguments
		# Note: Just for the record, if I were to completely rework this function(I would like to do so), I would NOT pass the account objects as separate arguments
		# 	  but would instead pass it as a single argument and split it into different account objects using IFS and expanding the array with [*] INSIDE THE FUNCTION.
		#   	That would make it faaaar more simple to assign the arguments, and it would be more elegant. However, that would open the scope considerably, and I
		#   	need to get over this(that is, logging the monetary change moment) asap.

		# Getting rid of empty strings
		# You see... I carried on an important aconception so far. That is if the function were to be invoked with the log message and monetary change datetime
		# as empty strings or without passing them; I always intended to be able to pass an empty string in place of any of those args, but I prepared the func
		# tion to handle solely not passing them. This causes that passing only empty strings breaks the thing.
		# More concretely, invoking the program as `bash moneybook inject 100 'Fake salary'` gets the log message assigned an empty string for the monetary cha
		# nge datetime, that throws the definition of the last account object index off the window, expanding part of the log message and halting the program.
		# For that, the easiest thing is to get rid of the empty string arguments. That way it's like you would have invoked the function without those argumem
		# ents. Both giving support to both manners of invokation, and avoiding me the hassle of re-working the assignment of the arguments.
		declare -a Parameters_Without_Empties
		IFS=$'\t'
		Parameters_Without_Empties=( ${*} )
		for (( Parameter_Index=0 ; Parameter_Index<=$(( ${#Parameters_Without_Empties[@]} - 1 )) ; Parameter_Index++ ))
		do
				if [[ "${Parameters_Without_Empties[$Parameter_Index]}" = '' ]] ; then unset 'Parameters_Without_Empties[$Parameter_Index]' ; fi
		done
		set ${Parameters_Without_Empties[*]} # This re-assigns all the parameters except for the empty strings
		unset IFS

		# Assigning injection value
		Injection_Value="$1"

		# Assigning the injection datetime
		declare -r Injection_DateTime="$( date '+%a %b %e %Y %H:%Mhs' )" # The datetime might look like `Sat Aug 31 2024 16:20:57`

		# Assigning the log file path
		declare +r Log_Directory_Path='/data/data/com.termux/files/usr/var/log'
		declare -r Log_File_Path="${Log_Directory_Path}/moneybook.log"
		unset Log_Directory_Path

		# Assigning the moment of monetary change
		declare +r TwentyFourHour_Regex='([0-1]?[0-9]|2[0-4]):[0-5][0-9]'
		declare +r Monetary_DateTime_Format_Regex="^(Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) ([0-2][0-9]|3[0-1]) [1-2][0-9][0-9][0-9] (${TwentyFourHour_Regex}|N/A)hs$"
		if grep -E "$Monetary_DateTime_Format_Regex" <<< "${@: -1}" &> /dev/null
		then declare Monetary_Change_DateTime="${@: -1}"
		else declare -r Monetary_Change_DateTime=''
		fi
		unset Monetary_DateTime_Format_Regex
		unset TwentyFourHour_Regex

		# Assigning the log message
		declare Log_Message_Index
		if [[ "$Monetary_Change_DateTime" = '' ]]
		then Log_Message_Index=' -1:1'
		else Log_Message_Index=' -2:1' # Second to last argument
		fi

		eval 'declare +r Argument="${@:'"$Log_Message_Index"'}"' # Don't ask me why, but bash cannot handle you passing it a substring expnasion expression as a variable. Thus the use of eval
		if ! Parameter_Is_Account_Object "$Argument"
		then declare -r Log_Message="$Argument"
		else declare -r Log_Message=''
		fi
		unset Log_Message_Index
		unset Argument

		# Assigning account objects
		declare +r -i First_Object_Index=2 # This is for substring substitution; indexes start from 1. And 1 is always for the amount of money
		declare -i Last_Object_Index
		Last_Object_Index="$(( ${#@} - 1 ))"
		if [[ "$Monetary_Change_DateTime" != '' ]] ; then Last_Object_Index=$(( Last_Object_Index - 1 )) ; fi
		if [[ "$Log_Message" != '' ]] ; then Last_Object_Index=$(( Last_Object_Index - 1 )) ; fi
		if [[ "$Last_Object_Index" -lt 1 ]] ; then Last_Object_Index=1 ; fi
		unset IFS
		Account_Objects=( ${@:$First_Object_Index:$Last_Object_Index} )
		unset First_Object_Index
		unset Last_Object_Index

		# Account objects format check
		for Account_Object in ${Account_Objects[@]}
		do
				if ! Parameter_Is_Account_Object "$Account_Object"
				then
						echo "Couldn't log injection, the argument \`${Account_Object}\` couldn't be parsed as an Account Object. Status 5" > /dev/stderr
						return 5
				fi
		done

		# Sourcing aka Imports
		if ! . ~/moneybook/lib/Account_Methods.bash
		then
				echo "Logging_methods: Couldn't log purchase, couldn't source \`~/moneybook/lib/Account_Methods\`. Status 6"
				return 6
		fi

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
		if [[ "$Monetary_Change_DateTime" != '' ]] ; then Monetary_Change_DateTime="(${Monetary_Change_DateTime})" ; fi
		Injection_Log_Line=" [Injection] ${Injection_DateTime}${Monetary_Change_DateTime}, with a value of \`${Injection_Value}\` *money*; "
		
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

Log_Payment() {	
# Synopsis: Log_Payment <String>Expense_Name <IndexedArray>FundsUpdate [<String?>Payment_Message] [<DateTime?>Moment_Of_Monetary_Change]
# Note: The indexed array "FundsUpdate" portraits the change in state of the funds of the Expense.
#	   And it is parsed as follows: <Int>PrevioudFunds//<Int>NewFunds
# 	  Where the double slash is literal and acts as a separator.
#	   For example, passing: 1250//1000
#	   Reads that the Expense previously had 1250 *money, and now has 1000.
#	   From this it is also deducted that the cost was 250. And it will be logged as well.
# Note: The payment message is not expanded in any way, shape or form.
# Note:	 The moment of monetary change means "when did my money change other than the moment I am recording the event into moneybook?".
#		   On output it will be formatted as: %a %b %d %Y %H:%Mhs
#		   It is a string passed to the date command. However the time of day might be replaced with `N/A`...
#		   For example: Mon Jan 27 2025 N/Ahs
# Note: 	You might invoke the function passing an empty string ''(as indicated by the question mark in the synopsis) in the place of either the log message or the moneyary change datetime, or not supply them at all.
#   		Internally, the function gets rid of the empty strings. Don't alter the order tho of those two tho.
		
		declare +r Expense_Name
		declare +r Funds_Update
		declare +r Previous_Funds
		declare +r New_Funds
		declare +r Payment_Message
		
		if [[ ${1-} = '' ]] ; then echo "Couldn't log payment, missing name of the Expense. Status 1" > /dev/stderr ; return 1 ; fi
		if [[ ${2-} = '' ]] ; then echo "Couldn't log payment, missing state of funds of the Expense. Status 2" > /dev/stderr ; return 2 ; fi
		if [[ "$#" -lt 2 || "$#" -gt 4 ]] ; then echo "Couldn't log payment, incorrect amount of arguments passed. Status 3" > /dev/stderr ; return 3 ; fi
		
		declare -r Expense_Name=${1}
		declare -r Funds_Update=${2}
		declare -r Payment_Message=${3-}
		
		# Check for incorrect form of "FundsUpdate"
		declare +r Valid_Integer_Regex='(-?[1-9][0-9]*|0)'
		declare +r Correct_FundsUpdate_Format="^${Valid_Integer_Regex}//${Valid_Integer_Regex}\$"
		
		if ! [[ "$Funds_Update" =~ $Correct_FundsUpdate_Format ]]
		then
				echo "Couldn't log payment, the states of the Expense's funds are not formatted correctly. Status 4" > /dev/stderr
				return 4
		fi

		unset Correct_FundsUpdate_Format
		unset Valid_Integer_Regex
		
		# Assign the new and old amount of funds
		declare Previous_Funds_Regex='^[^/]+'
		declare New_Funds_Regex='[^/]+$'
		
		Previous_Funds="$( grep --color=never -E -o "$Previous_Funds_Regex" <<< "$Funds_Update" )"
		New_Funds="$( grep --color=never -E -o "$New_Funds_Regex" <<< "$Funds_Update"  )"
		
		unset Previous_Funds_Regex
		unset New_Funds_Regex
		
		# Checking log file
		Logging_Is_Possible
		case $? in
		0) ;;
		1) echo "Couldn't log payment, the log file doesn't exist. Status 5" > /dev/stderr ; return 5 ;;
		2) echo "Couldn't log payment, the log file is not a regular file. Status 6" > /dev/stderr ; return 6 ;;
		3) echo "Couldn't log paymebt, the log file is not writable. Status 7" > /dev/stderr ; return 7 ;;
		*) echo "Couldn't log payment, an unexpected error occurred while checking the log file. Status 8" > /dev/stderr ; return 8 ;;
		esac
		
		# Checking Expense exists
		if ! . ~/moneybook/lib/Expense_Methods.bash Name_Is_Expense
		then
				echo -n "; Couldn't log payment, unable to source function to check Expense file. Status 9" > /dev/stderr
				return 9
		fi

		if ! Name_Is_Expense "$Expense_Name"
		then
				echo -n "; Couldn't check the name \`${Expense_Name}\` corresponds to a valid Expense file. Status 10" > /dev/stderr
				return 10
		fi

		# Creating the log line
		declare Log_Line
		declare Record_DateTime
		declare Record_DateTime_Format='+%a %b %e %Y %H:%Mhs' # The datetime might look like `Sat Aug 31 2024 16:20hs'
		declare -i Payment_Cost
		
		Record_DateTime="$( date "$Record_DateTime_Format" )"
		Payment_Cost=$(( Previous_Funds - New_Funds ))
		Log_Line=" [Payment] ${Record_DateTime}, a payment of \`${Payment_Cost}\` *money was made over the Expense \`${Expense_Name}\`( \`${Previous_Funds}\` > \`${New_Funds}\` )"
		if [[ "$Payment_Message" != '' ]] ; then Log_Line+=": ${Payment_Message}" ; fi
		
		unset Record_DateTime
		unset Record_DateTime_Format
		unset Payment_Costs
		
		# Write the line to the log file
		declare -r Log_File_Path='/data/data/com.termux/files/usr/var/log/moneybook.log'
		echo "$Log_Line" >> "$Log_File_Path"
		return
}