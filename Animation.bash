Bold_Glow () {
		declare -r Message="Payment commited successfully :)"
		declare Get_Letter

		Get_Letter() {
				declare Word="$1"
				declare Letter_Index="$2"

				Get_Letter="${Word:Letter_Index:1}"
		}

		for (( Character_Cell=0 ; Character_Cell<${#Message} ; Character_Cell++ ))
		do
				declare Bold_Esc=$'\e[1m'
				declare Normal_Esc=$'\e[0m'
				Get_Letter "$Message" "$Character_Cell"
				
				if [[ "$Get_Letter" = [[:space:]] ]] ; then continue ; fi
				Letter_Position=$(( Character_Cell + 1 ))
				New_Frame="$( sed "s/./${Bold_Esc}${Get_Letter}${Normal_Esc}/${Letter_Position}" <<< "$Message" )"
				echo -n -e "${New_Frame}\r"
		done
		echo
}