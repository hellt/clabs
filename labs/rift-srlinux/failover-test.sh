#!/bin/bash
#
# Failover test: drop the spine1 <-> leaf3 link and confirm traffic to
# Host3 keeps flowing via spine2.

set -uo pipefail

LAB_PREFIX="clab-Lab_RIFT"

echo "=============================================="
echo " Baseline"
echo "=============================================="
docker exec "$LAB_PREFIX-leaf3" sr_cli -- "info from state rift" 2>/dev/null \
    | grep -E "adjacency-count|neighbor-system-id"

echo
echo "Baseline ping Host1 -> Host3"
docker exec "$LAB_PREFIX-Host1" ping -c 3 -W 2 10.10.3.10 2>&1 | tail -2

echo
echo "=============================================="
echo " Dropping the spine1 <-> leaf3 link"
echo "=============================================="
docker exec "$LAB_PREFIX-spine1" bash -c "printf 'enter candidate\nset / interface ethernet-1/3 admin-state disable\ncommit now\n' | sr_cli" >/dev/null
echo "  spine1 ethernet-1/3 disabled"

echo
echo "Waiting for reconvergence..."
sleep 10

echo
echo "=============================================="
echo " State after the failure"
echo "=============================================="
echo
echo "--- leaf3: should be left with spine2 only (system-id 2) ---"
docker exec "$LAB_PREFIX-leaf3" sr_cli -- "info from state rift" 2>/dev/null \
    | grep -E "adjacency-count|neighbor-system-id"

echo
echo "--- spine1: disaggregation ---"
docker exec "$LAB_PREFIX-spine1" sr_cli -- "info from state rift" 2>/dev/null \
    | grep -E "disaggregation-summary|adjacency-count"

echo
echo "--- spine2: disaggregation ---"
docker exec "$LAB_PREFIX-spine2" sr_cli -- "info from state rift" 2>/dev/null \
    | grep -E "disaggregation-summary|adjacency-count"

echo
echo "Ping Host1 -> Host3 (now necessarily via spine2)"
docker exec "$LAB_PREFIX-Host1" ping -c 5 -W 2 10.10.3.10 2>&1 | tail -2

echo
echo "=============================================="
echo " Restoring the link"
echo "=============================================="
docker exec "$LAB_PREFIX-spine1" bash -c "printf 'enter candidate\nset / interface ethernet-1/3 admin-state enable\ncommit now\n' | sr_cli" >/dev/null
echo "  spine1 ethernet-1/3 re-enabled"

sleep 10

echo
echo "Final leaf3 state"
docker exec "$LAB_PREFIX-leaf3" sr_cli -- "info from state rift" 2>/dev/null \
    | grep -E "adjacency-count|neighbor-system-id"

echo
echo "Final ping Host1 -> Host3"
docker exec "$LAB_PREFIX-Host1" ping -c 3 -W 2 10.10.3.10 2>&1 | tail -2
