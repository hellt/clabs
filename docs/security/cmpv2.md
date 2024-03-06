|                               |                                                                                      |
| ----------------------------- | ------------------------------------------------------------------------------------ |
| **Description**               | Certificate Management with CMPv2                                                    |
| **Components**                | Nokia SR OS, EJBCA                                                                   |
| **Resource requirements**[^1] | :fontawesome-solid-microchip: 2 <br/>:fontawesome-solid-memory: 6 GB                 |
| **Topology file**             | [cmp.clab.yml](https://github.com/hellt/clabs/blob/main/labs/cmpv2/cmp.clab.yml)     |
| **Version information**[^2]   | `containerlab:0.12.0`, `vr-sros:21.2.R1`, `docker-ce:19.03.13`, `vrnetlab:0.2.3`[^3] |
| **Authors**                   | Colin Bookham, [Roman Dodin](https://twitter.com/ntdvps)                             |

Management protocols of the modern day and age must be secure, there is not disagreement in that. But adding security layers is not free, the costs of having a secured communication is spread across development, capex/opex, support and many other domains.

Some state of the art management protocols like [gNMI](https://github.com/openconfig/reference/blob/master/rpc/gnmi/gnmi-specification.md) do not even assume they can be used without a security layer on top[^4], which implies that its users will have to setup the necessary security infrastructure before gNMI can be used.

??? "but what about unsecured gNMI?"
    It is a networking vendor's hack that allowed users to start playing with gNMI without setting up PKI infra. While it is possible, the gNMI specification clearly states that "The session between the client and server MUST be encrypted using TLS...".

In case of gNMI, TLS protocol is used to secure the session between the client and the server. That inherently means:

* Certificate Authority (CA) must exist
* a set of keys and a certificate signing request (csr) must be created for a gNMI server (a router)
* CA has to sign this certificate
* A router needs to import this certificate and use it for gNMI protocol it runs

As streaming telemetry and, consequently, gNMI are getting more popular, outgrowing the labs' simplified environments, operators are getting challenged with a question of **how to enable certificate management for network devices at scale?**

## Certificate management in an operator' network

If you think that creating a CA and signing a few certificates is an easy thing to pull off with something like `openssl` or `certbot`, you might want to reconsider when a network of an operator is concerned.

Network Operating Systems are not suitable to be used for something like `certbot`, as they won't be able to pass ACME challenge, nor DNS one. The manual certificate management with `openssl` can't stand a chance in a network with dozens and hundreds of nodes, this will get unmaintainable rather quickly.

Ideally a workflow for maintaining certificates lifecycle in the operators network could look like this:

1. CA maintains a registry of authenticated hosts for which it can enroll a certificate
2. A node generates or obtains private/public keys
3. A node contacts CA, authenticates and asks to issue/sign the certificate for it
4. The signed certificate is transferred from CA to the node over the same channel
5. Node installs that certificate
6. Before the certificate is about to expire, the node reaches to CA and asks it to issue a new certificate that the node uses instead of the one that is expiring

## CMPv2

Luckily, a few protocols exist to adhere to a workflow like that, and in this tutorial we will focus on one of them - CMPv2[^5].

CMPv2 is extensively used in mobile networks to manage certificates between the infrastructure nodes and it is also implemented by most networking vendors.

Without going into much details it is sufficient to say, that CMPv2 follows the workflow outlined above and this lab will demonstrate how Nokia SR OS router can initiate a certificate enrollment process and update it when needed.

To make use of CMPv2 we need to have a CA that supports that protocol. This lab uses EJBCA server from primekey via their official [docker image](https://hub.docker.com/r/primekey/ejbca-ce).

!!!info
    The purpose of this lab is to provide a complete environment to demonstrate how CMPv2 can be used to manage certificates in an operator' network.

## Deploying a lab

As usual with containerlab labs any deployment is a one-click task. Copy this lab' [clab file](https://github.com/hellt/clabs/blob/main/labs/cmpv2/cmp.clab.yml), ensure that you have `_license.txt` file for SR OS node available in your current working directory and deploy.

```
❯ clab dep -t cmp.clab.yml
INFO[0000] Parsing & checking topology file: cmp.clab.yml 
INFO[0000] Creating lab directory: /root/clabs/labs/cmpv2/clab-cmp 
INFO[0000] Creating container: ejbca                    
INFO[0000] Creating container: sr                       
INFO[0001] Writing /etc/hosts file                      
+---+----------------+--------------+--------------------------+---------+-------+---------+----------------+----------------------+
| # |      Name      | Container ID |          Image           |  Kind   | Group |  State  |  IPv4 Address  |     IPv6 Address     |
+---+----------------+--------------+--------------------------+---------+-------+---------+----------------+----------------------+
| 1 | clab-cmp-ejbca | 14f21198f5a7 | primekey/ejbca-ce        | linux   |       | running | 172.20.20.6/24 | 2001:172:20:20::6/80 |
| 2 | clab-cmp-sr    | 8e3123c84b3a | vrnetlab/vr-sros:21.2.R1 | vr-sros |       | running | 172.20.20.5/24 | 2001:172:20:20::5/80 |
+---+----------------+--------------+--------------------------+---------+-------+---------+----------------+----------------------+
```

??? "Persistent EJBCA"
    The clab file configuration for EJBCA assumes that no persistency is needed across lab runs. When the lab is destroyed, EJBCA config are removed as well. If EJBCA persistency is desired, users need to create a directory on their container host and mount it in the clab file like that:  
    ```yaml
    binds:
      - /home/ejbca:/mnt/persistent
    ```  
    This will save the EJBCA database under the `/home/ejbca` dir on the container host

When the lab starts, the EJBCA enters its initialization routine. You can monitor the progress with `docker logs -f clab-cmp-ejbca`. Once finished, the EJBCA web server will be available via `8443` port.

## EJBCA Configuration

EJBCA exposes web interface for its configuration. To access the main admin panel we use HTTPS connection over 8443 port - `https://localhost:8443/ejbca/adminweb/` - which is exposed by containerlab to 8443 port of the container host.

![admin](https://gitlab.com/rdodin/pics/-/wikis/uploads/afe7c909f9d3087a2393428235442683/image.png)

### CMP Alias

From the EJBCA perspective the CMP protocol configuration is done with creating a "CMP Alias".

On the EJBCA Administration home page, select CMP Configuration in the left hand pane (under System Configuration) and add a CMP Alias; in our case named "CMP-Server".

Once it is added, select edit, and then in the CMP Authentication Module ensure that "DnPartPwd" is selected and that the Subject DN Part is CN. This is used to extract the username of the node from its CN field when the node reaches out to CA and asks to enroll its certificate.

![CMP](https://gitlab.com/rdodin/pics/-/wikis/uploads/cbfbd86e8774accdb50e69321053947b/image.png)

Select Save at the bottom of the window to commit the CMP configuration.

### Certificate Profile

The Certificate Profile is a one-off configuration requirement.  
By default, the EJBCA server uses a certificate profile called `ENDUSER`. This profile sets X.509v3 extensions for Key Usage and Extended Key Usage to TLS Client authentication and Email Protection only.

![certprof](https://gitlab.com/rdodin/pics/-/wikis/uploads/5d4b0058d70beb73cc758dbee65474e1/image.png)

Since we want to use the certificate for gNMI (TLS Server) and the default `ENDUSER` profile cannot be edited, we need to create a new certificate profile disabling these extensions.

From the EJBCA Administration home page, select Certificate Profiles under CA Functions, and add a new entry. The below output shows the creation of a certificate profile called END-ENTITY, which removes all X509v3 extensions with the exception of Subject Alternative Name.

![newcertprof](https://gitlab.com/rdodin/pics/-/wikis/uploads/27484b3a14c9a7d1a0e58254622eeaa7/image.png)

### End Entity Profile

The End Entity Profile is a one-off configuration requirement.

To allow End Entities to use the newly-created Certificate Profile, we need to create an End Entity profile to reference it.

From the EJBCA Administration home page, select End Entity Profiles under RA Functions. Add a new profile, in our case `EE-PROFILE`, and edit the following:

* In the subject DN Attributes pane, use the Subject DN Attributes drop-down menu to add the required parts of the DN. In this case we add Country, State, and Organisation in addition to the existing Common Name. Tick all of them as required.
* In the Other Subject Attributes pane, use the Subject Alternative Name drop-down menu to add IP Address. Again, tick as required.
* In the "Main Certificate Data" pane use the drop-down menu for Default Certificate Profile to select the END-ENTITY certificate profile. In the Other subject attributes pain select IP Address as the Subject Alternative Name.  Select Save at the bottom of the screen.

![eeprofile](https://gitlab.com/rdodin/pics/-/wikis/uploads/dca50bb1d0d4dca05c3102e7cbaf53d6/image.png)

There is no requirement to enter the Password (or Enrolment Code) in the End Entity Profile. This differs on a per End Entity basis and will therefore be entered at that level.

### End Entity

End Entity configuration is required for each and every router that will be issued with an X.509 certificate.

From the EJBCA Administration home page, select "Add End Entity" in the left hand pane under RA Functions.

* In the End Entity Profile field select the previously created `EE-PROFILE`
* The password or enrolment code should be the same value as the CN entered in the Subject DN Attributes section and also in the CMP Initial-Registration request subsequently sourced by the SR-OS node.
* Complete the subject DN attributes. This example uses Country (C), State (ST), Organisation (O), and Common Name (CN). Again, the same values will be used in the CMP Initial-Registration request subsequently sourced by the SR-OS node.
* Add the IP address as the subject alternative name so that the issued certificate will also be valid for node's IP address. In our case we will use the management IP address that containerlab assigned for us (172.20.20.5)
* Select the previously configured END-ENTITY profile as the certificate profile.

![ee](https://gitlab.com/rdodin/pics/-/wikis/uploads/db0147521ab56614b99717986ffd140f/image.png)

When all fields have been completed, select Add at the bottom of the screen. This completes EJBCA configuration.

## CA certificate

To let our SR OS node to verify the certificate chain and be able to use CMPv2 protocol with the EJBCA, we need to transfer the CA certificate to it.

CA certificate of the EJBCA server can be downloaded from the Registration Authority server that runs on EJBCA node.

From the EJBCA Administration homepage, in the left hand pane select RA Web, which opens up another "EJBCA's RA GUI" tab. From here select "CA Certificates and CRLs" from the options along the top of the screen, and then download the Management CA Certificate in PEM format simply by selecting the appropriate link.

!!!info
    Management CA certificate can also be downloaded from the headless VM using lynx or any other text-based browser.

Next copy over this certificate to the SR OS node:

```
scp ManagementCA.pem admin@clab-cmp-sr:cf3:/
Warning: Permanently added 'clab-cmp-sr,172.20.20.5' (RSA) to the list of known hosts.

admin@clab-cmp-sr's password:
ManagementCA.pem                                     100% 1848    18.7KB/s   00:00
```

We will import this certificate into SR OS at a later stage.

## SR OS Configuration

### Keys generation

To create a router's certificate we first need to have a private/public key pair. Many NOS'es allow to generate the keys "on-box", and that is what we will use here:

```
//admin certificate gen-keypair cf3:/sr-key size 2048 type rsa
```

The generation process create the keys, but they are not imported yet. To import the keys issue:

```
//admin certificate import type key input cf3:/sr-key output sr-key format der
```

### CA certificate import

Next step is to import the ManagementCA certificate of EJBCA. We copied it over a few steps before, now let's import it:

```
//admin certificate import type cert input cf3:/ManagementCA.pem output ManagementCA.pem format pem
```

When certificate/keys get imported, the artifacts are copied over to a system directory named `system-pki`. As a result of a previous import, there will be a key file present with a name `sr-key`.

The imported certificated can be displayed to ensure that it is the one that is needed:

```
//admin certificate display type cert format der cf3:/system-pki/ManagementCA.pem
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            22:41:be:6b:87:94:a6:34:06:ce:73:63:01:6e:e5:80:d2:34:2d:5c
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: UID=c-0gkhtv71ootnm60rn, CN=ManagementCA, O=EJBCA Container Quickstart
<SNIPPED>
```

### CA profile

Now it is time to touch PKI related configuration on SR OS. We start by configuring CA Profile which defines the Certificate Authority for our SR OS node. This profile will hold the CMPv2 configuration

```bash
edit-config private

# enable profile
/configure system security pki ca-profile "ejbca-profile" admin-state enable

# refer to the CA cert file we imported before
/configure system security pki ca-profile ejbca-profile cert-file ManagementCA.pem

# allow unprotected messages
/configure system security pki ca-profile ejbca-profile cmpv2 accept-unprotected-message error-message
/configure system security pki ca-profile ejbca-profile cmpv2 accept-unprotected-message pkiconf-message

# specify sender info during cmpv2 initial registration message
/configure system security pki ca-profile ejbca-profile cmpv2 always-set-sender-for-ir

# skip CRL check
/configure system security pki ca-profile "ejbca-profile" revocation-check crl-optional

# set URL of CMPv2 server
/configure system security pki ca-profile ejbca-profile cmpv2 url url-string http://172.20.20.6:8080/ejbca/publicweb/cmp/CMP-Server

# add CMPv2 authentication data
/configure system security pki ca-profile "ejbca-profile" cmpv2 key-list key 1 password sr

commit
```

Let's talk about the last two for a moment. There we first say how to reach CMPv2 server, and to get its address, we use the management address that containerlab assigned to EJBCA node (172.20.20.6 in our case), then goes the static URL until the last element where we specify the CMP Alias [created earlier](#cmp-alias) on EJBCA. Our CMP Alias was `CMP-Server`, thus it is appeared in the URL for EJBCA server.

Then we create a key-list that holds a password that should match the enrollment code that we used during [End Entity creation](#end-entity). We used `sr` as the password string, thus we are referencing it in plain text as `key 1`.

To verify the operation status of the CA Profile:

```
A:admin@sr# /show certificate ca-profile "ejbca-profile"

===============================================================================
PKI CA-Profile Information
===============================================================================
CA Profile     : ejbca-profile                  Admin State    : up
Description    : (Not Specified)
CRL File       : (Not Specified)
Cert File      : ManagementCA.pem
Oper State     : up
Oper Flags     : <none>
Revoke Chk     : crl-optional

CMPv2
-------------------------------------------------------------------------------
HTTP Timeout   : 30 secs                        Router         : Base
CA URL         : http://172.20.20.6:8080/ejbca/publicweb/cmp/CMP-Server
Sign Cert URL  : (Not Specified)
Unprot Err Msg : enabled                        Unprot Pki Conf: enabled
Same RecipNonce: disabled
for Poll-reqs
Set Sndr for IR: True
HTTP version   : 1.1
```

??? "Check SR OS <-> EJBCA connectivity"
    If something doesn't work, check if your router can reach EJBCA. In our case, EJBCA management IP is 172.20.20.6, so we can check if it's reachable from SR OS:  
    ```
    (pr)[/]
    A:admin@sr# ping 172.20.20.6 router-instance "management"
    PING 172.20.20.6 56 data bytes
    64 bytes from 172.20.20.6: icmp_seq=1 ttl=63 time=0.668ms.
    ```

## CMPv2 Protocol Operations

### Initial Registration

Protocol wise everything starts with Initial Registration message that End Entity (SR OS router) node sends towards CMP server (EJBCA).

Use the following `admin certificate` command to send the CMPv2 initial-registration message and receive a signed certificate from the CA. The protection-algorithm in use is `password`, and the actual password should be equivalent to the value of CN as configured in the [EJBCA End Entity Configuration](#end-entity), as should the values entered in the subject-dn.

```
//admin certificate cmpv2 initial-registration ca "ejbca-profile" key-to-certify sr-key protection-alg password sr reference 1 subject-dn C=NL,ST=ZH,O=Nokia,CN=sr ip-addr 172.20.20.5 save-as cf3:/sr-cert.der

Processing request...
Received 'accepted'.
```

With this command we made SR OS node to contact CMPv2 Server running on EJBCA and requesting it to enroll a certificate for it. Since EJBCA had an End Entity configured with matched Subject DN fields and plain text password authentication, the request succeeded, and SR OS got its signed certificate. The certificate will be valid for IP SAN `172.20.20.5`.

The request that SR OS sent can be viewed with the following command:

```
//admin certificate cmpv2 show-request ca "ejbca-profile"

===============================================================================
CMPv2 Request
===============================================================================
CA Profile          : ejbca-profile
Original Request    : initialRegistration
Request Start Time  : 2021/03/30 19:24:40
Message Protection  : password-based
Reference number    : 1
Subject DN          : C=NL,ST=ZH,O=Nokia,CN=sr
Subject Alt. Name
    Domain Name     : (Not Specified)
    IP Address      : (Not Specified)
Key to Certify      : sr-key
Save-as file path   : cf3:\sr-cert.der
Request Status      : processed
CA Response         : accepted
CA Reply Time       : 2021/03/30 19:24:41
Additional Info     : (Not Specified)
===============================================================================
```

To display the freshly minted certificate:

```
//admin certificate display type cert format der cf3:/sr-cert.der

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            08:92:70:57:1e:d6:f7:93:5f:1a:26:d4:9e:cf:be:66:88:07:80:07
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: UID=c-0gkhtv71ootnm60rn, CN=ManagementCA, O=EJBCA Container Quickstart
        Validity
            Not Before: Mar 30 19:24:28 2021 GMT
            Not After : Mar 30 19:24:28 2023 GMT
        Subject: CN=sr, O=Nokia, ST=ZH, C=NL
        <SNIP>
        X509v3 extensions:
            X509v3 Subject Alternative Name:
                IP Address:172.20.20.6
```

As the above output shows, the received certificate is indeed signed by EJBCA and is enrolled for our SR OS node, valid for both Subject-DN and node's IP Address.

!!!info ":material-shark-fin: packet capture"
    [This pcap](https://gitlab.com/rdodin/pics/-/wikis/uploads/85e2c84bc7a9672fc2f186ed14c1d89d/Initial-Registration.pcapng) captures the message exchange during the initial-registration request, consisting of initialisation request (ir), initialisation response (ip),  certificate confirmation, and PKI confirmation

Once the certificate has been passed by the CA, it needs to be imported so that it can be used for PKI purposes. Note that because the input file is in DER format, the output file is also in DER format. Outputting to a different format will result in a failed import.

```
//admin certificate import type cert input cf3:/sr-cert.der output sr-cert format der
```

### Configure & verify secured gNMI

To test that the issued certificate is good to be used for secured gNMI we need to create another SR OS constructs - Certificate Profile and TLS Server Profile.

Readers can refer to ["Securing gNMI with TLS"](https://containerlab.srlinux.dev/lab-examples/tls-cert/) lab which goes into details of this, here we will just repeat the needed commands:

```bash
# configure certificate profile
/configure system security tls cert-profile sr-cert-prof entry 1 certificate-file sr-cert
/configure system security tls cert-profile sr-cert-prof entry 1 key-file sr-key
/configure system security tls cert-profile sr-cert-prof admin-state enable

# ciphers list
/configure system security tls server-cipher-list "ciphers" cipher 1 name tls-rsa-with3des-ede-cbc-sha
/configure system security tls server-cipher-list "ciphers" cipher 2 name tls-rsa-with-aes128-cbc-sha256

# configure server profile
/configure system security tls server-tls-profile sr-server-tls-prof cert-profile "sr-cert-prof" admin-state enable
/configure system security tls server-tls-profile sr-server-tls-prof cert-profile "sr-cert-prof" cipher-list "ciphers"

# make gNMI to use tls profile
/configure system grpc tls-server-profile "sr-server-tls-prof"
commit
```

Now when gNMI is configured to use the TLS security, we can verify that it all works by using [gnmic](https://gnmic.kmrd.dev) client with specifying the EJBCA CA file for verification.

```bash
# using Mgmt IP address of the node
gnmic -a 172.20.20.5 -u admin -p admin  --tls-ca /root/clabs/labs/cmpv2/ManagementCA.pem capabilities
gNMI version: 0.7.0
supported models:
  - nokia-conf, Nokia, 21.2.R1
  - nokia-state, Nokia, 21.2.R1
  - nokia-li-state, Nokia, 21.2.R1
  - nokia-li-conf, Nokia, 21.2.R1
supported encodings:
  - JSON
  - BYTES
  - PROTO
```

At this stage, we demonstrated how a network node can successfully enroll its certificate that can be used to secure the gNMI communication channel. What we haven't covered yet is the way to manage the certificate lifecycle. That is the goal of the subsequent sections.

### Certificate Request

A Certificate Request message is used to obtain a new certificate after the End Entity has obtained the initial certificate from the CA. The message flow is similar to that of the Initial Request and consists of the Certificate Request (cr) and Certificate Response (cp), followed by the Certificate Confirmation and PKI Confirmation.

When making the Certificate-Request for a new certificate a requirement is to generate and load the new certificate without having to make any configuration changes to the TLS configuration. At present, the SR OS TLS cert-profile references a certificate with the name of "sr-cert" and a key-pair with the name of "sr-key".

```
(pr)[/configure system security tls cert-profile "sr-cert-prof"]
A:admin@sr# info
    admin-state enable
    entry 1 {
        certificate-file "sr-cert"
        key-file "sr-key"
    }
```

The certificate request requires generation of a new keypair. Note that when the key is output to the `system-pki` directory the same filename is used as that already referenced in the TLS cert-profile.

```
//admin certificate gen-keypair cf3:/sr-key size 2048 type rsa
//admin certificate import type key input cf3:/sr-key output sr-key format der
```

The syntax of the Certificate Request from the router is similar to that of the Initial Request, with the notable exception that no password protection is required as the digital signature from the previously issued certificate is used as a form of authentication. The command
calls the old keypair as well as the newly-generated keypair, but in this case they refer to the same filename.

!!!note
    To make a certificate request to the EJBCA server before a certificate has expired, search the relevant End Entity and change the Status of that End Entity from "Generated" to "New".  
    As well as delete the existing certificate file from SR OS compact flash: `file remove cf3:/sr-cert.der` before requesting a new certificate.

```
//admin certificate cmpv2 cert-request ca "ejbca-profile" current-key sr-key current-cert sr-cert newkey sr-key subject-dn C=NL,ST=ZH,O=Nokia,CN=sr ip-addr 172.20.20.5 save-as cf3:/sr-cert.der
Processing request...
Received 'accepted'.
```

The "accepted" indication means that the certificate was successfully issued by the CA. This can also be verified with the following command.

```
//admin certificate cmpv2 show-request ca "ejbca-profile"

===============================================================================
CMPv2 Request
===============================================================================
CA Profile          : ejbca-profile
Original Request    : certRequest
Request Start Time  : 2021/03/31 07:15:20
Message Protection  : signature-based
Current Certificate : sr-cert
Hash Algorithm      : sha1
Subject DN          : C=NL,ST=ZH,O=Nokia,CN=sr
Subject Alt. Name
    Domain Name     : (Not Specified)
    IP Address      : 172.20.20.5
Current Key         : sr-key
New Key             : sr-key
Save-as file path   : cf3:\sr-cert.der
Request Status      : processed
CA Response         : accepted
CA Reply Time       : 2021/03/31 07:15:20
Additional Info     : (Not Specified)
===============================================================================
```

!!!info ":material-shark-fin: packet capture"
    [This pcap](https://gitlab.com/rdodin/pics/-/wikis/uploads/0c37a4dd9b2a0023cee57782f6a5260c/Certificate-Request.pcapng) captures the message exchange during the Certificate Request procedure.

It is thereafter necessary to import the received certificate into the `system-pki` directory for use.

```
//admin certificate import type cert input cf3:/sr-cert.der output sr-cert format der
```

Finally, it is necessary to do a reload of the certificate and keypair to ensure that the new keypair and certificate are loaded into memory.

```
//admin certificate reload type cert-key-pair sr-cert protocol tls key-file sr-key
```

The reload status can be seen in log 101:

```
A:admin@sr# /show log log-id 101

===============================================================================
Event Log 101 log-name 101
===============================================================================
Description : Default NETCONF event stream
Log contents  [size=500   next event=249  (not wrapped)]

248 2021/03/31 07:21:20.403 UTC MINOR: SECURITY #2101 Base TLS
"Certificate file "sr-cert" has been reloaded."

247 2021/03/31 07:21:20.403 UTC MINOR: SECURITY #2101 Base TLS
"Key file "sr-key" has been reloaded."
```

Now we can again check that gNMI client can successfully call the RPCs over a secure channel with a new node certificates in place.

### Automated certificate renewal

As demonstrated above, Certificate Request message can be used to re-issue a new certificate. Let's close the loop here and create an automated renewal routine that will result in a router to request a new certificate by the time a current one is about to expire.

The SR OS PKI configuration provides an option for generating expiration warnings when a certificate and/or CRL is about to expire. On our node we configured the certificate expiration warning to be 6 hours, with a repeat warning every subsequent hour:

```
/configure system security pki certificate-expiration-warning hours 6 repeat-hours 1
```

The corresponding log event looks like the following:

```
*A:pe-1# show log log-id 90

===============================================================================
Event Log 90
===============================================================================
Description : (Not Specified)
Memory Log contents  [size=100   next event=114  (wrapped)]

113 2021/03/15 15:47:51.997 GMT MINOR: SECURITY #2095 Base Cert
"Certificate pe1-cert used by TLS will expire in 5 hour(s) and 0 minute(s)."

110 2021/03/15 14:47:51.997 GMT MINOR: SECURITY #2095 Base Cert
"Certificate pe1-cert used by TLS will expire in 6 hour(s) and 0 minute(s)."
```

The system is configured to use the Event Handling System such that when the certificate expiration alarm is generated with an hour to go, that the system will request and install a new certificate. A key role in this procedure plays a script that is executed when a certain message appears in the log.

```
//file show auto-cert-update.txt
File: auto-cert-update.txt
-------------------------------------------------------------------------------
exit all
file remove cf3:/sr-cert.der force
sleep 2
//admin certificate gen-keypair cf3:/sr-key size 2048 type rsa
sleep 5
//admin certificate import type key input cf3:/sr-key output sr-key format der
sleep 5
//admin certificate cmpv2 cert-request ca "ejbca-profile" current-key sr-key current-cert sr-cert newkey sr-key subject-dn C=NL,ST=ZH,O=Nokia,CN=sr ip-addr 172.20.20.5 save-as cf3:/sr-cert.der
sleep 10
//admin certificate import type cert input cf3:/sr-cert.der output sr-cert format der
sleep 5
//admin certificate reload type cert-key-pair sr-cert protocol tls key-file sr-key
exit all
```

Essentially this script just repeats the steps we did manually before.

The following snipped shows configuration steps required to configure EHS subsystem of SR OS to call the script when the certificate only has 1 hour left before expiry:

```bash
# create script control policy
/configure system script-control script "auto-cert-update" location cf3:/auto-cert-update.txt admin-state enable
/configure system script-control script-policy "auto-cert-update" results "cf3:/cert-update-results.txt" admin-state enable
/configure system script-control script-policy "auto-cert-update" script name "auto-cert-update"

# configure log filter to match on a message about cert expiration
/configure log filter 100 default-action drop
/configure log filter 100 named-entry cert-update action forward
/configure log filter 100 named-entry cert-update match message eq  "Certificate sr-cert used by TLS will expire in 1 hour(s) and 0 minute(s)"

# create event handler that will call a previously created script
/configure log event-handling handler "auto-cert-update" entry 1 script-policy name "auto-cert-update"
/configure log event-handling handler "auto-cert-update" admin-state enable

# configure event trigger to match on log filter rule and call the handler
/configure log event-trigger security event tmnxPkiCertBeforeExpWarning entry 1 handler "auto-cert-update" admin-state enable
/configure log event-trigger security event tmnxPkiCertBeforeExpWarning entry 1 filter "100"
/configure log event-trigger security event tmnxPkiCertBeforeExpWarning admin-state enable
```

After the certificate has expired there are various places which can be used to confirm the EHS script was successful. Firstly, a check of log 99, which shows that the SROS CLI file cf3:/auto-cert-update was completed successfully.

```
*A:pe-1# show log log-id 99

===============================================================================
Event Log 99
===============================================================================
Description : Default System Log
Memory Log contents  [size=500   next event=3223  (wrapped)]

3222 2021/03/16 03:30:58.138 GMT MAJOR: SYSTEM #2053 Base CLI 'exec'
"The CLI user initiated 'exec' operation to process the commands in the SROS CLI file cf3:/auto-cert-update.txt has completed with the result of success"

3221 2021/03/16 03:30:26.001 GMT MAJOR: SYSTEM #2052 Base CLI 'exec'
"A CLI user has initiated an 'exec' operation to process the commands in the SROS CLI file cf3:/auto-cert-update.txt"

3220 2021/03/16 03:30:25.997 GMT MINOR: SYSTEM #2069 Base EHS script
"Ehs handler :"auto-cert-update" with the description : "" was invoked by the cli-user account "not-specified"."
```

Finally, a users can check of the event-handling handler "auto-cert-update" shows a success, and the last time the script was executed.

```
show log event-handling handler "auto-cert-update"

===============================================================================
Event Handling System - Handlers
===============================================================================

===============================================================================
Handler          : auto-cert-update
===============================================================================
Description      : (Not Specified)
Admin State      : up                                Oper State : up

-------------------------------------------------------------------------------
Handler Execution Statistics
  Success        : 1
  Err No Entry   : 0
  Err Adm Status : 0
Total            : 1

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
Handler Action-List Entry
-------------------------------------------------------------------------------
Entry-id         : 10
Description      : (Not Specified)
Admin State      : up                                Oper State : up
Script
  Policy Name    : auto-cert-update
  Policy Owner   : TiMOS CLI
Min Delay        : 0
Last Exec        : 03/16/21 03:30:26 BST
-------------------------------------------------------------------------------
Handler Action-List Entry Execution Statistics
  Success        : 1
  Err Min Delay  : 0
  Err Launch     : 0
  Err Adm Status : 0
Total            : 1
===============================================================================
```

## Summary

Handling of PKI infrastructure and TLS certificates is a complicated matter when a network of hundreds of nodes is concerned. An automated solution is needed to allow for certificate enrollment and lifecycle management.

CMPv2 protocol is one of the protocols aimed to solve that task in a network infrastructure domain. Being extensively used in 4G and 5G networks, it is also applicable to nodes in the operators network. This lab demonstrated CMPv2 protocol operations and how it can be used to automatically enroll and renew certificates for an SR OS router using EJBCA server.

The benefit of CMPv2 and protocols like it is in their ability to scale without increasing the operational effort. Once configured, the new nodes will come up with their templated configuration and will be able to request certificates and auto-renew them when time comes.

[^1]: Resource requirements are provisional. Consult with the installation guides for additional information. Memory deduplication techniques like [UKSM](https://netdevops.me/2021/how-to-patch-ubuntu-2004-focal-fossa-with-uksm/) might help with RAM consumption.
[^2]: The lab has been validated using these versions of the required tools/components. Using versions other than stated might lead to a non-operational setup process.
[^3]: Router images are built with vrnetlab [v0.2.3](https://github.com/hellt/vrnetlab/tree/v0.2.3). To reproduce the image, checkout to this commit and build the relevant images. Note, that you might need to use containerlab of the version that is stated in the description.
[^4]: <https://github.com/openconfig/reference/blob/master/rpc/gnmi/gnmi-specification.md#31-session-security-authentication-and-rpc-authorization>
[^5]: The protocol is defined in RFC4210, RFC4211 and RFC4212, with further guidance in the transmission of CMP messages over HTTP being defined in RFC6712.
