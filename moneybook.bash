#!/data/data/com.termux/files/usr/bin/bash
set -eu

read Account_Help <<< $(
cat ~/moneybook/Specifications/moneybook_AccountFile_useful_specification.txt ||
echo -e '
Refer to the specification file in the root directory of the program.
Regularly ~/moneybook
'
)

Command_Help_Message="
Purcharse management mode:\n
\t	Concrete synopsis: ${0} purcharse -d 'last friday' education 12000 'Hardvard course'\n
\t	Abstract synopsis: ${0} purcharse [-d | --datetime MomentOfMonetaryChange] /033[2;0AccountFileName PurcharseIntegerValue [ PurchaseLogMessage ]\n
\n
\t	Purcharse managment mode allows you to stage a purcharse over one of your Accounts. Allowing you to see your current foundings and what would remain if you commit the current purcharse.\n
\t	Each purchase is logged into the \`moneybook.log\` file, which is under the log directory of the OS. If given a message for the purchase, it gets logged along with the rest of the purchase.\n
\t	Specifying the moment of moneyary change apart from that of the record of the operation is allowed. The flag might be placed anywhere after the word \`purchase\` as long as the value follows right after.\n
\t	The value of the flag is interpreted by the \`date\` command, but if no hour(time of the day) value is supplied, it is specified as \`N/A\`, obviously, a date indicator is still mandatory.\n
Money injection mode:\n
\t	Concrete synopsis: ${0} inject 4700 'I won the lottery'\n
\t	Abstract synopsis: ${0} inject YourIncomingIntegerAmountOfMoney [ InjectionLogMessage ]\n
\n
\t	Injection mode allows to automatically split any incomming money between all of your Accounts.\n
\t	It is the mean to get money into the Accounts for free spending.\n
\t	Each injection is logged into the \`moneybook.log\` file, which is under the log directory of the OS. If given a message for the injection, it gets logged along with the rest of the details.\n
Money separation mode:\n
\t	Concrete synopsis: ${0} separate 1200 PhoneBill\n
\t	Abstract synopsis: ${0} separate AnIncommingPositiveIntegerAmountOfMoney FixedExpenseName\n
\n
\t	Separation mode allows you to save money for a given Fixed Expense, summing the amount to its funds. If the funds were to overflow the Budget of the Expense, then you are offered to Inject the exceeding money.\n
\t	It is the mean to get money destined to Pay a determined Fixed Spense.\n
Fixed Expense payment mode:\n
\t	Concrete synopsis: ${0} pay PhoneBill 1150 'I also bought a 20 bucks internet package'\n
\t	Abstract synopsis: ${0} pay FixedExpenseName [ PaymentPrice ] [ Log Message ]\n
\n
\t	Fixed Expense payment mode allows you to pay a determined Fixed Expense.\n
\t	The price of the payment will be discounted from the funds of the Expense. The final price of the payment might be specified, in that case that is the amount of money to be discounted. Otherwise, the budgeted amount, aka the Expense's Budget, is to be discounted.\n
\t	Each purchase is logged into the \`moneybook.log\` file, which is under the log directory of the OS. If given a message for the purchase, it gets logged along with the rest of the purchase.\n
\n
\t\t		Written by: @LucasYata
"

Incorrect_Mode_Message="
Unrecognized mode of operation: ${1-nothing}. Refer to the help message by executing the command without argument, or using the help flag (--help).
"

# _______________________________
# ------------- Injection mode --
# Helper functions

Get_Accounts() {
# Note: This was an inner function of 'Print_Account_Shares'.
# All this problem could be avoided if the Accounts were in a directory for themselves
# rather than in the root dir of the program among all other files
# attention: if a file without an extension other than an Account gets into the root dir
# it will have nasty consequences. Like a LOG file for example.
		for File in ~/moneybook/*
		do
				if [[ -d $File ]] ; then continue ; fi
				if [[ -L $File ]] ; then continue ; fi
				if ! File_Is_Account "$File" ; then continue ; fi
				echo "$File"
		done
}

Print_Account_Shares() { # Synopsis: Print_Account_Shares ['DisplayAccountNames'] # Abstract: Displays the shares of all Accounts, if any argument is given displays the Account each value corresponds
		declare Shares="$( grep --color=never --with-filename 'Share=' $( Get_Accounts ))"
		if [[ ${1+Parameter1WasNotPassed} != 'Parameter1WasNotPassed' ]] ; then cut --delim='=' --field=2 <<< $Shares ; return 0 ; fi
		grep --color=never -o '[^/]*$' <<< $Shares |
		sed 's/Share=//' ; # this should look like: "MyAccountName:ShareIntegerValue" 'recreation:20'
}

Splitting_Is_Total() { # Synopsis: Splitting_Is_Total # Abstract: Checks that the 100% of the money is split among all the Accounts # returns: 0 if true, 1 if false
		declare -i Sum_Of_Shares=0 # Should end up being 100
		for AccountShare in $( Print_Account_Shares ) ; do Sum_Of_Shares=$(( Sum_Of_Shares + AccountShare )) ; done

		if [[ Sum_Of_Shares -eq 100 ]] ; then return 0 ; fi
		return 1
}

Get_Percentage() { # Abstract synopsis: Get_Percentage Operand Percentage
# Sourced from: https://unix.stackexchange.com/a/421086
		declare Operand="$1"
		declare Percentage="$2"
		awk -v Operand="$Operand" -v Percentage="$Percentage" 'BEGIN{ print( Operand * ( Percentage / 100 ) ) }'
}

Get_Unfulfilled_Expenses() { # Abstract synopsis: Get_Unfulfilled_Expenses # Returns: 0 if any unfulfilled Expense was found, 1 if none was found and 2 if any error occurred. # echoes: Array of unfulfilled Expenses if any.
                declare -a Unfulfilled_Expenses[0]
                declare -r Error_Message="; Couldn't get unfulfilled Fixed Expenses. Status: "
                trap '
                                echo -n $Error_Message > /dev/stderr # [[ -> # I guess I will never know what this was. Thanks nano, I love you. Really.
                                return 2
                ' ERR
                for File in ~/moneybook/Fixed_Expenses/*
                do
                                declare +r File_Name="$( basename "$File" )"
                                if [[ -d "$File" ]] ; then continue ; fi
                                if [[ -L "$File" ]] ; then continue ; fi
                                if ! Name_Is_Expense "$File_Name" ; then continue ; fi
                                if Expense_Is_Fulfilled "$File_Name" ; then continue ; fi
                                Unfulfilled_Expenses+=( "$File_Name" )
                done
                if [[ -n ${Unfulfilled_Expenses[@]} ]]
                then
                                echo "${Unfulfilled_Expenses[@]}"
                                return 0
                fi
                return 1
}

Echo_Unfulfilled_Expenses_Warnings() { # outputs: A warning message for each unfulfilled Expense. Contaning the name of the expense, the current fundings and the budget.
		declare -a Unfulfilled_Expenses[0]
		declare Warning_Table
		declare -r Warning_Table_Headers='# ,Name,Fundings,Budget\n'

		declare -a Unfulfilled_Expenses=( $( Get_Unfulfilled_Expenses ) ) # Purposefully masking a falsy return
		if [[ -z ${Unfulfilled_Expenses[*]} ]] ; then return ; fi

		# Construct the warning table
		Warning_Table+="$Warning_Table_Headers"
		for Expense_Name in "${Unfulfilled_Expenses[@]}"
		do
				declare +r -i Expense_Funds="$( Read_Expense_Funds "$Expense_Name" )"
				declare +r -i Expense_Budget="$( Read_Expense_Budget "$Expense_Name" )"
				declare +r Warning_Table_Row="*, ${Expense_Name}, ${Expense_Funds}, ${Expense_Budget}\n"

				Warning_Table+="$Warning_Table_Row"
		done
		# unset Expense_Funds Expense_Budget Warnings_Table_Row

		# Echo the warning screen
		echo 'Warning: Unfulfilled Fixed Expenses were found:'
		echo -e "$Warning_Table\n" | column -t -s,
}

# Flow
Inject_Flow() {
		declare +r Incoming_Money
		declare +r Log_Message
		declare DateTimeFlag_Value

		# Argument quantity check
		declare Argument_Quantity_Error=''
		if [[ ${1:+IsSet} != 'IsSet' ]] ; then Argument_Quantity_Error='Missing argument for injection: Amount of incoming money' ; fi
		if [[ ${5+IsSet} = 'IsSet' ]] ; then Argument_Quantity_Error='Extra argument/s were supplied for injection. Aborting just in case' ; fi
		if [[ "$Argument_Quantity_Error" != '' ]]
		then
				echo "$Argument_Quantity_Error" > /dev/stderr
				return 2
		fi
		unset Argument_Quantity_Error

		# Handling the datetime flag
		# detecting tand validating the date flag
		for (( Argument_Index=0 ; Argument_Index<=${#@} ; Argument_Index++ ))
		do
				declare Argument="${@:$Argument_Index:1}"
				if [[ "$Argument" != '-d' && "$Argument" != '--datetime' ]] ; then continue ; fi
				declare Flag_Index="$Argument_Index"
				declare Flag_Value_Index=$(( Flag_Index + 1 ))
				if [[ "$Flag_Value_Index" -gt "${#@}" ]]
				then
						echo "Missing argument for purchase: Value following datetime flag" > /dev/stderr
						exit 2
				fi

				declare Flag_Value="${@:$Flag_Value_Index:1}"
				if ! date --date="$Flag_Value" &> /dev/null
				then
						echo "The datetime supplied for the moment of the monetary transaction could not be parsed by date command" > /dev/null
						exit 2
				fi
				break
		done
		unset Argument

		if [[ "${Flag_Value-}" != '' ]]
		then
				# handle no hour passed for flag
				declare +r Twelve_Hour_Regex='(1[0-2]|0?[0-9])(:[0-6][0-9])?((am|AM|a.m|A.M)|(pm|PM|p.m|P.M))'
				declare +r TwentyFour_Hour_Regex='([0-1]?[0-9]|2[0-4]):[0-5][0-9]'
				declare +r Log_DateTime_Format='+%a %b %d %Y %H:%Mhs'
		
				DateTimeFlag_Value="$( date --date "$Flag_Value" "$Log_DateTime_Format" )"
				if ! grep -E -e "$Twelve_Hour_Regex" -e "$TwentyFour_Hour_Regex" <<< "$Flag_Value" &> /dev/null ; then DateTimeFlag_Value="$( sed -E -e "s#${TwentyFour_Hour_Regex}hs#N/Ahs#" <<< "$DateTimeFlag_Value" )" ; fi
				unset Flag_Value
				unset Twelve_Hour_Regex
				unset TwentyFour_Hour_Regex
				unset Log_DateTime_Format

				# asigning the rest of the arguments
				# Because the flag can basically be at any given position within the arguments, it's not as somple as $1 = mode anymore.
				# The good thing is that, if I take the flag out of the equation, then the order of the normal arguments must be the same!
				declare -a Sequential_Arguments
				IFS=$'\t'
				Sequential_Arguments=( ${*} )
				# Trickily, $@ exapands to all positional parameters except for $0, but...
				# you can get $0 out of the same "reference" using ${@:0:1} as I did before.
				# As "Sequential_Arguments" is declared as a copy of $@, $0 is not present.
				# So... The index 0(first field) of $@ is not the same as ${@:0:1}.
				# Because of that, the indexes I have got when I iterated through the arguments are shifted right by 1...
				Flag_Index=$(( Flag_Index - 1 ))
				Flag_Value_Index=$(( Flag_Value_Index - 1 ))
				unset 'Sequential_Arguments[$Flag_Value_Index]'
				unset 'Sequential_Arguments[$Flag_Index]'
				# Beware, in bash unsetting an array index doesn't move the next element to the current index, instead, the index is left empty.
				Sequential_Arguments=( ${Sequential_Arguments[*]} ) # This makes the elements left in the array to be in a row
				declare -r Incoming_Money="${Sequential_Arguments[0]}"
				declare -r Log_Message="${Sequential_Arguments[1]-}"
				unset Sequential_Arguments
				unset Flag_Index
				unset Flag_Value_Index
				unset IFS
		else
				declare -r DateTimeFlag_Value=''
				unset Flag_Value
				declare -r Incoming_Money="$1"
				declare -r Log_Message="${2-}"
		fi

		if ! . ~/moneybook/lib/Account_Methods.bash
		then
				echo "Couldn't source \`~/moneybook/bin/Account_Methods.bash\` file containing necessary proceedures to treat Accounts." > /dev/stderr
				return 99
		fi

		if ! . ~/moneybook/lib/Logging_Methods.bash
		then
				echo "Couldn't source \`~/moneybook/lib/Logging_Methods.bash\` which cointains necessary proceedures to log Injections" > /dev/stderr
				return 100
		fi

		if ! Splitting_Is_Total
		then
				echo 'The split cannot be done because the sum of the shares among all Accounts does not equal a 100% of any incoming money.' > /dev/stderr
				return 3
		fi
		
		# integer check for incoming money
		if [[ ! "$Incoming_Money" =~ ^[0-9]+$ ]]
		then
				echo 'Cannot parse the second argument as an integer amount of money' > /dev/stderr
				return 4
		fi 
		# zero amount check
		if [[ "$Incoming_Money" =~ ^0+$ ]]
		then
				echo 'Yeah, consider it done or whatever(why to inject no value at all).' > /dev/stderr
				return 5
		fi

		# Display transaction state
		( # Try to show unfulfilled Expenses
				if . ~/moneybook/lib/Expense_Methods.bash 2> /dev/null
				then Echo_Unfulfilled_Expenses_Warnings ;
				else echo "Error: Couldn't source the file \`~/moneybook/lib/Expense_Methods.bash\` necessary to check and display whether there are unfulfilled Accounts or not. Continuing regardless..." > /dev/stderr
				fi
		)

		echo -e "An amount of $Incoming_Money *money* is about to be injected and split among all your Accounts accordingly.\n"
		
		# Ask for confirmation
		read -n 1 -p 'Do you wish to continue? Y/N: ' ; echo
		if [[ "${REPLY,,}" != y && "${REPLY,,}" != n ]] ; then echo 'Invalid option, aborting.' > /dev/stderr ; return 5 ; fi
		if [[ "${REPLY,,}" == n ]]
		then
				echo 'Injection cancelled'
				return 1
		fi

		# Gather the data
		declare -a Account_Objects
		declare Account_File_Name
		declare -i Account_Share
		declare -i Account_Old_Funds
		declare -i Account_Income
		declare -i Account_New_Funds
		for Account_File_Path in $( Get_Accounts )
		do
				Account_File_Name="$( basename "$Account_File_Path" )"
				Account_Share="$( sed -n -e '/^Share=[0-9]\+$/s/^Share=//p' "$Account_File_Path" )"
				Account_Income="$( Get_Percentage "$Incoming_Money" "$Account_Share" | cut --delim='.' --field=1 )"
				Account_Old_Funds=$( Read_Account "$Account_File_Name" )
				Account_New_Funds=$(( Account_Old_Funds + Account_Income ))

				Account_Objects+=( "${Account_File_Name}//${Account_Old_Funds}//${Account_New_Funds}" )
		done
		unset Account_Share Account_Old_Funds Account_Income Account_New_Funds

		# Log the injection
		if ! Log_Injection "$Incoming_Money" "${Account_Objects[@]}" "$Log_Message" "$DateTimeFlag_Value"
		then
				echo "The injection couldn't be logged..." > /dev/stderr
				echo "The injection hasn't take effect yet. You can safely cancel it now."
				echo -e "If you proceed anyway the injection won't be logged. If you don't then it will be cancelled and won't take effect.\n"
				read -n 1 -p 'Do you wish to continue? Y/N: ' ; echo
				case "${REPLY,,}" in
				y) ;;
				n) echo 'Injection canceled' ; return 1 ;;
				*) echo 'Invalid option, aborting.' > /dev/stderr ; return 5 ;;
				esac
		fi

		# Commit the injection
		declare +r Account_File_Name
		declare +r Account_Old_Funds
		declare +r Account_New_Funds
		for Account_Object in "${Account_Objects[@]}"
		do
				Account_File_Name="$( sed 's|//.*$||' <<< "$Account_Object" )"
				Account_Old_Funds="$( sed 's|^[^/]*//||; s|//.*$||' <<< "$Account_Object" )"
				Account_New_Funds="$( sed 's|^.*//||' <<< "$Account_Object" )"

				if ! Write_Account "$Account_File_Name" "$Account_New_Funds"
				then
						echo -e "Couldn\'t add(write) \`${Account_Income}\` to the Account \`${Account_File_Name}\`. Status 6" > /dev/stderr
						return 6
				fi
				echo "Updated funds for Account: $Account_File_Name ( $Account_Old_Funds > $Account_New_Funds )"
		done
		unset Account_File_Name Account_Old_Funds Account_New_Funds

		echo 'Injection completed :)'
		return 0
}

# ___________________________
# ------------- Main -------

# Bounce backs
if [[ $# -eq 0 ]] ; then echo -e $Command_Help_Message ; exit 1 ; fi
if [[ "$1" == 'help' || "$1" == '--help' ]] ; then echo -e $Command_Help_Message ; exit 1 ; fi
if [[ "$1" != 'purchase' && "$1" != 'inject' && "$1" != 'separate' && "$1" != 'pay' ]] ; then echo -e "$Incorrect_Mode_Message" ; exit 1 ; fi

# Purchase management mode
Echo_Account_State() { # Echo_Account_State MyAccountName PurchaseIntegerValueyAccount CurrentFoundings Remaining_Account_Foundings
		declare -r Account_Name="$1"
		declare -ri Purchase_Value=$2
		declare -ri Account_Current_Foundings=$3
		declare -ri Remaining_Account_Foundings=$4

		# this is a start up responsability over the mode, and a responsability when reading or writing to an Account # if [[ ! -f "$Account_Name" ]] ; then return 1 ; fi
		if [[ $# -ne 4 ]]
		then
				echo "Cannot echo account state as the amount of parameters is incorrect." > /dev/stderr
				exit 2
		fi

		echo -e "
		${Account_Name}'s current foundings: ${Account_Current_Foundings}
		Current purchase: ${Purchase_Value}
		Remaining foundings after purchase: ${Remaining_Account_Foundings}\n
		"
		return 0
}
Insufficient_Funds_Warning='
Warning: The Account you selected does not have enough money for that transaction. You may still continue...
'
No_Purchase_Message_Warning='
Warning: no purchase message was supplied!
'

if [[ "$1" == 'purchase' ]]
then
Purchase_Flow() {

		declare +r Account_Name
		declare +r Purchase_Value
		declare +r Purchase_Message
		declare +i Account_Current_Foundings
		declare +i Remaining_Account_Foundings
		declare DateTimeFlag_Value

		if [[ $# -lt 2 || $# -gt 6 ]]
		then
				if [[ ${1+IsSet} != 'IsSet' ]] ; then echo 'Missing arguments for purchase: Account Name, Price' > /dev/stderr
				elif [[ ${2+IsSet} != 'IsSet' ]] ; then echo 'Missing argument for purchase: Price' > /dev/stderr
				elif [[ ${6+IsSet} = 'IsSet' ]] ; then echo 'Extra arguments were supplied for purchase. Aborting just in case' > /dev/stderr
				fi
				exit 2
		fi

		# Argument handling
		# Greatest overload: moneybook purchase savings 3442453 "Sex doll" -d "Last friday" # 6 arguments(either long or short flag, screw --flag=value format).
		# Smallest overload: moneybook purchase savings 3442453 # 3 arguments

		# detecting tand validating the date flag
		for (( Argument_Index=0 ; Argument_Index<=${#@} ; Argument_Index++ ))
		do
				declare Argument="${@:$Argument_Index:1}"
				if [[ "$Argument" != '-d' && "$Argument" != '--datetime' ]] ; then continue ; fi
				declare Flag_Index="$Argument_Index"
				declare Flag_Value_Index=$(( Flag_Index + 1 ))
				if [[ "$Flag_Value_Index" -gt "${#@}" ]]
				then
						echo "Missing argument for purchase: Value following datetime flag" > /dev/stderr
						exit 2
				fi

				declare Flag_Value="${@:$Flag_Value_Index:1}"
				if ! date --date="$Flag_Value" &> /dev/null
				then
						echo "The datetime supplied for the moment of the monetary transaction could not be parsed by date command" > /dev/null
						exit 2
				fi
				break
		done
		unset Argument


		# check for non-flag argument under quantity limit
		# Checking the quangity is not enough, as it is possible to pass something other than the flag and being under the quantity limitations.
		# In that case the program would just go by without the flag, but without halting either.
		if [[ "$#" > 3 && "${Flag_Value-}" = '' ]]
		then
				# Rationale:
				# There's 3 sequential arguments, and the flag. If there's more parameters than that necessary for the sequential arguments,
				# and there's no flag value, then either the flag is wrong or some nonsense was passed.
				# The three first parameters will be evaluated as the account, amount and message respectively. So if they're other than that,
				# then the program will eventually return anyway. So there's no need to worry about them.
				# Threat: moneybook purchase test 100 "Hola" dufufjf hujh # This currently lets the program run without flag
				echo 'Invalid argument/s detected. Aborting.' > /dev/stderr
				return 2
		fi

		# handle datetime flag
		if [[ "${Flag_Value-}" != '' ]]
		then
				# handle no hour passed for flag
				declare +r Twelve_Hour_Regex='(1[0-2]|0?[0-9])(:[0-6][0-9])?((am|AM|a.m|A.M)|(pm|PM|p.m|P.M))'
				declare +r TwentyFour_Hour_Regex='([0-1]?[0-9]|2[0-4]):[0-5][0-9]'
				declare +r Log_DateTime_Format='+%a %b %d %Y %H:%Mhs'
		
				DateTimeFlag_Value="$( date --date "$Flag_Value" "$Log_DateTime_Format" )"
				if ! grep -E -e "$Twelve_Hour_Regex" -e "$TwentyFour_Hour_Regex" <<< "$Flag_Value" &> /dev/null ; then DateTimeFlag_Value="$( sed -E -e "s#${TwentyFour_Hour_Regex}hs#N/Ahs#" <<< "$DateTimeFlag_Value" )" ; fi
				unset Flag_Value
				unset Twelve_Hour_Regex
				unset TwentyFour_Hour_Regex
				unset Log_DateTime_Format

				# asigning the rest of the arguments
				# Because the flag can basically be at any given position within the arguments, it's not as somple as $1 = mode anymore.
				# The good thing is that, if I take the flag out of the equation, then the order of the normal arguments must be the same!
				declare -a Sequential_Arguments
				IFS=$'\t'
				Sequential_Arguments=( ${*} )
				# Trickily, $@ exapands to all positional parameters except for $0, but...
				# you can get $0 out of the same "reference" using ${@:0:1} as I did before.
				# As "Sequential_Arguments" is declared as a copy of $@, $0 is not present.
				# So... The index 0(first field) of $@ is not the same as ${@:0:1}.
				# Because of that, the indexes I have got when I iterated through the arguments are shifted right by 1...
				Flag_Index=$(( Flag_Index - 1 ))
				Flag_Value_Index=$(( Flag_Value_Index - 1 ))
				unset 'Sequential_Arguments[$Flag_Value_Index]'
				unset 'Sequential_Arguments[$Flag_Index]'
				# Beware, in bash unsetting an array index doesn't move the next element to the current index, instead, the index is left empty.
				Sequential_Arguments=( ${Sequential_Arguments[*]} ) # This makes the elements left in the array to be in a row
				declare -r Account_Name="${Sequential_Arguments[0]}"
				declare -r Purchase_Value="${Sequential_Arguments[1]}"
				declare +r Purchase_Message="${Sequential_Arguments[2]-}"
				unset Sequential_Arguments
				unset Flag_Index
				unset Flag_Value_Index
				unset IFS
		else
				declare -r DateTimeFlag_Value=''
				unset Flag_Value
				declare -r Account_Name="$1"
				declare -r Purchase_Value="$2"
				declare -r Purchase_Message="${3-}"
		fi

		# Sourcing
		if ! . ~/moneybook/lib/Account_Methods.bash
		then
				echo "Couldn't source \`~/moneybook/bin/Account_Methods.bash\` file containing necessary proceedures to treat Accounts." > /dev/stderr
				return 99
		fi
		if ! . ~/moneybook/lib/Logging_Methods.bash
		then
				echo "Couldn't source \`~/moneybook/lib/Logging_Methods\` file, which cointains necessary procedures to log purchases." > /dev/stderr
				return 100
		fi

		# Check input
		if [[ ! "$Purchase_Value" =~ ^[0-9]+$ ]]
		then
				echo 'Invalid purchase value, please enter an integer value.' > /dev/stderr
				exit 3
		fi

		# Get Account state
		set +e
		Account_Current_Foundings=$( Read_Account "$Account_Name" )
		declare +r -i Read_Account_Status=$?
		if [[ $Read_Account_Status -ne 0 ]]
		then
				if [[ "$Read_Account_Status" -eq 2 ]] ; then echo "Unable to read Account \`${Account_Name}\`, no such file or directory." > /dev/stderr
				else echo "Unable to read Account \`${Account_Name}\`, couldn't parse \`${Account_Name}\` as a moneybook Account. Status: ${Read_Account_Status}" > /dev/stderr ; fi
				exit 4
		fi
		unset Read_Account_Status
		set -e

		Remaining_Account_Foundings=$(( Account_Current_Foundings - Purchase_Value ))
	
		# Displaying the purchase screen
		Echo_Account_State "$Account_Name" "$Purchase_Value" "$Account_Current_Foundings" "$Remaining_Account_Foundings"
		if [[ $Remaining_Account_Foundings -lt 0 ]] ; then echo "$Insufficient_Funds_Warning" > /dev/stderr ; fi
		if [[ "$Purchase_Message" = "" ]] ; then echo $No_Purchase_Message_Warning ; fi

		read -n 1 -p 'Do you wish to continue? Y/N: ' ; echo
		if [[ "${REPLY,,}" != y && "${REPLY,,}" != n ]] ; then echo 'Invalid option, aborting.' > /dev/stderr ; exit 5 ; fi
		if [[ "${REPLY,,}" == n ]]
		then
				echo 'Purchase cancelled'
				exit 1
		fi
	
		# Log the purchase
		if ! Log_Purchase "$Account_Name" "$Purchase_Value" "$Purchase_Message" "$DateTimeFlag_Value"
		then
				echo "The purchase couldn't be logged..." > /dev/stderr
				echo "The purchase hasn't take effect yet. You can safely cancel it now."
				echo -e "If you proceed anyway the purchase won't be logged. If you don't then it will be cancelled and won't take effect.\n"
				read -n 1 -p 'Do you wish to continue? Y/N: ' ; echo
				case "${REPLY,,}" in
				y) ;;
				n) echo 'Purchase canceled' ; return 1 ;;
				*) echo 'Invalid option, aborting.' > /dev/stderr ; exit 5 ;;
				esac
		fi

		# Update the funds
		Write_Account "$Account_Name" $Remaining_Account_Foundings
		echo 'Purchase committed successfully'
		exit 0
}
		( shift 1 ; Purchase_Flow "$@" )
		exit $?
fi

if [[ "$1" == 'inject' ]]
then
		# if [[ $# -gt 2 ]]
		# then
				# echo "An incorrect amount of arguments were supplied. Aborting injection just in case." > /dev/stderr
				# exit 1
		# fi

		( shift 1 ; Inject_Flow "$@" )
		exit $?
fi

# Separate for Expense mode # moneybook separate `Money` Fixed Expense
if [[ "$1" = 'separate' ]]
then
		if ! . ~/moneybook/lib/Expense_Methods.bash
		then
				echo "Couldn't source \`~/moneybook/lib/Expense_Methods.bash\` file containing necessary proceedures to treat Fixed Expenses." > /dev/stderr
				exit 99
		fi

		Separation_Flow() {
		# Incorrect input bounce backs 
		if [[ -z "${1:+IsSet}" ]] ; then echo "Couldn't separate the money, missing arguments: Amount of money and Fixed Expense." > /dev/stderr ; return 2 ; fi
		if [[ -z "${2:+IsSet}" ]] ; then echo "Couldn't separate the money, missing argument: Fixed Account." > /dev/stderr ; return 3 ; fi
		if [[ ${4+IsSet} = 'IsSet' ]] ; then echo "Couldn't separate the money, exceeding arguments were passed. Aborting just in case." > /dev/stderr ; return 4 ; fi
		if [[ ! "$1" =~ [0-9]+$ ]] ; then echo "Couldn't parse the second argument as a positive integer." > /dev/stderr ; return 5 ; fi

		declare -i Income="$1"
		declare Expense_Name="$2"
		declare Log_Message="${3-}"
		declare +r Expense_Funds
		declare +r Expense_Budget
		declare +r Postoperation_Expense_Funds
		declare +r -i Current_Exceeding_Funds
		declare +r -i New_Exceeding_Funds

		# Invalid input bounce backs
		if [[ "$Income" -eq 0 ]] ; then echo 'Consider it done I guess...' > /dev/stderr ; return 1 ; fi
		if ! Name_Is_Expense "$Expense_Name" ; then echo "Couldn't find a Fixed Expense named \`${Expense_Name}\` in the directory for Fixed Expenses at the root dir of the program." > /dev/stderr ; fi

		Expense_Funds="$( Read_Expense_Funds "$Expense_Name" )"
		Expense_Budget="$( Read_Expense_Budget "$Expense_Name" )"
		Postoperation_Expense_Funds=$(( Expense_Funds + Income ))
		Current_Exceeding_Funds=$(( Expense_Funds > Expense_Budget ? Expense_Funds - Expense_Budget : 0 ))
		New_Exceeding_Funds=$(( Postoperation_Expense_Funds > Expense_Budget ? Postoperation_Expense_Funds - Expense_Budget : 0 ))

		# Display transaction state
		echo -e "${Income} of *money* is about to be separated for the Expense \`${Expense_Name}\`.
		Expense Budget: ${Expense_Budget}
		Expense current funds: ${Expense_Funds}
		Expense funds after transaction: ${Postoperation_Expense_Funds}
		"
		if [[ "$Current_Exceeding_Funds" -gt 0 ]] ; then echo -e "Exceeding funds: ${Current_Exceeding_Funds}" ; fi
		if [[ "$New_Exceeding_Funds" -gt 0 ]] ; then echo "Exceeding funds after operation: ${New_Exceeding_Funds}" ; fi

		if Expense_Is_Fulfilled "$Expense_Name" ; then echo "Warning: The Expense already has a fulfilled Budget." ; fi

		# Ask for confirmation
		echo ; read -n 1 -p 'Do you wish to continue? Y/N: ' ; echo
		if [[ "${REPLY,,}" != y && "${REPLY,,}" != n ]] ; then echo 'Invalid option, aborting.' > /dev/stderr ; exit 2 ; fi
		if [[ "${REPLY,,}" == n ]]
		then
				echo 'Separation cancelled'
				exit 0
		fi

		# Log the operation
		if ! . ~/moneybook/lib/Logging_Methods.bash Log_Separation
		then
				echo "Couldn't separate money, unable to source lib files with necessary procedures to log the separation." > /dev/stderr
				return 3
		fi

		if ! Log_Separation "$Expense_Name" "${Expense_Funds}//${Postoperation_Expense_Funds}" "$Log_Message"
		then
				echo "Couldn't make separation, unable to record and log operation into log file." > /dev/stderr
				return 4
		fi

		# Commit the separation
		if ! Write_Expense "$Expense_Name" "$Postoperation_Expense_Funds"
		then
				echo "Couldn't write \`${Postoperation_Expense_Funds}\` to Expense \`${Expense_Name}\`." > /dev/stderr
				exit 5
		fi
		
		# Offer to inject exceeding funds
		if [[ "$Postoperation_Expense_Funds" -le "Expense_Budget" ]]
		then
				echo "Money separated successfully :)"
				exit 0
		fi
		
		echo "The Budget of the Expense is overflowed by \`${New_Exceeding_Funds}\`..."
		read -n 1 -p 'Would you like to Inject those exceding funds? Y/N: ' ; echo
		if [[ "${REPLY,,}" != y && "${REPLY,,}" != n ]] ; then echo 'Invalid option, aborting.' > /dev/stderr ; exit 2 ; fi
		if [[ "${REPLY,,}" == n ]]
		then
				echo -e 'Money separated sucessfully :)'
				exit 0
		fi
		
		# Compensate for the exceeding money
		if ! Write_Expense "$Expense_Name" "$Expense_Budget"
		then
				echo "; Couldn't take the exceeding money" > /dev/stder
				exit 14
		fi

		# Inject it
		echo -e '\nnInjection: -------------'
		if ! Inject_Flow "$New_Exceeding_Funds" # (
				# I pretended to prefix every putput from the inject flow with '+ '. However, doing so with the prompt of the read command
				# has proved to be not as straight forward. Maybe in the future I will solve this. But not now.
				  # set -o pipefail
		      	# Inject_Flow "$New_Exceeding_Funds" |&
		      	# sed '/\S/s/^/+ /'
		# ) 
		then
				echo "; Couldn't Inject the exceeding amount \`${New_Exceeding_Funds}\`.\nTrying to restore it to the Expense." > /dev/stderr
				if Write_Expense "$Expense_Name" "$Postoperation_Expense_Funds"
				then
						echo "Exceeding fundings successfuly restored to Expense."
						exit 15
				else
						echo -e "
						Couldn't restore \`${New_Exceeding_Funds}\` to the funds of the Expense \`${Expense_Name}\`.
						That overflow was lost in the transaction. The Expense's fundings should be `\${Postoperation_Expense_Funds}`\ but are \`${Expense_Budget}\` instead.\n
						This requires a manual fixing.
						" > /dev/stderr
						exit 16
				fi
		fi
		
		echo '------------------------'
		echo 'The separation was committed successfully :)'
		return 0
		}
		( shift 1 ; Separation_Flow "$@" )
fi
if [[ "$1" = 'pay' ]]
then
		Payment_Flow() {
		DateTimeFlag_IsPresent() { grep -Ew -- '-d|--date' <<< "$@" &> /dev/null ; }
		if ! . ~/moneybook/lib/Expense_Methods.bash
		then
				echo "Couldn't source \`~/moneybook/lib/Expense_Methods.bash\` file containing necessary proceedures to treat Fixed Expenses. Status: 2" > /dev/stderr
				return 2
		fi

		# Check quantity of arguments
		{
				declare -i Minimum_Parameters=1
				declare -i Max_Parameters=3
				
				if DateTimeFlag_IsPresent "$@"
				then
						Minimum_Parameters+=2
						Max_Parameters+=2
						# As a sidenote, this works only because the variables are integers.
				fi
				
				if [[ "$#" -lt "$Minimum_Parameters" ]]
				then
						echo "Couldn't pay expense, too little arguments. Status: 3" > /dev/stderr
						return 3
				elif [[ "$#" -gt "$Max_Parameters" ]]
				then
						echo "Couldn't pay expense, too much arguments. Status: 4" > /dev/stderr
						return 4
				fi

				unset Minimum_Parameters
				unset Max_Parameters
		}
		
		declare Expense_Name
		declare +i Payment_Cost
		declare -i Expense_Funds
		declare -i Postransaction_Expense_Funds
		declare Payment_Message
		declare Payment_DateTime=''

		# Assigning the arguments
		{
				# Assigning the datetime flag
				if DateTimeFlag_IsPresent "$@"
				then
						declare -i DateTime_Flag_Index
						declare -i DateTime_Argument_Index

						declare -i Last_Parameter_Index="$#"
						for (( Parameter_Index=1 ; "$Parameter_Index"<="$Last_Parameter_Index" ; Parameter_Index++ ))
						do
								declare Current_Parameter="${!Parameter_Index}"
								if [[ "$Current_Parameter" != '-d' && "$Current_Parameter" != '--datetime' ]] ; then continue ; fi
								if [[ "$Parameter_Index" -eq "$Last_Parameter_Index" ]]
								then
										echo "Couldn't make payment, datetime flag has no argument. Status 5" > /dev/stderr
										return 5
								fi

								declare -i Payment_DateTime_Index=$(( Parameter_Index + 1 ))
								Payment_DateTime="${!Payment_DateTime_Index}"

								DateTime_Flag_Index="$Parameter_Index"
								DateTime_Argument_Index="$Payment_DateTime_Index"
								break
						done
						unset Last_Parameter_Index
						unset Current_Parameter
						unset Payment_DateTime_Index

						# Excluding the flag and its argument from the parameters
						DateTime_Argument_Index=$(( DateTime_Argument_Index - 1 ))
						DateTime_Flag_Index=$(( DateTime_Flag_Index - 1 ))

						declare -a Rest_Of_Parameters[0]
						Rest_Of_Parameters=( "$@" )
						unset 'Rest_Of_Parameters[$DateTime_Argument_Index]'
						unset 'Rest_Of_Parameters[$DateTime_Flag_Index]'
						
						Rest_Of_Parameters=( "${Rest_Of_Parameters[@]}" )
						set -- "${Rest_Of_Parameters[@]}"

						unset DateTime_Flag_Index
						unset DateTime_Argument_Index

				fi

				# Assigning the rest of the arguments
				declare Expense_Name="$1"
				declare Payment_Cost="${2-}"
				declare Payment_Message="${3-}"
		}

		# Validating the parameters
		local +r -i Name_Is_Expense_Status=$( Name_Is_Expense "$Expense_Name" 2> /dev/null ; echo $? ) # it would be nice to be able to invoke `Name_Is_Expense --echo "$Expense_Name" 2> /dev/null` to echo its exit status directly
		if ! ( return $Name_Is_Expense_Status )
		then
				if [[ $Name_Is_Expense_Status -eq 2 ]] ; then echo "Couldn't pay expense, \`${Expense_Name}\`, no such file or directory."
				else echo "Couldn't pay expense, the name \`${Expense_Name}\` is not a correct Fixed Account file. Status: 5" > /dev/stderr ; fi
				return 5
		fi
		unset Name_Is_Expense_Status

		if [[ "$Payment_Cost" != '' &&  ! "$Payment_Cost" =~ [0-9]+$ ]]
		then
				echo "Couldn't parse the cost of the payment as a positive integer. Status: 6" > /dev/stderr
				return 6
		elif [[ "$Payment_Cost" = '' ]]
		then
				if ! Payment_Cost="$( Read_Expense_Budget "$Expense_Name" )"
				then
						echo "Couldn't get the budget of the Expense to use it as the cost of the payment. Status: 7" > /dev/stderr
						return 6
				fi
		fi
		declare -i Payment_Cost

		if ! date --date="$Payment_DateTime" &> /dev/null
		then
				echo "Couldn't make payment, the datetime supplied for the moment of the monetary transaction could not be parsed by date command" > /dev/stderr
				return 6
		fi
		
		## Assign the variables
		# Define the cost of the payment
		if ! Expense_Funds="$( Read_Expense_Funds "$Expense_Name" )"
		then
				echo "; Couldn't get current funds of the Expense. Status: 8"
				return 8
		fi
		Postransaction_Expense_Funds=$(( Expense_Funds - Payment_Cost ))

		# Format datetime
		if [[ "$Payment_DateTime" != '' ]]
		then
				declare Hour_Is_Present=false
				declare Log_DateTime_Format='+%a %b %d %Y %H:%Mhs'
				declare Twelve_Hour_Regex='(1[0-2]|0?[0-9])(:[0-6][0-9])?((am|AM|a.m|A.M)|(pm|PM|p.m|P.M))'
				declare TwentyFour_Hour_Regex='([0-1]?[0-9]|2[0-4]):[0-5][0-9]'
		
				if grep -E -e "$Twelve_Hour_Regex" -e "$TwentyFour_Hour_Regex" <<< "$Payment_DateTime" &> /dev/null
				then Hour_Is_Present=true
				else Hour_Is_Present=false
				fi
		
				Payment_DateTime="$( date --date "$Payment_DateTime" "$Log_DateTime_Format" )"
				unset Log_DateTime_Format
		
				if ! $Hour_Is_Present
				then
					Payment_DateTime="$( sed -E -e "s#${TwentyFour_Hour_Regex}hs#N/Ahs#" <<< "$Payment_DateTime" )"
				fi
				unset Hour_Is_Present
				unset Twelve_Hour_Regex
				unset TwentyFour_Hour_Regex
		fi

		## Display payment screen
		Payment_Screen="
		The payment of \`${Payment_Cost}\` will be done over the Fixed Expense \`${Expense_Name}\`\n
		\t	Expense funds: ${Expense_Funds}\n
		\t	Payment Cost: ${Payment_Cost}\n
		\t	Remaining funds after payment: ${Postransaction_Expense_Funds}\n
		"
		echo -e $Payment_Screen
		unset Payment_Screen

		# Ask for confirmation
		read -n 1 -p 'Proceed with the payment? Y/N: ' ; echo
		if [[ "${REPLY,,}" != y && "${REPLY,,}" != n ]] ; then echo 'Invalid option, aborting.' > /dev/stderr ; return 8 ; fi
		if [[ "${REPLY,,}" == n ]]
		then
				echo -e 'Payment canceled.'
				return 1
		fi

		## Commit the payment
		if ! Write_Expense "$Expense_Name" "$Postransaction_Expense_Funds"
		then
				echo "; Couldn't take off the money for the payment off the Expense. Status: 9"
				return 9
		fi

		# Log the payment
		if ! . ~/moneybook/lib/Logging_Methods.bash Log_Payment
		then
				echo "Couldn't log the payment, unable to source logging function. Status 10" > /dev/stderr
				return 10
		fi

		if ! Log_Payment "$Expense_Name" "${Expense_Funds}//${Postransaction_Expense_Funds}" "$Payment_Message" "$Payment_DateTime"
		then
				echo "; Couldn't log payment, there was an error with the log function." > /dev/stderr
				echo "Warning: The money was already charged, but it was not recorded in the log file..."
		fi

		echo 'Payment committed successfully :)'
		return 0

		}
		( shift 1 ; Payment_Flow "$@" )
		exit $?
fi

# ------------------------------------------------------------------------
