#!/usr/bin/env bash

RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
api_domain='bash.ws'
error_code=1

function increment_error_code {
    error_code=$((error_code + 1))
}

function echo_bold {
    echo -e "${BOLD}${1}${NC}"
}

function echo_error {
    (>&2 echo -e "${RED}${1}${NC}")
}

function program_exit {
    command -v $1 > /dev/null
    if [ $? -ne 0 ]; then
        echo_error "Please, install \"$1\""
        exit $error_code
    fi
    increment_error_code
}


function check_internet_connection {
    curl --silent --head  --request GET "https://${api_domain}" | grep "200 OK" > /dev/null
    if [ $? -ne 0 ]; then
        echo_error "No internet connection."
        exit $error_code
    fi
    increment_error_code
}

function print_servers {

    if (( $jq_exists )); then

        echo ${result} | \
            jq  --monochrome-output \
            --raw-output \
            ".[] | select(.type == \"${1}\") | \"\(.ip)\(if .country_name != \"\" and  .country_name != false then \" [\(.country_name)\(if .asn != \"\" and .asn != false then \" \(.asn)\" else \"\" end)]\" else \"\" end)\""

    else

        while IFS= read -r line; do
            if [[ "$line" != *${1} ]]; then
                continue
            fi

            ip=$(echo $line | cut -d'|' -f 1)
            code=$(echo $line | cut -d'|' -f 2)
            country=$(echo $line | cut -d'|' -f 3)
            asn=$(echo $line | cut -d'|' -f 4)

            if [ -z "${ip// }" ]; then
                 continue
            fi

            if [ -z "${country// }" ]; then
                 echo "$ip"
            else
                 if [ -z "${asn// }" ]; then
                     echo "$ip [$country]"
                 else
                     echo "$ip [$country, $asn]"
                 fi
            fi
        done <<< "$result"

    fi
}

program_exit curl
program_exit ping
program_exit mail
check_internet_connection

if command -v jq &> /dev/null; then
    jq_exists=1
else
    jq_exists=0
fi

if hash shuf 2>/dev/null; then
    id=$(shuf -i 1000000-9999999 -n 1)
else
    id=$(jot -w %i -r 1 1000000 9999999)
fi

if (( $jq_exists )); then
    format="json"
else
    format="txt"
fi

result=$(curl --silent "https://${api_domain}/email-leak-test/test/${id}?${format}")

mail -s "Test" ${id}@bash.ws  < /dev/null > /dev/null

for (( ; ; ))
do
    result=$(curl --silent "https://${api_domain}/email-leak-test/test/${id}?${format}")

    is_done=$(print_servers "done")

    if [[ $is_done == *"1"* ]]; then

        break
    fi

done

echo_bold "Your IP:"
print_servers "ip"

echo ""
ips_count=$(print_servers "mail" | wc -l)
if [ ${ips_count} -eq "0" ];then
    echo_bold "No IPs found in mail header"
else
    if [ ${ips_count} -eq "1" ];then
        echo_bold "Mail header has got ${ips_count} IP:"
    else
        echo_bold "Mail header has got ${ips_count} IPs:"
    fi
    print_servers "mail"
fi

echo ""
echo_bold "Conclusion:"
print_servers "conclusion"

exit 0
