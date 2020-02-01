#!/bin/bash

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

program_exit curl
program_exit ping
program_exit jq
program_exit mail
check_internet_connection

id=$(shuf -i 1000000-9999999 -n 1)

result=$(curl --silent "https://${api_domain}/emailleak/test/${id}?json")

mail -s "Test" ${id}@bash.ws  < /dev/null > /dev/null

for (( ; ; ))
do
    result=$(curl --silent "https://${api_domain}/emailleak/test/${id}?json")

    is_done=$(jq 'map(select(.type == "done"))' <<< ${result} | jq '.[0].done')

    if [[ "$is_done" == "\"1\"" ]]; then

        break
    fi

done

function print_servers {
    jq  --monochrome-output \
        --raw-output        \
        ".[] | select(.type == \"${1}\") | \"\(.ip)\(if .country_name != \"\" and  .country_name != false then \" [\(.country_name)\(if .asn != \"\" and .asn != false then \" \(.asn)\" else \"\" end)]\" else \"\" end)\"" \
        <<< ${result}
}

echo_bold "Your IP:"
print_servers "ip"

echo ""
ips_count=$(jq 'map(select(.type == "mail")) | length' <<< ${result})
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
jq --monochrome-output --raw-output '.[] | select(.type == "conclusion") | .ip' <<< ${result}

exit 0
