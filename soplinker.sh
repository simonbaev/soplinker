#!/bin/bash

# SHFLAGS related
#-----------------
[ ! -f shflags ] && wget -q http://shflags.googlecode.com/svn/trunk/source/1.0/src/shflags
#-- source shflags from current directory
. ./shflags
DEFINE_boolean 'verbose' false 'enable verbose output' 'v'
DEFINE_boolean 'autoplay' false 'autostart video player' 'a'
DEFINE_integer 'port' 8908 'port number to be used video streaming' 'p'
#-- parse the command-line
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"

# Local variables
#-----------------
SW=$(expr $(tput cols) - 5)

# Functions
#-----------
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
			[ -z "$x" ] && continue
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
#--
trapHandler() {
	pgrep sp-sc-auth
}
# Sanity check
#--------------
if [ $# -lt 1 ]; then
	echo "Usage: $(basename $0) <URL of a webpage with sopcast links>" 1>&2
	exit 10
fi
url="$1"
isInstalled "html2text"	 || exit 1
isInstalled "sp-sc-auth"	|| exit 2
isInstalled "xsltproc"	  || exit 3
isInstalled "wget"			|| exit 4

# Main loop
#-----------
trap
flag=0;
while [ $flag -eq 0 ]
do
	unset pid
	#-- Retrieve webpage and save it in a temp file
	wget --no-cache ${url} -O- 2> /dev/null | xsltproc --html minimal.xsl - 2> /dev/null | html2text | uniq > $$
	#-- Let user select a SOP link
	if [ $(cat $$ | wc -l) -gt 0 ]; then
		printf "\nSelect Sopcast link to stream out (Ctrl+C to quit):\n"
		temp=($(cat $$))
		rm -rf $$ > /dev/null
		printf "%2d. Auto selection (start from the frst to find a good one).\n" "0"
		result=$(selectItem temp[@]) || break
		echo "Open http://<ip of this host>:$port/tv.asf network stream in your favorite media player."
		if [ $result -eq 0 ]; then
			echo "Hit Ctrl+\ and then Ctrl+C to enforce channel switch, Hit Ctrl+C to stop streaming."
			trap 'continue' QUIT
			trap 'break'    INT
			for((i=0;i<${#temp[@]};i++)); do
				printf "\r%${SW}s\rTrying: [%2d/%2d] %s..." "" "$((i+1))" "${#temp[@]}" "${temp[i]}"
				if [ ${FLAGS_verbose} -eq ${FLAGS_FALSE} ]; then
					sp-sc-auth "${temp[$i]}" 0 "${FLAGS_port}" 1> /dev/null 2> /dev/null || { continue; }
				else
					sp-sc-auth "${temp[$i]}" 0 "${FLAGS_port}" || { continue; }
				fi
			done
			trap - INT QUIT
		else
			echo "Hit Ctrl+C to stop streaming and see list of links again."
			if [ ${FLAGS_verbose} -eq ${FLAGS_FALSE} ]; then
				sp-sc-auth "${temp[$((result-1))]}" 0 "${FLAGS_port}" 1> /dev/null 2> /dev/null || { echo "" && continue; }
			else
				sp-sc-auth "${temp[$((result-1))]}" 0 "${FLAGS_port}" || { echo "" && continue; }
			fi
		fi
		unset temp
	else
		echo "Specified webpage, i.e '$url' doesn't seem to contain sopcast links." 1>&2
		echo "Would you like to try it again? [y/N]:" 1>&2
		YesNo 1 || break
	fi
done

#-- Finalize
echo ""
