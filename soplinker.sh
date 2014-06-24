#!/bin/bash

# SHFLAGS related
#-----------------
[ ! -f shflags ] && wget -q http://shflags.googlecode.com/svn/trunk/source/1.0/src/shflags
#-- source shflags from current directory
. ./shflags
DEFINE_boolean 'verbose' false 'enable verbose output' 'v'
DEFINE_boolean 'autoplay' false 'autostart video player' 'a'
DEFINE_integer 'port' 8908 'port number to be used video streaming' 'p'
FLAGS_HELP="USAGE: $(basename $0) [flags] <URL of a webpage with sopcast links>"
#-- parse the command-line
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"

# Local variables
#-----------------
SW=$(expr $(tput cols) - 5)

# Functions
#-----------
#--
# colorize stdin according to parameter passed (GREEN, CYAN, BLUE, YELLOW)
colorize() {
	bold="0"
	GREEN="\033[$bold;32m"
	CYAN="\033[$bold;36m"
	GRAY="\033[$bold;37m"
	BLUE="\033[$bold;34m"
	RED="\033[$bold;31m"
	YELLOW="\033[$bold;33m"
	NORMAL="\033[m"
	color=\$${1:-NORMAL}
	# activate color passed as argument
	echo -ne "`eval echo ${color}`"
	# read stdin (pipe) and print from it:
	# cat
	shift; printf "$*"
	# Note: if instead of reading from the pipe, you wanted to print
	# the additional parameters of the function, you could do:
	# shift; echo $*
	# back to normal (no color)
	echo -ne "${NORMAL}"
}
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
			[ -z "$x" ] && continue
			echo ${x} | grep -E '^[0-9]+$' > /dev/null && [ ${x} -ge 0 ] && [ ${x} -le ${#array[@]} ] && echo ${x} && break
			echo "$(colorize RED 'ERROR:') Incorrect input, try again..." >&2
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
		echo "$(colorize RED 'ERROR:') missing dependence(s). Please install '$1' and re-run the script." 1>&2
		return 1;
	}
	return 0
}
# Sanity check
#--------------
#-- Check for the presence of URL
[ ${FLAGS_help} -eq ${FLAGS_TRUE} ] && exit 0
if [ $# -lt 1 ]; then
	flags_help
	exit 10
fi
url="$1"
#-- Check for the availability of the port to be used by sp-sc-auth
if lsof -i :${FLAGS_port} > /dev/null; then
	echo "$(colorize RED ERROR:) Port '${FLAGS_port}' is in use by '$(lsof -i :${FLAGS_port} | tail -n +2 | awk '{printf "%s (%s)\n",$1,$2}')' process." 1>&2
	exit 20
fi
#-- Check for the presence of necessary utils
isInstalled "html2text"	  || exit 11
isInstalled "sp-sc-auth"	 || exit 12
isInstalled "xsltproc"		|| exit 13
isInstalled "wget"			 || exit 14
isInstalled "lsof"          || exit 15
#-- Check if -a option is specified
[ ${FLAGS_autoplay} -eq ${FLAGS_TRUE} ] && echo "$(colorize GREEN 'INFO:') Option -a (autostart video player) is not yet implemented."

# Main loop
#-----------
flag=0;
while [ $flag -eq 0 ]
do
	#-- Retrieve webpage and save it in a temp file
	wget --no-cache ${url} -O- 2> /dev/null | xsltproc --html minimal.xsl - 2> /dev/null | html2text | uniq > $$
	#-- Let user select a SOP link
	if [ $(cat $$ | wc -l) -gt 0 ]; then
		printf "Select Sopcast link to stream out (hit <Ctrl+C> to quit):\n"
		temp=($(cat $$))
		rm -rf $$ > /dev/null
		printf "%2d. %s\n" "0" "$(colorize YELLOW 'Auto selection (start from the frst to find a good one).')"
		result=$(selectItem temp[@]) || break
		echo "Open $(colorize CYAN "http://<ip of this host>:${FLAGS_port}/tv.asf") network stream in your favorite media player."
		if [ $result -eq 0 ]; then
			echo "Hit <Ctrl+\> and then <Ctrl+C> to enforce channel switch. Alternatively hit <Ctrl+C> to stop streaming."
			trap 'continue' QUIT
			trap 'echo ""; break'    INT
			for((i=0;i<${#temp[@]};i++)); do
				printf "\r%${SW}s\rTrying: [%2d/%2d] %s..." "" "$((i+1))" "${#temp[@]}" "${temp[i]}"
				if [ ${FLAGS_verbose} -eq ${FLAGS_FALSE} ]; then
					sp-sc-auth "${temp[$i]}" 0 "${FLAGS_port}" 1> /dev/null 2> /dev/null
				else
					sp-sc-auth "${temp[$i]}" 0 "${FLAGS_port}"
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
