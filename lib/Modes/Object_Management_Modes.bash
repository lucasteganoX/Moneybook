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
}