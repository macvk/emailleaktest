#!/bin/sh

RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
api_domain='bash.ws'
error_code=1

increment_error_code() {
    error_code=$((error_code + 1))
}

echo_bold() {
    printf '%b\n' "${BOLD}${1}${NC}"
}

echo_error() {
    printf '%b\n' "${RED}${1}${NC}" >&2
}

require_command() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo_error "Please, install \"$1\""
        exit "$error_code"
    fi

    increment_error_code
}

check_internet_connection() {
    if ! curl --silent --show-error --fail --head "https://${api_domain}" > /dev/null; then
        echo_error 'No internet connection.'
        exit "$error_code"
    fi

    increment_error_code
}

request_test_id() {
    if ! id=$(curl --silent --show-error --fail "https://${api_domain}/id"); then
        echo_error "Unable to obtain a test ID from ${api_domain}."
        exit "$error_code"
    fi

    case "$id" in
        *[!A-Za-z0-9]*)
            echo_error "Invalid test ID returned by ${api_domain}."
            exit "$error_code"
            ;;
    esac

    if [ "${#id}" -ne 16 ]; then
        echo_error "Invalid test ID returned by ${api_domain}."
        exit "$error_code"
    fi
}

request_result() {
    if ! result=$(curl --silent --show-error --fail "https://${api_domain}/email-leak-test/test/${id}?${format}"); then
        echo_error 'Unable to retrieve the email leak test result.'
        exit "$error_code"
    fi

    if [ "$format" = json ]; then
        response_error=$(printf '%s\n' "$result" | jq --raw-output 'if type == "object" then .error // empty else empty end' 2>/dev/null || :)

        if [ -n "$response_error" ]; then
            echo_error "$response_error"
            exit "$error_code"
        fi

        if ! printf '%s\n' "$result" | jq --exit-status 'type == "array"' > /dev/null 2>&1; then
            echo_error 'Invalid response from the email leak test.'
            exit "$error_code"
        fi
    else
        case "$result" in
            ERROR:*)
                echo_error "$result"
                exit "$error_code"
                ;;
        esac
    fi
}

print_servers() {
    record_type=$1

    if [ "$jq_exists" -eq 1 ]; then
        printf '%s\n' "$result" |
            jq --monochrome-output \
                --raw-output \
                --arg record_type "$record_type" \
                '.[] | select(.type == $record_type) |
                    if $record_type == "done" then .done
                    else . as $record |
                        [$record.city_name, $record.region_name, $record.country_name, $record.asn] |
                        map(select(. != null and . != false and . != "")) as $location |
                        "\($record.ip)\(if ($location | length) > 0 then " [\($location | join(", "))]" else "" end)"
                    end'
        return
    fi

    printf '%s\n' "$result" |
        while IFS='|' read -r ip code country asn type city region; do
            [ "$type" = "$record_type" ] || continue

            case "$ip" in
                *[![:space:]]*) ;;
                *) continue ;;
            esac

            location=''
            for value in "$city" "$region" "$country" "$asn"; do
                case "$value" in
                    *[![:space:]]*)
                        if [ -n "$location" ]; then
                            location="${location}, ${value}"
                        else
                            location=$value
                        fi
                        ;;
                esac
            done

            if [ -n "$location" ]; then
                printf '%s [%s]\n' "$ip" "$location"
            else
                printf '%s\n' "$ip"
            fi
        done
}

require_command curl
require_command mail
check_internet_connection

if command -v jq > /dev/null 2>&1; then
    jq_exists=1
else
    jq_exists=0
fi

request_test_id

if [ "$jq_exists" -eq 1 ]; then
    format=json
else
    format=txt=2
fi

request_result

if ! mail -s 'Test' "${id}@bash.ws" < /dev/null > /dev/null; then
    echo_error 'Email was not sent.'
    exit "$error_code"
fi

while :; do
    request_result
    is_done=$(print_servers done)

    case "$is_done" in
        *1*) break ;;
    esac

    sleep 1
done

echo_bold 'Your IP:'
print_servers ip

printf '\n'
ips_count=$(print_servers mail | wc -l)
if [ "$ips_count" -eq 0 ]; then
    echo_bold 'No IPs found in mail header'
elif [ "$ips_count" -eq 1 ]; then
    echo_bold "Mail header has got ${ips_count} IP:"
    print_servers mail
else
    echo_bold "Mail header has got ${ips_count} IPs:"
    print_servers mail
fi

printf '\n'
echo_bold 'Conclusion:'
print_servers conclusion

exit 0
