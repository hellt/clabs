|                               |                                                                                                                                |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **Description**               | Network Unit Testing System (Show case)                                                                                        |
| **Components**                | Nokia SR Linux                                                                                                                 |
| **Resource requirements**[^1] | :fontawesome-solid-microchip: 4 <br/>:fontawesome-solid-memory: 8 GB                                                           |
| **Topology file**             | [setup.clos02.clab.yml](https://github.com/network-unit-testing-system/nuts-containerlab-demo/blob/main/setup.clos02.clab.yml) |
| **Version information**[^2]   | `containerlab:0.44.3`, `gnmic:0.31.7`, `srlinux:23.3.3`                                                                        |
| **Authors**                   | **Urs Baumann** [:material-linkedin:][urs-linkedin] [:material-github:][urs-github]                                            |

## Description

The lab is heavily based on the [5-stage Clos fabric from ContainerLab](https://containerlab.dev/lab-examples/min-5clos)

The client1 is replaced with a Python container image and NUTS will be installed on it. Clients 2 to 4 are running a Linux container with an SSH service.

The router images are Nokia SR Linux. To be able to use NAPALM, the [community driver](https://github.com/napalm-automation-community/napalm-srlinux) is used.

## Quickstart

1. [Install](https://containerlab.srlinux.dev/install/) containerlab.
2. Clone [lab repository](https://github.com/network-unit-testing-system/nuts-containerlab-demo).
3. Deploy the lab topology `containerlab deploy -t setup.clos02.clab.yml`
4. Execute `./setup.sh` to confure the network and setup the hosts
5. Follow the original [`README`](https://github.com/network-unit-testing-system/nuts-containerlab-demo/blob/main/README.md) to run and change the network tests.

[^1]: Resource requirements are provisional. Consult with the installation guides for additional information. Memory deduplication techniques like KSM might help with RAM consumption.
[^2]: The lab has been validated using these versions of the required tools/components. Using versions other than stated might lead to a non-operational setup process.

[urs-linkedin]: https://www.linkedin.com/in/ubaumannch/
[urs-github]: https://github.com/ubaumann
