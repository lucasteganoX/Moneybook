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

		# Put together the file contents
		declare Account_File_Content
		read -d '' Account_File_Content <<- EOF
		# This is a moneybook Account file
		Share=${Account_Share}
		Foundings=${Account_Funds}

		${Account_Message-}
		EOF
		    # can't believe a year has past and I still haven't fixed the misspell "foundings"

		# Write the file
		if [[ ! -w ~/moneybook ]]
		then
				echo "$Couldn't create Account, lack of write permission over the directory where Accounts are stored."
				return 5
		fi
		echo "$Account_File_Content" > ~/moneybook/"$Account_Name"
		unset Account_File_Content

		# Incorrect share among Accounts warning
		declare -i Total_Share_Percentage
		for Share in $( Print_Account_Shares ) ; do Total_Share_Percentage+="$Share" ; done
		Total_Share_Percentage+="$Account_Share"
		if [[ "$Total_Share_Percentage" -ne 100 ]]
		then
				declare -i Difference=$(( 100 - Total_Share_Percentage ))
				declare -i Absolute_Difference=${Difference#-}
				if [[ "$Difference" -gt 0 ]]
				then echo "The total share among Accounts, taking this one into consideration, undershoots a 100% by ${Absolute_Difference} percent."
				else echo "The total share among Accounts taking this one into consideration, overshoots a 100% by ${Absolute_Difference} percent."
				fi
				echo "In order to be able to Inject money, the sum of all of your Accounts must sum a 100% of the incoming money. You may still proceed."
				unset Absolute_Difference
				unset Difference
		fi
		unset Total_Share_Percentage
}