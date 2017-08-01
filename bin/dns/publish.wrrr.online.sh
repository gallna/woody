#!/bin/bash

domain=wrrr.online
yaml=$(mktemp) && cat > $yaml
# ---------------------------------------------------------------------------- #
# Usage:
# ./auto.wrrr.online.sh
# ---------------------------------------------------------------------------- #
source fscripts
source boilerplate.sh

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Cache - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# ---------------------------------------------------------------------------- #
cache_dir=$XDG_CACHE_HOME/wrrr.online
cache_file="${cache_dir}/$(basename $(dirname $(realpath $0))).cache"
# test -d $cache_dir && find $cache_dir -mmin +6 -type f -delete > /dev/null || mkdir -p $cache_dir
# ---------------------------------------------------------------------------- #
# function update_cache() {
#   local per_page=${1-100}
#   local current_page=${2-1};
#   local total_pages=$(api.dnsimple.com GET "/57425/zones/$domain/records?per_page=${per_page}&page=${current_page}" \
#     | tee >(jq -r -c '.data[]' >> $cache_file) \
#     | jq -r -c '.pagination.total_pages')
#   msg "Updated $domain records; page: ${current_page}/${total_pages} (${per_page} per_page)"
#   (( total_pages > current_page++ )) && update_cache $per_page $current_page || true
# }
# ---------------------------------------------------------------------------- #
# test -f "$cache_file" || update_cache
# ---------------------------------------------------------------------------- #

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - DNS ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# -------------------------------------------------------------------------- #
function get_domain() {
  name=$(yaml r $yaml metadata.annotations.\"io.rahcnar.domain\")
  [[ -n "$name" && ! "$name" =~ null ]] || name=$(yaml r $yaml "metadata.name" | tr '-' '.')
  echo "${name//\.$domain}"
}

function get_ip() {
  ip=$(yaml r $yaml metadata.annotations.\"io.rahcnar.ip\");
  lb_ip=$(yaml r $yaml "status.loadBalancer.ingress[*].ip" | sort --unique | awk '{print $2}')
  case "$ip" in
    "" ) echo $lb_ip ;;
    null ) echo $lb_ip ;;
    public )  wrrr.online i "$lb_ip" --public-ip | xargs ;;
    private ) wrrr.online i "$lb_ip" --private-ip | xargs ;;
    * ) pcregrep '^[\.\d]+$' <<< "$ip" >/dev/null && echo "$ip" || \
        pcregrep '^[\.\d]+$' <<< "$lb_ip" >/dev/null && echo "$lb_ip" || \
        die "Unknown IP: $ip LB: $lb_ip" ;;
  esac
}

function get_public_ip() {
  ip=$(get_ip)
  test -z "$ip" || wrrr.online i "$ip" --public-ip | xargs
}

# -------------------------------------------------------------------------- #
function get_records() {
  IFS="=" read key value <<< "$1"
  cat "$cache_file" | jq -r ". | select (.${key} == \"${value}\") | .${2}?"
}

# -------------------------------------------------------------------------- #
function add_record() {
  Blue $(printf 'Creating, %20s ~> %s' $name $ip)
  $(dirname $0)/wrrr.online.sh --name $name --ip $ip
}

function update_record() {
  Cyan $(printf 'Updating, %20s ~> %s [removing: %s]' $name $ip $dns_ip)
  test -z "$dns_ip" || sed -i "/$dns_ip/d" $cache_file
  $(dirname $0)/wrrr.online.sh --name $name --ip $ip
}

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Processing  ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# -------------------------------------------------------------------------- #
name=$(get_domain); test -z "$name" && die "domain name not found"
test -z "${force_public-}" && ip=$(get_ip) || ip=$(get_public_ip);
test -z "$ip" && { Debug "Cancelled, $name" && exit 7; }

# -------------------------------------------------------------------------- #
dns_ip=$(get_records name=$name content)
message=$(printf '%s.%s ~> IP: %s [dns: %s]' $name $domain $ip $dns_ip)

# -------------------------------------------------------------------------- #
[[ "$dns_ip" = "$ip" ]] && Yellow "Skipped,  $message" || {
  test -z "$dns_ip" && add_record || update_record | jq -r -c '.data' >> $cache_file
}


rm -f $yaml



:<<JSON
{
    "data": [
        {
            "content": "ns1.dnsimple.com admin.dnsimple.com 1475625074 86400 7200 604800 300",
            "created_at": "2016-10-04T23:34:50Z",
            "id": 6429792,
            "name": "",
            "parent_id": null,
            "priority": null,
            "regions": [
                "global"
            ],
            "system_record": true,
            "ttl": 3600,
            "type": "SOA",
            "updated_at": "2017-07-29T02:58:09Z",
            "zone_id": "wrrr.online"
        }
    ],
    "pagination": {
        "current_page": 1,
        "per_page": 30,
        "total_entries": 140,
        "total_pages": 5
    }
}
JSON
