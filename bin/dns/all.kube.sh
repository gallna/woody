#!/bin/bash
# ---------------------------------------------------------------------------- #
# Usage:
# ./auto.wrrr.online.sh
# ---------------------------------------------------------------------------- #
source fscripts
source boilerplate.sh

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Cache - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
per_page=100
domain=wrrr.online
# ---------------------------------------------------------------------------- #
cache_dir=$XDG_CACHE_HOME/wrrr.online
cache_file="${cache_dir}/$(basename $(dirname $(realpath $0))).cache"
total_pages=$(test -f "$cache_file" && wc -l "$cache_file" | awk '{print $1}' || echo 2)

# ---------------------------------------------------------------------------- #
function update_cache() {
  local current_page=${1-1};
  (( total_pages > current_page++ )) && update_cache $current_page || true &
  msg "Updated $domain records; page: ${current_page}/${total_pages} (${per_page} per_page)"
  api.dnsimple.com GET "/57425/zones/$domain/records?per_page=${per_page}&page=${current_page}" | jq -r -c '.data[]' >> $cache_file
}
# ---------------------------------------------------------------------------- #
test -d $cache_dir && find $cache_dir -mmin +6 -type f -delete > /dev/null || mkdir -p $cache_dir
test -f "$cache_file" || update_cache

if (( 5 > $(wc -l "$cache_file" | awk '{print $1}') )); then
  die "DNS update failed!"
fi
# ---------------------------------------------------------------------------- #
yaml=$(mktemp --dry-run)
# ---------------------------------------------------------------------------- #
function add_record() {
  local item=$1
  local spec=$(yaml r "$yaml" "items[${item}]");
  # yaml r - metadata.name <<< "$spec" | msg

  if [[ -n "${spec-}" && ! "${spec-}" =~ null ]]; then
    echo "$spec" | $(dirname $0)/publish.wrrr.online.sh || {
      code="$?"; test 7 == $code || exit $code
    } &
    item=$((item + 1)) && add_record $item
    wait
  fi
}
kubectl get --all-namespaces service,ingress -o yaml > $yaml && add_record 0
rm -f "$yaml"
