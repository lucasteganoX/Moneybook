#!/bin/bash
Create_Account() {
# Synopsis: Create_Account <String>Account_Name <+Int>Account_Share <Int>Account_Funds [<String?>File_Message]
# Note: The account funds might be negative, positive or zero.
# Note: The file message is a text appended to the account object file to be created. It is not expanded.

		declare Account_Name=${1-}
		declare Account_Share=${2-}
		declare Account_Funds=${3-}
		declare Account_Message=${4-}

		if [[ "$Account_Name" = '' ]] ||
		   [[ "$Account_Share" = '' ]] ||
		   [[ "$Account_Funds" = '' ]]
		then
				echo "Couldn't create Account, not all indispensable attributes were supplied." > /dev/stderr
				return 2
		fi

		# Integer parameters check
		if [[ ! "$Account_Share" =~ ^[0-9]+$ ]]
		then
				echo "Couldn't create Account, the share supplied is not an integer value." > /dev/stderr
				return 2
		fi

		if [[ ! "$Account_Funds" =~ ^(0|-?[1-9][0-9]*)$ ]]
		then
				echo "Couldn't create Account, the funds supplied are not either a positive or negative integer, or zero." > /dev/stderr
				return 2
		fi

		# Import libraries
		if ! . ~/moneybook/lib/Account_Methods.bash
		then
				echo "Couldn't create Account, couldn't import libraries necessary for the creation." > /dev/stderr
				return 3
		fi

		# Check Account name doesn't exist
		declare -a Existing_Account_Names[0]
		Existing_Account_Names=( $( basename --multiple $( Get_Accounts ) ) )

		for Existing_Account_Name in "${Existing_Account_Names[@]}"
		do
				if [[ "$Account_Name" = "$Existing_Account_Name" ]]
				then
						echo "Couldn't create Account, there's already an Account under that name." > /dev/stderr
						return 4
				fi
		done
		unset Existing_Account_Names
}