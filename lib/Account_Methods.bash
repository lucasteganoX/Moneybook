File_Is_Account() { # Abstract Synopsis: File_Is_Account PresuntAccountFilePath # returns: 0 if file is an Account file, 1 if it is not.
		# Based on the Account file specification
		declare File_Path="$1"

		if [[ ! -f "$File_Path" ]] ; then return 1 ; fi
		if [[ ! -r "$File_Path" ]] ; then return 1 ; fi
		if [[ ! "$( head --lines=1 "$File_Path" )" =~ ^'# This is a moneybook Account file'[[:blank:]]*$ ]] ; then return 1 ; fi
		if [[ ! -n "$( grep -E 'Foundings=[0-9]+[[:blank:]]*$' "$File_Path" )" ]] ; then return 1 ; fi
		if [[ ! -n "$( grep -E 'Share=[0-9]+[[:blank:]]*$' "$File_Path" )" ]] ; then return 1 ; fi
		return 0
}

Read_Account() { # Read_Account MyFooAccountName # echoes: Foundings of the Account(integer value) or nothing if an error occurred # returns: 0 if ok, 1 if other than 1 argument was passed, 2 if the account has a non integer value(including if the file is empty)
		if [[ $# -ne 1 ]] ; then return 1 ; fi

		declare -r Account_Name="$1"
        declare -i Account_Foundings

        Get_Foundings() { # Get_Foundings MyAccountName # echoes: Foundings of specified account(Integer)
        		declare -r Account_Name=$1
        		declare -i Foundings
        		Foundings=$( grep --color=never 'Foundings=' ~/moneybook/"$Account_Name" | cut --field=2 --delim='=' )
        		echo $Foundings
        }

        if [[ ! -f ~/moneybook/"$Account_Name" ]] ; then return 2 ; fi
		if ! File_Is_Account "$Account_Name" ; then return 3 ; fi
        if [[ ! "$( Get_Foundings "$Account_Name" )" =~ ^[0-9]+$ ]] ; then return 4 ; fi

        Account_Foundings=$( Get_Foundings "$Account_Name" )
        echo $Account_Foundings && return 0
}

Write_Account() { # Write_Account MyFooAccount MyNewIntegerValueFoundings # returns: 0 if everything is ok, 1 if any but two arguments were passed, 2 if the Account file of the specified name could not be found, 3 if the content of the Account file is any but an integer number(including if the file is empty)
		declare -r Account_Name="$1"
		declare -r New_Foundings=$2

		if [[ $# -ne 2 ]] ; then return 1 ; fi
		if [[ ! -f ~/moneybook/"$Account_Name" ]] ; then return 2 ; fi
		if [[ ! $New_Foundings =~ ^[0-9]+$ ]] ; then return 3 ; fi

		# echo $New_Foundings > "$Account_Name"
		sed --in-place --follow-symlinks "s/Foundings=.*$/Foundings=${New_Foundings}/" ~/moneybook/"$Account_Name" || return 4
		return 0
}

Read_Account_Share() { # Read_Account_Share MyAccountName # returns: 0 if ok, 1 if file was not found and 2 if the value was not an integer # echoes: Integer percentage of money associated to the account
		declare -r Account_Name="$1"
		declare -i Percentage

		if [[ ! -f "$Account_Name" ]] ; then return 1 ; fi
		# input integer check
		Percentage=$( grep --color=never 'Share=' "$Account_Name" | cut --field=2 --delim='=' )

		if [[ ! "$Percentage" =~ ^[0-9]+$ ]] ; then return 2 ; fi
		echo $Percentage
		return 0
}

