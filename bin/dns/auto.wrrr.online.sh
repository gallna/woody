#!/bin/bash

# ---------------------------------------------------------------------------- #
# Usage:
# ./auto.wrrr.online.sh
# ---------------------------------------------------------------------------- #
source fscripts
source boilerplate.sh
# ---------------------------------------------------------------------------- #
yaml=$(mktemp --dry-run)
domain=wrrr.online
pids=()
# ---------------------------------------------------------------------------- #
function add_record() {
  # Get name and ip of service/ingress
  name=$(yaml r $yaml "metadata.name" | tr '-' '.')
  ip=$(yaml r $yaml "status.loadBalancer.ingress[*].ip" | sort --unique | awk '{print $2}')
  # -------------------------------------------------------------------------- #
  # Continue if empty ip
  test -z $ip && return
  # -------------------------------------------------------------------------- #
  (
    # Check existing DNS records
    dns_ip=$(api.dnsimple.com GET "/57425/zones/$domain/records" name=$name | jq --exit-status -r '.data[].content?' || true)

    message=$(printf '%s.%s ~> IP: [old: %s] new: %s ' $name $domain $dns_ip $ip)
    # Continue if record already exists
    [[ "$dns_ip" == "$ip" ]] && Yellow "Skipped,  $message" || {
      test -z "$dns_ip" && Green "Creating, $message" || Cyan "Updating, $message"
      # Add or update DNS record
      Debug wrrr.online.sh --name $name.$domain --ip $ip
      $(dirname $0)/wrrr.online.sh --name $name.$domain --ip $ip | Debug
    }
  ) & pids=("$!")
}

while read service; do
  # Get service details
  kubectl --namespace $(awk '{print $1}' <<< $service) get service $(awk '{print $2}' <<< $service) -o yaml > $yaml
  add_record
  rm -f $yaml
done < <(kubectl get service --all-namespaces | grep -v 'NAMESPACE' || pass "Services not found")

while read ingress; do
  # Get ingress resource details
  kubectl --namespace $(awk '{print $1}' <<< $ingress) get ingress $(awk '{print $2}' <<< $ingress) -o yaml > $yaml
  add_record
  rm -f $yaml
done < <(kubectl get ingress --all-namespaces | grep -v 'NAMESPACE' || pass "Ingress resources not found")

wait $pids
