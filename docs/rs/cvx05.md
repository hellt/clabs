|                               |                                                                      |
| ----------------------------- | -------------------------------------------------------------------- |
| **Description**               | Cumulus Linux VX with leaf and spine topology                        |
| **Components**                | [Cumulus Linux][cvx]                                                 |
| **Resource requirements**[^1] | :fontawesome-solid-microchip: 4 <br/>:fontawesome-solid-memory: 5 GB |
| **Topology file**             | [topo.clab.yml][topofile]                                            |
| **Name**                      | cvx05                                                                |
| **Version information**[^2]   | `cvx:5.3.0` `Docker version 25.0.3, build 4debf41`                   |

## Description

The lab consists of Cumulus Linux 5.3 fabric composed of 2 borders, 2 spines and 2 leafs. The topology demonstrate a EVPN VXLAN BGP configuration.
The topology is additionally equipped with a Linux container connected to leaves to facilitate use cases which require access side emulation.

<div class='mxgraph' style='max-width:100%;border:1px solid transparent;margin:0 auto; display:block;' data-mxgraph='{"page":1,"zoom":2,"highlight":"#0000ff","nav":true,"resize":true,"edit":"_blank","url":"https://raw.githubusercontent.com/hellt/clabs/main/diagrams/cvx05.drawio"}'></div>

## Configuration

The custom docker image need to be built locally before running the deployment

```bash
docker build \
--force-rm=true \
-t cx_ebtables:5.3.0 \
-f cx_ebtables.Dockerfile .
```

All nodes have been provided with a startup configuration and should come up with all their interfaces fully configured.

Once the lab is started, the nodes will be able to ping each other on their vlan interfaces:

```
# ping leaf interface
root@border-1:/# ping 10.162.0.14
PING 10.162.0.14 (10.162.0.14) 56(84) bytes of data.
64 bytes from 10.162.0.14: icmp_seq=1 ttl=64 time=0.262 ms
64 bytes from 10.162.0.14: icmp_seq=2 ttl=64 time=0.256 ms
^C
--- 10.162.0.14 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 34ms
```

Logs of the NVUE process are placed in `/root/nvue.log`.

## Use cases

* Demonstrate how a `cvx` can run with a EVPN VXLAN BGP fabric
* Demonstrate Cumulus Linux Leaf and spine with NVUE configuration (introduced in version 5.X)
* Verify vlan trunking and access on connected host to a leaf

[cvx]: https://www.nvidia.com/en-gb/networking/ethernet-switching/cumulus-vx/
[topofile]: https://github.com/hellt/clabs/tree/main/labs/cvx05/topo.clab.yml

[^1]: Resource requirements are provisional. Consult with the installation guides for additional information.
[^2]: The lab has been validated using these versions of the required tools/components. Using versions other than stated might lead to a non-operational setup process.

<script type="text/javascript" src="https://viewer.diagrams.net/js/viewer-static.min.js" async></script>
