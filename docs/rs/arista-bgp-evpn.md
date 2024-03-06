|                               |                                                                                                                          |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **Description**               | Arista BGP EVPN                                                                                                          |
| **Components**                | Arista cEOS                                                                                                              |
| **Resource requirements**[^1] | :fontawesome-solid-microchip: 4 <br/>:fontawesome-solid-memory: 8 GB                                                     |
| **Topology file**             | [ceos-evpn-overlaid.clab.yml](https://github.com/hellt/clabs/blob/main/labs/arista-bgp-evpn/ceos-evpn-overlaid.clab.yml) |
| **Version information**[^2]   | `containerlab:0.19.1`                                                                                                    |
| **Authors**                   | [Dharmesh Shah](https://github.com/dharmbhai) and [Dave Varnum](https://overlaid.net/about/)                             |

## Description

The topology and configs are based on the [Arista BGP EVPN – Configuration Example](https://overlaid.net/2019/01/27/arista-bgp-evpn-configuration-example/).

All credits belong to the Original Author.

This is a cEOS (Arista Container for EOS) based EVPN VXLAN topology to illustrate following concepts

1. MLAG
2. L2 EVPN
3. L3 EVPN

## Quickstart

1. [Install](https://containerlab.srlinux.dev/install/) containerlab.
2. Clone [hellt/clabs](https://github.com/hellt/clabs) repository
3. Change into `arista-bgp-evpn` repository and deploy the lab topology:

    ```bash
    git clone https://github.com/hellt/clabs.git
    cd labs/arista-bgp-evpn
    containerlab dep -t ceos-evpn-overlaid.clab.yml
    ```

4. Follow the original blog post and perform the configurations, or use the provided resulting configs from the [`configs`](https://github.com/hellt/clabs/blob/main/labs/arista-bgp-evpn/configs) directory.

[^1]: Resource requirements are provisional. Consult with the installation guides for additional information. Memory deduplication techniques like [UKSM](https://netdevops.me/2021/how-to-patch-ubuntu-2004-focal-fossa-with-uksm/) might help with RAM consumption.
[^2]: The lab has been validated using these versions of the required tools/components. Using versions other than stated might lead to a non-operational setup process.
