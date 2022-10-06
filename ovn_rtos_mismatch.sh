#!/bin/bash -eu
# Author: Andreas Karis <akaris@redhat.com>
# This script retrieves all k8s.ovn.org/node-subnets and all OVN rtos_networks. It then compares
# the 2 sets and reports differences.
# Tested for IPv4 single stack clusters only with OCP 4.8.35

# check_prerequisites makes sure that all required commands are found
# and that python points to python 3
check_prerequisites() {
    for c in jq python oc sort uniq awk grep; do
        if ! command -v "${c}" &> /dev/null; then    
            echo "Prerequisite: Command ${c} could not be found"
            exit 1
        fi
    done
    if ! python --version | grep -q "Python 3"; then
        echo "Prerequisite: Python must point to Python 3"
        exit 1
    fi
}

# read_opts reads the options for this script
read_opts() {
    opts="$@"
    for o in $opts; do
        if [ "$o" == "-d" ]; then
            DEBUG=true
        fi
        if [ "$o" == "-h" ]; then
            HELP=true
        fi
    done
}

# print_help prints help info
print_help() {
    echo "Usage: -d for debug, -h for help"
    exit 1
}

# get_node_subnets gets the subnet annotation from all nodes
get_node_subnets() {
    for a in $(oc get nodes -o json | jq -r '.items[].metadata.annotations["k8s.ovn.org/node-subnets"]'); do
        echo $a | jq -r '.default'
    done
}

# get_leader_pod gets the OVN_Northbound DB leader
function get_leader_pod {
     for f in $(oc -n openshift-ovn-kubernetes get pods -l app=ovnkube-master \
         -o jsonpath="{.items[*].metadata.name}")
     do
         f_role=$(oc -n openshift-ovn-kubernetes exec "${f}" -c northd -- \
             ovs-appctl -t /var/run/ovn/ovnnb_db.ctl cluster/status OVN_Northbound | \
             grep -E "^Role: ")
         echo "${f_role}" | grep -q leader && { echo ${f}; return $(/bin/true); }
     done
     return $(/bin/false)
}

# get_rtos_network gets the subnets that are attached to each rtos router
get_rtos_networks() {
    local leader_pod="$1"
    oc exec -it -n openshift-ovn-kubernetes  "${leader_pod}" -c northd -- ovn-nbctl find Logical_Router_Port "name>rtos" \
        | grep networks | awk -F ':' '{print $NF}' | jq -r '.[0]' \
        | python -c '
import ipaddress
import sys
for line in sys.stdin:
    ipnet=line.rstrip()
    net=ipaddress.ip_network(ipnet, strict=False)
    print(net)
'
}

check_prerequisites

read_opts "$@"
HELP=${HELP:-false}
DEBUG=${DEBUG:-false}
if $HELP; then
    print_help
fi

leader_pod=$(get_leader_pod)
node_subnets="$(get_node_subnets)"
rtos_networks=$(get_rtos_networks "${leader_pod}")
rtos_networks="$rtos_networks"

if $DEBUG; then
    echo "=== Leader pod is: ==="
    echo "${leader_pod}"
    echo "=== Node subnets are: ==="
    echo "${node_subnets}"
    echo "=== rtos networks are: ==="
    echo "${rtos_networks}"
fi

mismatch=$(echo -e "${node_subnets}\n${rtos_networks}" | sort | uniq -c | awk '$1 != 2')
if [ "${mismatch}" != "" ]; then
    echo "The following subnets were found either in node subnets or in rtos networks, but not in the other:"
    echo "${mismatch}"
    exit 1
fi
exit 0
