# Cisco Smart Enterprise Network + Security Lab (Containerlab)

A demo-first enterprise network lab aligned with Cisco Account Systems Engineering:
- Multi-segment network design (Sales/Ops/IT/Mgmt/Services)
- TCP/IP gateways + routed connectivity
- ACL-style security policies (least privilege)
- Validation via repeatable test cases

## IP Plan
- Sales: 192.168.10.0/24
- Ops: 192.168.20.0/24
- IT: 192.168.30.0/24
- Mgmt: 192.168.40.0/24
- Web/Services: 192.168.50.0/24

## Policies (ACL-style)
- Sales ❌ IT
- Ops ❌ Mgmt
- Mgmt outbound restricted (baseline)

## How to Run (later)
This lab is designed to be run via containerlab + docker.
Files included: topology + setup script + test script.
