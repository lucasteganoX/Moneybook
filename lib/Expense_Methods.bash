set -e
Name_Is_Expense() { # Abstract synopsis: Name_Is_Expense MyExpenseFileName # returns: 0 if true, 1 if file was not found or readable, 2 if the head of the file does not match the signature, 3 if no correct Funding line was matched, 4 if no line matched the budget expression, 5 if the budget equals zero # echoes: Error messaje with return state
		if [[ ${1+IsSet} != 'IsSet' ]] ; then echo "Couldn't check for corresponse of name to Expense file, missing argument: Name. Status: 1" ; return 1 ; fi

		declare -r File_Name="$1"
		declare -r File_Path="${HOME}/moneybook/Fixed_Expenses/${File_Name}"
		declare -r Error_Message="Couldn't check whether the name \`${File_Name}\` was a Fixed Expense file. Status:"
		declare Expense_Budget_Line
		declare Expense_Budget

		if [[ ! -r "$File_Path" ]] ; then echo "${Error_Message} 2" > /dev/stderr; return 2 ; fi
		if [[ ! "$( head -n 1 $File_Path )" =~ ^'# This is a Fixed Expending file for the mooneybook program'[[:blank:]]* ]] ; then echo "${Error_Message} 3" > /dev/stderr ; return 3 ; fi
		if ! grep '^Fundings=-\?[0-9]\+[[:blank:]]*' "$File_Path" > /dev/null ; then echo "${Error_Message} 4" > /dev/stderr ; return 4 ; fi
		if ! Expense_Budget_Line="$( grep '^Budget=[0-9]\+' $File_Path 2> /dev/null )" ; then echo "${Error_Message} 5" > /dev/stderr ; return 5 ; fi
		Expense_Budget="$( cut --delim='=' --field=2 <<< $Expense_Budget_Line )"
		if [[ "$Expense_Budget" = 0 ]] ; then echo "${Error_Message} 6" > /dev/stderr ; return 6 ; fi
		return 0
}

Read_Expense_Funds() { # Abstract synopsis: Read_Expense MyFixedExpenseFileName # echoes: Integer fundings of the Fixed Expense to stding, error message + error status code to stderr # returns: 0 if ok, 1 if no expense name was given, 2 if file name couldn't be parsed as an Expense File, 3 if fundings could not be parsed, 4 if fundings could not be parsed as an integer(positive or negative)
		if [[ ${1+IsSet} != 'IsSet' ]] ; then echo "Couldn't read Expense funds, missing parameter: Fixed Expense name. Status: 1" > /dev/stderr ; return 1 ; fi

		declare -r Expense_Name="$1"
		declare -r Expense_Path="${HOME}/moneybook/Fixed_Expenses/${Expense_Name}"
		declare -i Expense_Fundings # Might be negative
		declare -r Error_Message="Couldn't read expense \`${Expense_Name}\`. Status:"

		if ! Name_Is_Expense "$1" ; then echo -n " ; $Error_Message 2" > /dev/stderr ; return 2 ; fi
		Expense_Fundings=$(
		grep --color=never '^Fundings=-\?[0-9]\+[[:blank:]]*' "$Expense_Path" |
		cut --delim='=' --field=2
		)
		if [[ -z "$Expense_Fundings" ]] ; then echo "$Error_Message 3" > /dev/stderr ; return 3 ; fi
		if ! grep '^-\?[0-9]*' > /dev/null <<< "$Expense_Fundings" ; then echo "$Error_Message 4" > /dev/stderr ; return 4 ; fi
		echo "$Expense_Fundings"
		return 0
}

Read_Expense_Budget() { # Abstract synopsis: Read_Expense_Budget MyFixedExpenseName # echoes: The budget of the said Fixed Expense(negative or positive integer) # returns: 0 if ok, 1 if not expense name was given, 2 if the expense test failed
		if [[ ${1+IsSet} != 'IsSet' ]] ; then echo "Couldn't read Expense budget, missing argument: Expense file name. Status: 1" > /dev/stderr ; return 1 ; fi

		declare -r Expense_Name="$1"
		declare -r Expense_Path="${HOME}/moneybook/Fixed_Expenses/${Expense_Name}"
		declare -i Expense_Budget
		declare -r Error_Message="Couldn't read Expense budget for the Expense \`${Expense_Name}\`. Status:"

		if ! Name_Is_Expense "$Expense_Name" ; then echo "$Error_Message 2" > /dev/stderr ; return 2 ; fi
		Expense_Budget="$( grep --color=never '^Budget=' "$Expense_Path" | cut --delim='=' --field=2 )"
		
		echo "$Expense_Budget"
		return 0
}

Write_Expense() { # Abstract synopsis: Write_Expense MyFixedExpenseFileName NewExpenseIntegeFundingValue(might be negative) returns: 0 if ok, 1 if Expense name was not provided, 2 if new fundings were not provided, 3 if Expense File check failed, 4 if write check over the Expense failed, 3 if no new fundings are present(the second argument are the new fundings, 5 if the new fundings couldn't be parsed as a negative or positive integer
		if [[ ${1+IsSet} != 'IsSet' ]] ; then echo "Couldn't write Expense, missing argument: Exense file name. Status: 1" > /dev/stderr ; return 1 ; fi
		if [[ ${2+IsSet} != 'IsSet' ]] ; then "Couldn't write Expense, missing argument: New funding value. Status: 2" ; return 2 ; fi

		declare -r Expense_Name="$1"
		declare -r New_Fundings="$2"
		declare -r Expense_Path="${HOME}/moneybook/Fixed_Expenses/${Expense_Name}"
		declare Expense_Fundings
		declare -r Error_Message="Couldn't write Fixed expense \`${Expense_Name}\`. Status:"

		if ! Name_Is_Expense "$Expense_Name" ; then echo "$Error_Message 3" > /dev/stderr ; return 3 ; fi
		if [[ ! -w "$Expense_Path" ]] ; then echo "$Error_Message 4" > /dev/stderr ; return 4 ; fi
		if ! grep '^-\?[0-9]\+' > /dev/null <<< "$New_Fundings" ; then echo "$Error_Message 5" > /dev/stderr ; return 4 ; fi

		sed -i "s/Fundings=-\?[0-9]*/Fundings=${New_Fundings}/" "$Expense_Path"
		return 0
}

Expense_Is_Fulfilled() { # Abstract synopsis: Expense_Is_Fulfilled MyExpenseName
		if [[ ${1+IsSet} != 'IsSet' ]] ; then echo "Couldn't check if Expense is fulfilled, missing argument: Expense name. Status: 2" ; return 2 ; fi
		declare -r Expense_Name="$1"

		[[ "$( Read_Expense_Funds "$Expense_Name" )" -eq "$( Read_Expense_Budget "$Expense_Name" )" ]]
}

