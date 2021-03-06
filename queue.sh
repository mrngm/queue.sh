#!/bin/bash

### URLS
LOGINURL="https://marietje-zuid.science.ru.nl/login/"
QUEUEURL="https://marietje-zuid.science.ru.nl/api/queue"
REFERER="https://marietje-zuid.science.ru.nl/"

### LOGIN
USERFILE="credentials.user"
PASSFILE="credentials.pass"

if [ ! -f "${USERFILE}" ]; then
	touch "${USERFILE}"
	read -erp "Username: " USER
	echo -n ${USER} > ${USERFILE}
	echo "... saved!"
fi
if [ ! -f "${PASSFILE}" ]; then
	touch "${PASSFILE}"
	chmod 600 "${PASSFILE}"
	read -ersp "Password: " PASS
	echo -n ${PASS} > ${PASSFILE}
	echo "... saved!"
fi

VERBOSE=0
### Clean cookiejar
rm ./koekjes

### Store some cookies and get the CSRFM token
CSRFM=`curl -sS -b ./koekjes -c ./koekjes -H "Referer: ${REFERER}" "${LOGINURL}" | grep 'csrfmiddlewaretoken' | sed -e "s/^.*value='\(.*\)'.*$/\1/"`

curl -sS -b ./koekjes -c ./koekjes -d "username=$(cat ${USERFILE})" -d "password=$(cat ${PASSFILE})" -d "csrfmiddlewaretoken=${CSRFM}" -H "Referer: ${REFERER}" "${LOGINURL}"


trap exit SIGINT
clear

# "started_at": 1523024189,
# "current_time": 1523024249,
function format_seconds {
	SECS="$1"
	HRS="$(( ${SECS} / 3600 % 3600 ))"
	MIN="$(( ${SECS} / 60 % 60 ))"
	SEC="$(( ${SECS} % 60 ))"
	SECO=${SEC}
	OUT=""
	if [[ ${SEC} -ge 0 && ${SEC} -lt 10 ]]; then
		SECO="0${SEC}"
	fi
	if [[ ${MIN} -ge 0 && ${MIN} -lt 10 && ${HRS} -ge 1 ]]; then
		MIN="0${MIN}"
	fi
	if [[ ${HRS} -ge 1 ]]; then
		OUT="${HRS}:${MIN}:${SECO}"
	else
		OUT="${MIN}:${SECO}"
	fi
	if [[ ${SECS} -lt 0 ]]; then
		OUT="-${OUT}"
	fi
	echo "${OUT}"
}

while true; do
	Q=`curl -sS -b ./koekjes -c ./koekjes -H "Referer: ${REFERER}" "${QUEUEURL}"`
	NOW=`echo ${Q} | jq -r '.current_time'`
	START=`echo ${Q} | jq -r '.started_at'`
	DURATION=`echo ${Q} | jq -r '.current_song.song.duration'`
	TIMELEFT="$(( ${DURATION} - (${NOW} - ${START}) ))"
	CURRREQ=`echo ${Q} | jq -r '.current_song | .requested_by'`
	CURRART=`echo ${Q} | jq -r '.current_song | .song.artist'`
	CURRTIT=`echo ${Q} | jq -r '.current_song | .song.title'`
	TL=$(format_seconds ${TIMELEFT})
	PREV=${TIMELEFT}
	QLIST=""
	UNTIL=${PREV}
	LINESUSED=3
	while read item; do
		REQ=`echo ${item} | cut -d '%' -f 1`
		ART=`echo ${item} | cut -d '%' -f 2`
		TIT=`echo ${item} | cut -d '%' -f 3`
		DUR=`echo ${item} | cut -d '%' -f 4`
		UNTILTL=$(format_seconds ${UNTIL})
		QLIST="${QLIST}\n${REQ}%${ART}%${TIT}%${UNTILTL}"
		PREV=${UNTIL}
		UNTIL="$(( ${PREV} + ${DUR} ))"
		LINESUSED=$(( ${LINESUSED} + 1))
		if [[ ${LINESUSED} -eq $(tput lines) ]]; then
			break
		fi
	done < <(echo ${Q} | jq -r '.queue | .[] | .requested_by + "%" + .song.artist + "%" + .song.title + "%" + (.song.duration | tostring)')
	sleep 1
	printf "\033c"
	HDR=""
	if [[ $VERBOSE -eq 1 ]]; then
		HDR="Requested by%Artist%Title%Time left\n\n"
	fi
	echo -e "${HDR}${CURRREQ}%${CURRART}%${CURRTIT}%Playing now!\n${QLIST}" | column -s '%'  -t -e -c $(tput cols)
done
