#!/bin/bash
#
# Deploy and configure the RIFT agent (srl-rift) on the Lab_RIFT topology.
#
#   ./deploy-rift.sh            use the already-built binary
#   ./deploy-rift.sh --build    rebuild before deploying
#
# Prerequisites: the topology must be up (clab deploy) and the srl-rift
# repo cloned into ./srl-rift

set -euo pipefail

REPO_DIR="./srl-rift"
BINARY="$REPO_DIR/rift-srl"
LAB_PREFIX="clab-Lab_RIFT"
NODES=("spine1" "spine2" "leaf1" "leaf2" "leaf3")

declare -A SYSID=([spine1]=1 [spine2]=2 [leaf1]=101 [leaf2]=102 [leaf3]=103)
declare -A LEVEL=([spine1]=1 [spine2]=1 [leaf1]=0   [leaf2]=0   [leaf3]=0)

# Fabric interfaces only. On the leaves, ethernet-1/3 faces the host and
# does not participate in RIFT -- the agent discovers that prefix another way.
declare -A IFACES=(
    [spine1]="ethernet-1/1 ethernet-1/2 ethernet-1/3"
    [spine2]="ethernet-1/1 ethernet-1/2 ethernet-1/3"
    [leaf1]="ethernet-1/1 ethernet-1/2"
    [leaf2]="ethernet-1/1 ethernet-1/2"
    [leaf3]="ethernet-1/1 ethernet-1/2"
)

# ------------------------------------------------------------- preflight

[[ -d "$REPO_DIR" ]] || {
    echo "ERROR: $REPO_DIR not found"
    echo "  git clone https://github.com/hyposcaler/srl-rift.git"
    exit 1
}

docker ps --format '{{.Names}}' | grep -q "^$LAB_PREFIX-spine1$" || {
    echo "ERROR: topology is not running"
    echo "  sudo clab deploy -t rift.clab.yml"
    exit 1
}

# ------------------------------------------------------------- build

if [[ "${1:-}" == "--build" ]] || [[ ! -f "$BINARY" ]]; then
    echo "Building the agent..."
    ( cd "$REPO_DIR" && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
        go build -o rift-srl ./cmd/rift-srl/ )
fi

# ------------------------------------------------------------- deploy

echo
echo "Deploying the agent to ${#NODES[@]} nodes"

for node in "${NODES[@]}"; do
    c="$LAB_PREFIX-$node"
    echo "  $node"

    # 1. the binary
    docker cp "$BINARY" "$c:/usr/local/bin/rift-srl"
    docker exec "$c" chmod +x /usr/local/bin/rift-srl

    # 2. the manifest the app manager reads
    docker cp "$REPO_DIR/lab/rift-srl.yml" \
        "$c:/etc/opt/srlinux/appmgr/rift-srl.yml"

    # 3. the YANG model, at the path that manifest declares
    docker exec "$c" mkdir -p /opt/rift-srl/yang
    docker cp "$REPO_DIR/yang/rift-srl.yang" \
        "$c:/opt/rift-srl/yang/rift-srl.yang"

    # 4. allow binding below port 1024 (RIFT TIE uses 915)
    docker exec "$c" ip netns exec srbase-default \
        sysctl -w net.ipv4.ip_unprivileged_port_start=0 >/dev/null 2>&1 || true

    # 5. reload the app manager. This compiles the YANG and exposes /rift.
    #    Without it, "set / rift" returns "Unknown token 'rift'".
    docker exec "$c" sr_cli -- \
        tools system app-management application app_mgr reload >/dev/null 2>&1 || true
done

echo
echo "Waiting for YANG model registration..."
sleep 15

# ------------------------------------------------------------- configure

echo
echo "Configuring RIFT"

for node in "${NODES[@]}"; do
    c="$LAB_PREFIX-$node"
    echo "  $node  system-id=${SYSID[$node]}  level=${LEVEL[$node]}"

    cmds="enter candidate"
    cmds="$cmds\nset / rift admin-state enable"
    cmds="$cmds\nset / rift system-id ${SYSID[$node]}"
    cmds="$cmds\nset / rift level ${LEVEL[$node]}"
    for i in ${IFACES[$node]}; do
        cmds="$cmds\nset / rift interface $i"
    done
    cmds="$cmds\ncommit now"

    docker exec "$c" bash -c "printf '$cmds\n' | sr_cli" >/dev/null || {
        echo "    FAILED on $node -- see README.md (Troubleshooting)"
    }
done

echo
echo "Waiting for convergence..."
sleep 15

# ------------------------------------------------------------- verify

echo
for node in "${NODES[@]}"; do
    c="$LAB_PREFIX-$node"
    adj=$(docker exec "$c" sr_cli -- "info from state rift" 2>/dev/null \
          | grep -c "state three-way" || true)
    printf "  %-8s three-way adjacencies: %s\n" "$node" "${adj:-0}"
done

echo
echo "Expected: 3 on each spine, 2 on each leaf."
echo
echo "Details:       docker exec -it $LAB_PREFIX-spine1 sr_cli"
echo "               > info from state rift"
echo "Connectivity:  ./verify.sh"
