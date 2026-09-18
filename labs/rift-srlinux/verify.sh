#!/bin/bash
#
# Verify RIFT state and end-to-end connectivity.

set -uo pipefail

LAB_PREFIX="clab-Lab_RIFT"
NODES=("spine1" "spine2" "leaf1" "leaf2" "leaf3")

echo "=============================================="
echo " Agent state"
echo "=============================================="
for node in "${NODES[@]}"; do
    st=$(docker exec "$LAB_PREFIX-$node" sr_cli -- \
        "info from state system app-management application rift-srl" 2>/dev/null \
        | grep -m1 "state" | awk '{print $2}')
    printf "  %-8s %s\n" "$node" "${st:-not registered}"
done

echo
echo "=============================================="
echo " Adjacencies"
echo "=============================================="
for node in "${NODES[@]}"; do
    echo
    echo "--- $node ---"
    docker exec "$LAB_PREFIX-$node" sr_cli -- "info from state rift" 2>/dev/null \
        | grep -E "adjacency-count|spf-runs|lsdb-tie-count|state three-way|neighbor-system-id|neighbor-level" \
        || echo "  no RIFT state"
done

echo
echo "=============================================="
echo " Routes learned on leaf1"
echo "=============================================="
docker exec "$LAB_PREFIX-leaf1" sr_cli -- \
    "show network-instance default route-table ipv4-unicast summary" 2>/dev/null \
    | head -30

echo
echo "=============================================="
echo " Host-to-host connectivity (across the fabric)"
echo "=============================================="
echo
echo "Host1 (10.10.1.10) -> Host2 (10.10.2.10)"
docker exec "$LAB_PREFIX-Host1" ping -c 3 -W 2 10.10.2.10 2>&1 | tail -3
echo
echo "Host1 (10.10.1.10) -> Host3 (10.10.3.10)"
docker exec "$LAB_PREFIX-Host1" ping -c 3 -W 2 10.10.3.10 2>&1 | tail -3
echo
echo "Host2 (10.10.2.10) -> Host3 (10.10.3.10)"
docker exec "$LAB_PREFIX-Host2" ping -c 3 -W 2 10.10.3.10 2>&1 | tail -3
