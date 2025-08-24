# Absolute methods
## These are functions that operate over files directly given to them. One might say they are proper "methods".
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

# Relative methods
## These are functions that operate over a given name. Which is expected to correspond to a file under the root dir of the program.
Read_Account() { # Read_Account MyFooAccountName # echoes: Foundings of the Account(integer value) or nothing if an error occurred # returns: 0 if ok, 1 if other than 1 argument was passed, 2, if the Account file reached couldn't be evaluated as a moneybook Account file, 3 if the account has a non integer value(including if the file is empty)
		if [[ $# -ne 1 ]] ; then return 1 ; fi

		Get_Foundings() { # Get_Foundings MyAccountPath # echoes: Foundings of specified account(Integer)
				declare -r Account_File_Path="$1"
        		declare +i Foundings
        		Foundings="$( grep --color=never 'Foundings=' "$Account_File_Path" | cut --field=2 --delim='=' )"
        		echo $Foundings
        }

		declare -r Account_Name="$1"
		declare -r Account_File_Path=~/moneybook/"${Account_Name}"
        declare -i Account_Foundings

        if ! File_Is_Account "$Account_File_Path" ; then return 2 ; fi
        Account_Foundings="$( Get_Foundings "$Account_File_Path" )"
        if [[ ! "$Account_Foundings" =~ ^[0-9]+$ ]] ; then return 3 ; fi
        echo $Account_Foundings
		return 0
}

Write_Account() { # Write_Account MyFooAccountName MyNewIntegerValueFoundings # returns: 0 if everything is ok, 1 if any but two arguments were passed, 2 if the associated file couldn't be evaluated as a moneybook Account file, 3 if the second argument is any but an integer number and 4 if the write itself failed somehow
		if [[ $# -ne 2 ]] ; then return 1 ; fi

		declare -r Account_Name="${1}"
		declare -r Account_File_Path=~/moneybook/"${Account_Name}"
		declare -r New_Foundings=${2}

		if ! File_Is_Account "$Account_File_Path" ; then return 2 ; fi
		if [[ ! "$New_Foundings" =~ ^-?[0-9]+$ ]] ; then return 3 ; fi
		if ! sed --in-place --follow-symlinks "s/Foundings=.*$/Foundings=${New_Foundings}/" "$Account_File_Path" ; then return 4 ; fi
		return 0
}

Read_Account_Share() { # Read_Account_Share MyAccountName # returns: 0 if ok, 1 if file didn't make it as an moneybook Account file and 2 if the value was not an integer # echoes: Integer percentage of money associated to the Account named as specified under the root dor of moneybook
		declare -r Account_Name="$1"
		declare -r Account_File_Path=~/moneybook/"${Account_Name}"
		declare -i Percentage

		if ! File_Is_Account "$Account_File_Path" ; then return 1 ; fi
		Percentage=$( grep --color=never 'Share=' "$Account_File_Path" | cut --field=2 --delim='=' )
		if [[ ! "$Percentage" =~ ^[0-9]+$ ]] ; then return 2 ; fi
		echo $Percentage
		return 0
}
