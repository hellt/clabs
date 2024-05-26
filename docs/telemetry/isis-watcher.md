# IS-IS watcher. Tracking IS-IS topology changes in Real-Time

![IS-IS watcher containerlab](container_lab.drawio.png)
This lab consists of 6 FRR routers and a single IS-IS Watcher. Each router is pre-configured for being in IS-IS domain with different network type. Topology changes are printed in a text file only (which is enough for testing), for getting logs exported to ELK or Topolograph (to see network changes on a map) start `docker-compose` files and follow instructions on main README.

### IS-IS Topology Watcher
IS-IS Watcher is a monitoring tool of IS-IS topology changes for network engineers. It works via passively listening to IS-IS control plane messages through a specially established IS-IS adjacency between IS-IS Watcher and one of the network device. The tool logs IS-IS events into a static file, which can be exported by Logstash to **Elastic Stack (ELK)**, **Zabbix**, **WebHooks** and **Topolograph** monitoring dashboard for keeping the history of events, alerting, instant notification.

#### Detected network events:
* IS-IS neighbor adjacency Up/Down
* IS-IS link cost changes
* IS-IS networks appearance/disappearance from the topology

### Supported IS-IS TLV 
| TLV name                         | TLV |
|----------------------------------|-----|
| IS Reachability                  | 2   |
| Extended IS Reachability   (new) | 22  |
| IPv4 Internal Reachability (old) | 128 |
| IPv4 External Reachability (old) | 130 |
| Extended IPv4 Reachability (new) | 135 |
| IPv6 Reachability                | 236 |  

## Quickstart

1. [Install](https://containerlab.srlinux.dev/install/) containerlab.
2. Create a `br-dr` linux bridge (to emulate broadcast network):

    ```
    sudo brctl addbr br-dr
    sudo ip link set up dev br-dr
    ```

3. Start the lab
    ```
    sudo clab deploy --topo frr01.clab.yml
    ```

4. Start watching logs
    ```
    sudo tail -f watcher/watcher.log
    ```

5. Change IS-IS settings on lab' routers. Connect to a router
    ```
    sudo docker exec -it clab-frr01-router2 vtysh
    ```

### IS-IS Watcher logs location
Available under `watcher` folder. To see them:
```
sudo tail -f watcher/watcher.log
```

Note:
log file should have `systemd-network:systemd-journal` ownership

> **Note**  
> [IS-IS Watcher](https://github.com/Vadims06/isiswatcher) - IS-IS topology tracker    
> This lab is based on simple FRR for building topology based on frr routers, more information about it is available here: https://www.brianlinkletter.com/2021/05/use-containerlab-to-emulate-open-source-routers/

