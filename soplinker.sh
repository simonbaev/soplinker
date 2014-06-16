#!/bin/bash

# local definitions
rport=8908
lport=3908
#--
selectItem() {
	declare -a array=("${!1}")
	if	[ ${#array[@]} -eq 0 ]; then
		echo -1
	else
		for((i=0;i<${#array[@]};i++)); do
			echo $(printf "%2d." $((i+1))) ${array[$i]} >&2
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
isInstalled "html2text"  || exit 1
isInstalled "sp-sc-auth" || exit 2
isInstalled "xsltproc"   || exit 3
#--
while read -p "Enter URL of a webpage with Sopcast links (Ctrl+D to quit): " url
do
	#-- Check if nothin is entered
	[ -z "$url" ] && continue;
	#-- Retrieve webpage and save it in a temp file
	wget ${url} -O- 2> /dev/null | xsltproc --html minimal.xsl - 2> /dev/null | html2text > $$
	#-- Let user select a SOP link
	printf "\nSelect Sopcast link to stream into VLC player (or '0' to quit):\n"
	if [ $(cat $$ | wc -l) -gt 0 ]; then
		temp=($(cat $$))
		result=$(selectItem temp[@])
		[ $result -eq 0 ] && break
		echo "Starting Sopcast broadcaster..."
		echo "This process may fail if link is no longer valid (e.g. banned)."
		echo "In case of success (you continue seeing this message) you need to start VLC (or any other) player"
		echo "and open http://<ip of this host>:$rport/tv.asf network stream. To quit broadcasting you need to hit Ctrl+C to start over or quit."
		sp-sc-auth $(echo ${temp[$((result-1))]}) $lport $rport > /dev/null || { echo "" && continue; }
		unset temp	
	fi
done
	
#-- Finalize
[ $result -eq 0 ] || echo ""
[ -f $$ ] && rm $$ 
