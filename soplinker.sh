port=8908
SW=$(expr $(tput cols) - 5)
#--
selectItem() {
	declare -a array=("${!1}")
	if	[ ${#array[@]} -eq 0 ]; then
		echo -1
	else
		for((i=0;i<${#array[@]};i++)); do
			echo "$(printf "%2d." $((i+1)))" ${array[$i]} >&2
		done
		while(true); do
			read -p "--> " x >&2
			echo ${x} | grep -E '^[0-9]+$' > /dev/null && [ ${x} -ge 0 ] && [ ${x} -le ${#array[@]} ] && echo ${x} && break
			echo "Error: Incorrect input, try again..." >&2
		done
	fi
}
#--
YesNo() {
	while(true); do
		read userConfirm >&2
		[ -z ${userConfirm} ] && return ${1}
		case $userConfirm in
			yes|YES|y|Y)
				return 0;;
			no|NO|n|N)
				return 1;;
		esac
		echo "Incorrect input, try again..." >&2
	done
}
#--
isInstalled() {
	which "$1" > /dev/null || {
		echo "Please install '$1' and re-run the script." 1>&2
		return 1;
	}
	return 0
}
# Sanity check
#--------------
if [ $# -lt 1 ]; then
	echo "Usage: $(basename $0) <URL of a webpage with sopcast links>" 1>&2
	exit 10
fi
url="$1"
isInstalled "html2text"		|| exit 1
isInstalled "sp-sc-auth"	|| exit 2
isInstalled "xsltproc"		|| exit 3
isInstalled "wget"			|| exit 4

# Main loop
#-----------
while true
do
	#-- Retrieve webpage and save it in a temp file
	wget --no-cache ${url} -O- 2> /dev/null | xsltproc --html minimal.xsl - 2> /dev/null | html2text > $$
	#-- Let user select a SOP link
	printf "\nSelect Sopcast link to stream into VLC player (Ctrl+C to quit):\n"
	if [ $(cat $$ | wc -l) -gt 0 ]; then
		temp=($(cat $$))
		rm -rf $$ > /dev/null
		printf "%2d. Auto selection (start from the frst to find a good one).\n" "0"
		result=$(selectItem temp[@])
		echo "Starting Sopcast broadcaster"
		if [ $result -eq 0 ]; then 
			echo "If you see the same link for longer than 5 seconds it is a good change that link is working."
			echo "In this case open http://<ip of this host>:$port/tv.asf network streami in your favorite player."
			for((i=0;i<${#temp[@]};i++)); do
				printf "\r%${SW}s\rTrying: [%2d/%2d] %s..." "" "$((i+1))" "${#temp[@]}" "${temp[i]}" 
				sp-sc-auth $(echo ${temp[$i]}) 0 $port 1> /dev/null 2> /dev/null || { continue; }
			done	
			echo ""
		else
			echo "This process may fail if link is no longer valid (e.g. banned)."
			echo "In case of success (you continue seeing this message) you need to start VLC (or any other) player"
			echo "and open http://<ip of this host>:$port/tv.asf network stream. To quit broadcasting you need to hit Ctrl+C to start over or quit."
			sp-sc-auth $(echo ${temp[$((result-1))]}) 0 $port 1> /dev/null 2> /dev/null || { echo "" && continue; }
		fi
		unset temp	
	fi
done
	
#-- Finalize
[ $result -eq 0 ] || echo ""
