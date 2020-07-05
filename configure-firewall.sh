#!/bin/sh
set -e

# Helper command to manipulate both the IPv4 and IPv6 tables.
ip46tables() {
  iptables -w "$@"
  ip6tables -w "$@"
}

chain_exists() {
    [ $# -lt 1 -o $# -gt 2 ] && {
        echo "Usage: chain_exists <chain_name> [table]" >&2
        return 1
    }
    local chain_name="$1" ; shift
    [ $# -eq 1 ] && local table="--table $1"
    iptables $table -n --list "$chain_name" >/dev/null 2>&1
}

cleanup() {
  echo "Cleanup..."
  ip46tables -D INPUT -j blocklist 2> /dev/null || true
  ip46tables -F blocklist 2> /dev/null || true
  ip46tables -X blocklist 2> /dev/null || true
  echo "...done."
  #exit 0
}

is_command() {
    # Checks for existence of string passed in as only function argument.
    # Exit value of 0 when exists, 1 if not exists. Value is the result
    # of the `command` shell built-in call.
    local check_command="$1"

    command -v "${check_command}" >/dev/null 2>&1
}


if ! is_command iptables ; then
    echo "iptables not found, exiting..."
    exit 1;
fi


#Download the lists if they are at least a day old
if [[ $(stat -c%Y /lists/drop.txt) -le $(( $(date +%s) - 86400 )) ]]; then
    echo "Downloading updated dropV4 list"
    curl https://www.spamhaus.org/drop/drop.txt 2> /dev/null | sed 's/;.*//' > /lists/drop.txt
fi

if [[ $(stat -c%Y /lists/dropv6.txt) -le $(( $(date +%s) - 86400 )) ]]; then
    echo "Downloading updated dropV6 list"
    curl https://www.spamhaus.org/drop/dropv6.txt 2> /dev/null | sed 's/;.*//' > /lists/dropv6.txt
fi

if [[ $(stat -c%Y /lists/drop.txt) -gt $(( $(date +%s) - 86400 ))  ]] && chain_exists blocklist ; then
    echo "No update needed, exiting";
    exit 0;
fi

if chain_exists blocklist  ; then
    echo "Chain Exists, flushing..."
    cleanup
fi


#Configure iptables
ip46tables -D INPUT -j blocklist 2> /dev/null || true
ip46tables -F blocklist 2> /dev/null || true
ip46tables -X blocklist 2> /dev/null || true
ip46tables -N blocklist

echo "Configuring IPv4 blocklist..."
for ip in $(cat /lists/drop.txt); do
  iptables -A blocklist -s $ip -j DROP
  iptables -A blocklist -d $ip -j DROP
done

iptables -A blocklist -j RETURN
echo "Configuring IPv6 blocklist..."

for ip in $(cat /lists/dropv6.txt); do
  ip6tables -A blocklist -s $ip -j DROP
  ip6tables -A blocklist -d $ip -j DROP
done

ip6tables -A blocklist -j RETURN
ip46tables -I INPUT -j blocklist

echo "...done."

exit 0
