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
\t	Concrete synopsis: ${0} purcharse education 12000\n
\t	Abstract synopsis: ${0} purcharse /033[2;0AccountFileName PurcharseIntegerValue\n
\n
\t	Purcharse managment mode allows you to stage a purcharse over one of your Accounts. Allowing you to see your current foundings and what would remain if you commit the current purcharse.\n
Money injection mode:\n
\t	Concrete synopsis: ${0} inject 4700\n
\t	Abstract synopsis: ${0} inject YourIncomingIntegerAmountOfMoney\n
\n
\t	Injection mode allows to automatically split any incomming money between all of your Accounts.\n
\t	It is the mean to get money into the Accounts for free spending.\n
Money separation mode:\n
\t	Concrete synopsis: ${0} separate 1200 PhoneBill\n
\t	Abstract synopsis: ${0} separate AnIncommingPositiveIntegerAmountOfMoney FixedExpenseName\n
\n
\t	Separation mode allows you to save money for a given Fixed Expense, summing the amount to its funds. If the funds were to overflow the Budget of the Expense, then you are offered to Inject the exceeding money.\n
\t	It is the mean to get money destined to Pay a determined Fixed Spense.\n
Fixed Expense payment mode:\n
\t	Concrete synopsis: ${0} pay PhoneBill 1150\n
\t	Abstract synopsis: ${0} pay FixedExpenseName [ PaymentPrice ]\n
\n
\t	Fixed Expense payment mode allows you to pay a determined Fixed Expense.\n
\t	The price of the payment will be discounted from the funds of the Expense. The final price of the payment might be specified, in that case that is the amount of money to be discounted. Otherwise, the budgeted amount, aka the Expense's Budget, is to be discounted.\n
\n
\t\t		Written by: @LucasYata
"

Incorrect_Mode_Message="
Unrecognized mode of operation: ${1-nothing}. Refer to the help message by executing the command without argument, or using the help flag (--help).
"

# _______________________________
# ------------- Injection mode --
# Helper functions
Print_Account_Shares() { # Synopsis: Print_Account_Shares ['DisplayAccountNames'] # Abstract: Displays the shares of all Accounts, if any argument is given displays the Account each value corresponds
		Get_Accounts() {
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
		# Argument quantity check
		declare Argument_Quantity_Error=''
		if [[ ${1:+IsSet} != 'IsSet' ]] ; then Argument_Quantity_Error='Missing argument for injection: Amount of incoming money' ; fi
		if [[ ${2+IsSet} = 'IsSet' ]] ; then Argument_Quantity_Error='Extra argument/s were supplied for injection. Aborting just in case' ; fi
		if [[ "$Argument_Quantity_Error" != '' ]]
		then
				echo "$Argument_Quantity_Error" > /dev/stderr
				return 2
		fi
		unset Argument_Quantity_Error
		declare Incoming_Money="$1"

		if ! . ~/moneybook/lib/Account_Methods.bash
		then
				echo "Couldn't source \`~/moneybook/bin/Account_Methods.bash\` file containing necessary proceedures to treat Accounts." > /dev/stderr
				return 99
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

		# Commit the injection
		for Share in $( Print_Account_Shares DisplayCorrespondingAccountNames )
		do
				declare Account_File_Name
				declare -i Account_Share
				declare -i Account_Foundings
				declare -i Account_Income
				declare -i Account_New_Foundings

				Account_File_Name="$( cut --delim=':' --field=1 <<< $Share )"
				Account_Share=$( cut --delim=':' --field=2 <<< $Share )
				Account_Foundings=$( Read_Account "$Account_File_Name" )
				Account_Income=$( Get_Percentage "$Incoming_Money" "$Account_Share" | cut --delim='.' --field=1 )
				Account_New_Foundings=$(( Account_Foundings + Account_Income ))

				# echo "Account_File_Name = $Account_File_Name"
				# echo "Account_Share = $Account_Share"
				# echo "Account_Foundings = $Account_Foundings"
				# echo "Account_Income = $Account_Income"
				# echo "Account_New_Foundings = $Account_New_Foundings"

				if ! Write_Account "$Account_File_Name" "$Account_New_Foundings"
				then
						echo -e "Couldn\'t add(write) $Account_Income to the Account \`${Account_File_Name}\`. Status: $?" > /dev/stderr
						return 6
				fi
				echo "Updated foundings for Account: $Account_File_Name ( $Account_Foundings > $Account_New_Foundings )"
		done
		echo 'Injection completed :)'
		return 0
}

# ___________________________
# ------------- Main -------

# Bounce backs
case "$1" in # this facility is a commodity to not break the program while I implement atomic argument quantity control
		('purchase' | 'inject' | 'separate') ;;
		('pay')
		if [[ $# -lt 2 || $# -gt 3 ]] ; then echo -e $Command_Help_Message ; exit 1 ; fi
		;;
esac

if [[ "$1" == 'help' || "$1" == '--help' ]] ; then echo -e $Command_Help_Message ; exit 1 ; fi
# if [[ "$1" != 'purchase' && "$1" != 'inject' && "$1" != 'separate' && "$1" != 'pay' ]] ; then echo -e "$Incorrect_Mode_Message" ; exit 1 ; fi

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
Insufficient_Foundings_Message='
The Account you selected does not have enough money for that transaction. Sorry :(
'

if [[ "$1" == 'purchase' ]]
then
Purchase_Flow() {
		if [[ $# -ne 2 ]]
		then
				if [[ ${1+IsSet} != 'IsSet' ]] ; then echo 'Missing arguments for purchase: Account Name, Price' > /dev/stderr
				elif [[ ${2+IsSet} != 'IsSet' ]] ; then echo 'Missing argument for purchase: Price' > /dev/stderr
				elif [[ ${3+IsSet} = 'IsSet' ]] ; then echo 'Extra arguments were supplied for purchase. Aborting just in case' > /dev/stderr
				fi
				exit 2
		fi

		if ! . ~/moneybook/lib/Account_Methods.bash
		then
				echo "Couldn't source \`~/moneybook/bin/Account_Methods.bash\` file containing necessary proceedures to treat Accounts." > /dev/stderr
				return 99
		fi

		declare -r Account_Name=${1}
		declare -r Purchase_Value=${2}
		declare -i Account_Current_Foundings
		declare -i Remaining_Account_Foundings

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
		if [[ ! $Remaining_Account_Foundings -gt 0 ]] ; then echo "$Insufficient_Foundings_Message" > /dev/stderr ; exit 0 ; fi
	
		read -n 1 -p 'Do you wish to continue? Y/N: ' ; echo
		if [[ "${REPLY,,}" != y && "${REPLY,,}" != n ]] ; then echo 'Invalid option, aborting.' > /dev/stderr ; exit 5 ; fi
		if [[ "${REPLY,,}" == n ]]
		then
				echo 'Purchase cancelled'
				exit 1
		fi
	
		# Commit the purchase
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
		if [[ ${3+IsSet} = 'IsSet' ]] ; then echo "Couldn't separate the money, exceeding arguments were passed. Aborting just in case." > /dev/stderr ; return 4 ; fi
		if [[ ! "$1" =~ [0-9]+$ ]] ; then echo "Couldn't parse the second argument as a positive integer." > /dev/stderr ; return 5 ; fi

		declare -i Income="$1"
		declare Expense_Name="$2"
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

		# Commit the separation
		if ! Write_Expense "$Expense_Name" "$Postoperation_Expense_Funds"
		then
				echo "Couldn't write \`${Postoperation_Expense_Funds}\` to Expense \`${Expense_Name}\`." > /dev/stderr
				exit 3
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
		if ! . ~/moneybook/lib/Expense_Methods.bash
		then
				echo "Couldn't source \`~/moneybook/lib/Expense_Methods.bash\` file containing necessary proceedures to treat Fixed Expenses. Status: 2" > /dev/stderr
				return 2
		fi

		if [[ ${2+IsSet} != 'IsSet' ]]
		then
				echo "Couldn't pay expense, missing argument: Expense name. Status: 3" > /dev/stderr
				return 3
		fi
		
		declare Expense_Name="$2"
		declare +i Payment_Cost
		declare -i Expense_Funds
		declare -i Postransaction_Expense_Funds

		local +r -i Name_Is_Expense_Status=$( Name_Is_Expense "$Expense_Name" 2> /dev/null ; echo $? ) # it would be nice to be able to invoke `Name_Is_Expense --echo "$Expense_Name" 2> /dev/null` to echo its exit status directly
		if ! ( return $Name_Is_Expense_Status )
		then
				if [[ $Name_Is_Expense_Status -eq 2 ]] ; then echo "Couldn't pay expense, \`${Expense_Name}\`, no such file or directory."
				else echo "Couldn't pay expense, the name \`${Expense_Name}\` is not a correct Fixed Account file. Status: 4" > /dev/stderr ; fi
				return 4
		fi
		unset Name_Is_Expense_Status
		
		## Assign the variables
		# Define the cost of the payment
		if [[ ${3:+IsPresent} = 'IsPresent'  ]]
		then
				if [[ ! "$3" =~ [0-9]+$ ]]
				then
						echo "Couldn't parse the cost of the payment as a positive integer. Status: 5" > /dev/stderr
						return 5
				fi
				declare -i Payment_Cost="$3"
		else
				if ! Payment_Cost="$( Read_Expense_Budget "$Expense_Name" )"
				then
						echo "Couldn't get the budget of the Expense to use it as the cost of the payment. Status: 6" > /dev/stderr
						return 6
				fi
				declare -i Payment_Cost
		fi
		if ! Expense_Funds="$( Read_Expense_Funds "$Expense_Name" )"
		then
				echo "; Couldn't get current funds of the Expense. Status: 7"
				return 7 
		fi
		Postransaction_Expense_Funds=$(( Expense_Funds - Payment_Cost ))

		## Display payment screen
		Payment_Message="
		The payment of \`${Payment_Cost}\` will be done over the Fixed Expense \`${Expense_Name}\`\n
		\t	Expense funds: ${Expense_Funds}\n
		\t	Payment Cost: ${Payment_Cost}\n
		\t	Remaining funds after payment: ${Postransaction_Expense_Funds}\n
		"
		echo -e $Payment_Message
		unset Payment_Message

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

		echo 'Payment committed successfully :)'
		return 0

		}
		Payment_Flow "$@"
		exit $?
fi

# ------------------------------------------------------------------------
