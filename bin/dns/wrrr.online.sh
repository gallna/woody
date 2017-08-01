#!/bin/bash

source fscripts
# Usage:
# /cc.wrrr.sh --name gogs-data --server integration --apply -- --access-mode ReadWriteOnce  --storage-class standard
# wrr.online --name monitoring.wrrr.online --ip 10.192.67.81
# api.dnsimple.com GET "/57425/zones/wrrr.online/records" name=graylog
# ---------------------------------------------------------------------------- #
source shflags
# ---------------------------------------------------------------------------- #
DEFINE_string 'type' 'A' 'Record type' 'T'
DEFINE_integer 'ttl' 300 'Record ttl' 't'
DEFINE_string 'priority' null 'Record priority' 'p'
DEFINE_string 'ip' false 'IP' 'c'
DEFINE_string 'name' false 'Record name' 'n'
# ---------------------------------------------------------------------------- #
# parse the command-line
FLAGS "$@" || exit $?
eval set -- "${FLAGS_ARGV}"
# ---------------------------------------------------------------------------- #
test ${FLAGS_ip} == false && die "Missing remote ip ${FLAGS_ip}"
test ${FLAGS_name} == false && die "Missing remote name"
# ---------------------------------------------------------------------------- #
source boilerplate.sh
# ---------------------------------------------------------------------------- #
dns_account=57425
dns_zone=wrrr.online
declare -A record=(
  [type]=${FLAGS_type}
  [ttl]=${FLAGS_ttl}
  [priority]=${FLAGS_priority}
  [content]=${FLAGS_ip}
  [name]=${FLAGS_name//.$dns_zone}
)

records=$(api.dnsimple.com GET /$dns_account/zones/$dns_zone/records name=${record[name]} | jq --exit-status '.data[].id?') && {
  while read record; do
    api.dnsimple.com PATCH /57425/zones/wrrr.online/records/$record \
      name=${record[name]} \
      content=${record[content]}
  done <<< "$records"
} || {
  api.dnsimple.com POST /$dns_account/zones/$dns_zone/records \
    priority:=${record[priority]} \
    ttl=${record[ttl]} \
    type=${record[type]} \
    name=${record[name]} \
    content=${record[content]}
}

wait
