#!/bin/bash


JSON=$(curl -s -H "Accept: application/json" "http://rancher-metadata/latest/stacks/ipsec/services/ipsec/containers")
CONTAINERS=$(jq -r '.[] | .name' <<<"${JSON}")
ENVIRONMENT=$(curl -s "http://rancher-metadata/latest/self/stack/environment_name")
INSTANCE=$(curl -s "http://rancher-metadata/latest/self/host/name")
PUSHGATEWAY_URL=${1:-"http://pushgateway.metrics:9091"}

function container_status() {
  local name="$1"
  local json=$(jq -r ".[] | select(.name == \"${name}\")" <<<"${JSON}")
  local ip=$(jq -r ".primary_ip" <<<"${json}")
  local host_uuid=$(jq -r ".host_uuid" <<<"${json}")
  local host_name=$(curl -s "http://rancher-metadata/latest/hosts/${host_uuid}/name")

  echo "Getting stats for container ${name} with ip ${ip}" >/dev/stderr

  count=5
  interval=2

  ping_stats=$(ping -i "${interval}" -q -w 30 -n -c "${count}" "${ip}" 2>&1 | tail -2)
  echo "${ping_stats}" >/dev/stderr
  min_ping="$(echo ${ping_stats} | sed -e "s#.\+= \([.0-9]\+\).\+#\\1#g")"
  avg_ping="$(echo ${ping_stats} | cut -d'/' -f5)"
  max_ping="$(echo ${ping_stats} | cut -d'/' -f6)"
  loss_percent="$(echo ${ping_stats} | sed -e "s#.\+ \([0-9]\+\)%.\+#\1#")"

  cat <<EOF
ipsec_status{container_name="${name}",host_name="${host_name}",what="min_ping"} ${min_ping}
ipsec_status{container_name="${name}",host_name="${host_name}",what="avg_ping"} ${avg_ping}
ipsec_status{container_name="${name}",host_name="${host_name}",what="max_ping"} ${max_ping}
ipsec_status{container_name="${name}",host_name="${host_name}",what="loss_percent"} ${loss_percent}
EOF
  echo >/dev/stderr
}


DATA="# TYPE ipsec_status gauge"

while read c; do
  data=$(container_status "$c")
  DATA="${DATA}
${data}"
done <<<"${CONTAINERS}"

echo "Sending data to ${PUSHGATEWAY_URL}" >/dev/stderr
curl -s --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/ipsec_status/instance/${INSTANCE}/environment/${ENVIRONMENT}" <<<"${DATA}"
