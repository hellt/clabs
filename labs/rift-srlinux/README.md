# RIFT on SR Linux. Deploying Routing in Fat Trees (RFC 9692) as an NDK agent

This lab deploys a working RIFT (Routing In Fat Trees, [RFC 9692](https://www.rfc-editor.org/rfc/rfc9692)) fabric on Nokia SR Linux using the community `srl-rift` NDK agent by [Dennis Fanshaw (hyposcaler)](https://github.com/hyposcaler/srl-rift).

RIFT behaves as link-state northbound (toward the spines) and distance-vector southbound (toward the leaves), which makes it purpose-built for Clos / fat-tree fabrics: automatic level-based adjacency formation, minimal southbound state, and automatic disaggregation on link or node failure.

This is a **deployment and troubleshooting guide** for running that agent in a containerlab topology. The RIFT implementation itself is the work of the hyposcaler project — full credit to the author.

## Lab summary

| | |
|---|---|
| **NOS** | Nokia SR Linux `25.7` |
| **RIFT agent** | [hyposcaler/srl-rift](https://github.com/hyposcaler/srl-rift) (built with Go 1.22) |
| **Topology** | 2 spines, 3 leaves, 3 Linux hosts |
| **Resource requirements** | _TODO: confirm, e.g. ~X vCPU, ~Y GB RAM_ |

## Topology

Two spines at level 1 and three leaves at level 0, each leaf with a Linux host attached for end-to-end reachability tests. Only fabric links (ethernet-1/1, ethernet-1/2) participate in RIFT; ethernet-1/3 on each leaf faces the host.

| Node   | Level | System ID |
|--------|-------|-----------|
| spine1 | 1     | 1         |
| spine2 | 1     | 2         |
| leaf1  | 0     | 101       |
| leaf2  | 0     | 102       |
| leaf3  | 0     | 103       |

## Deployment (two steps)

RIFT is not part of the topology file — it is installed by an NDK agent after the fabric is up. Deploying the lab is therefore a two-step process.

**1. Clone the RIFT agent into this lab directory**

    git clone https://github.com/hyposcaler/srl-rift.git

The `deploy-rift.sh` script expects the agent at `./srl-rift` and builds the binary itself (Go 1.22).

**2. Deploy the topology, then run the agent installer**

    sudo clab deploy -t rift.clab.yml
    ./deploy-rift.sh            # add --build to force a rebuild

The script copies the binary, its `rift-srl.yml` manifest and `rift-srl.yang` model to every SR Linux node, reloads the app manager so the `/rift` path is exposed, then configures system-id, level and the fabric interfaces per node.

> If you skip step 2 and only run `clab deploy`, the fabric comes up with no routing — RIFT lives entirely in the agent.

## Verification

The script prints the three-way adjacency count per node at the end. Expected: **3 on each spine, 2 on each leaf**.

Inspect state directly:

    docker exec -it clab-Lab_RIFT-spine1 sr_cli
    > info from state rift

_TODO: paste the real output of the three-way adjacencies / LSDB here._

Test host-to-host reachability — traffic should load-share across both spines:

    ./verify.sh

_TODO: paste the real host-to-host ping output here._

## Failure / disaggregation test

`failover-test.sh` breaks a fabric link to demonstrate RIFT's automatic disaggregation — when a leaf loses reachability to a prefix via the default southbound route, the affected specific prefixes are re-advertised so traffic reroutes via the healthy spine.

    ./failover-test.sh

_TODO: briefly describe what the script breaks and what is observed._

## Troubleshooting

- **`Unknown token 'rift'` in the CLI.** The agent files were copied but the app manager was not reloaded, so the YANG model was never registered. The script runs `tools system app-management application app_mgr reload` for you; if you install manually, run it after placing `rift-srl.yml` in `/etc/opt/srlinux/appmgr/` and `rift-srl.yang` in `/opt/rift-srl/yang/`, then reconnect to the CLI.
- **YANG vs gRPC registration are separate steps.** The `/rift` CLI path can resolve while the agent process is not yet attached to the NDK (or vice versa). Check both if the model loads but no adjacencies form.
- **RIFT TIE packets need a privileged port (915).** The script sets `net.ipv4.ip_unprivileged_port_start=0` in the `srbase-default` netns so the agent can bind below 1024. If adjacencies never reach three-way, verify that sysctl.
- **Version compatibility.** This lab is validated on SR Linux `25.7`. Newer images (e.g. `26.3.1`) did not come up cleanly under older containerlab releases during testing — pin the version in `rift.clab.yml`.

## Links

- [srl-rift NDK agent](https://github.com/hyposcaler/srl-rift) — RIFT implementation by Dennis Fanshaw
- [RFC 9692 — RIFT: Routing in Fat Trees](https://www.rfc-editor.org/rfc/rfc9692)
- [SR Linux NDK documentation](https://learn.srlinux.dev/ndk/)
