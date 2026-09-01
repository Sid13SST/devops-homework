# Networking — Homework

Source task: **Networking Homework Tasks** (Task 1 practise the commands, Task 2 create a `.md` file with the command output and an explanation of each).

This README **is** the Task 2 deliverable. Every command below was actually executed and the output is copied verbatim.

| File | What it is |
|---|---|
| [`networking-demo.sh`](networking-demo.sh) | The script that runs every command in this document |
| [`networking-output.txt`](networking-output.txt) | The complete unedited transcript |

> **Environment note.** The commands were run inside an `ubuntu:24.04` container (granted `NET_ADMIN` and `NET_RAW` so that `ping`, `traceroute` and `tcpdump` work) on a Windows 11 host. The container sits on Docker's default bridge, so its own address is `172.17.0.12/16` and its gateway is `172.17.0.1`.
>
> **Task 1 note.** The task refers to "commands and repo shared in devops-hero github repo". That repository link was not included in the handout I received, so rather than guess at the wrong repo I have covered the standard Linux networking toolkit end to end below — interface config, routing, ICMP, DNS, sockets, port reachability, HTTP clients, ARP, WHOIS and packet capture. If a specific repo is required, point me at it and I will fold its exercises in.
>
> **Privacy note.** One command (`curl https://api.ipify.org`) returns the machine's public IP address. It is shown as `<REDACTED-PUBLIC-IP>` here and in the transcript, since this is a public repository.

---

## 1. Interface configuration — `ip addr`, `ifconfig`, `hostname`

**What I understood:** these answer "what network interfaces does this machine have, and what addresses are on them?" `ip` is the modern tool from `iproute2`; `ifconfig` is the deprecated `net-tools` equivalent that still shows up everywhere. Every Linux box has at least `lo` (loopback, `127.0.0.1`, traffic that never leaves the machine) plus one real interface.

```
$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0@if102: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 1e:ef:c0:5b:b9:c6 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.12/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
```

Reading it: `eth0` is **UP**, has MAC `1e:ef:c0:5b:b9:c6`, IPv4 `172.17.0.12` with a `/16` mask (so the subnet is `172.17.0.0` – `172.17.255.255`), and an **MTU of 1500** bytes — the largest frame it will send without fragmenting.

`ip -brief addr` is the version you actually want day to day:

```
$ ip -brief addr show
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0@if102       UP             172.17.0.12/16
```

`ifconfig` shows the same thing plus cumulative packet counters, which is handy for spotting errors and drops:

```
$ ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.12  netmask 255.255.0.0  broadcast 172.17.255.255
        ether 1e:ef:c0:5b:b9:c6  txqueuelen 0  (Ethernet)
        RX packets 54583  bytes 77440726 (77.4 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 40693  bytes 2855430 (2.8 MB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

`RX/TX errors 0, dropped 0` is what a healthy interface looks like. Non-zero drops point at a cabling, driver or buffer problem.

| Command | Purpose |
|---|---|
| `ip addr show` | All interfaces and their IP addresses |
| `ip -brief addr` | Same, one line per interface |
| `ip link show` | Layer-2 view — MAC addresses and link state |
| `ip link set eth0 up/down` | Bring an interface up or down |
| `ifconfig` | Legacy equivalent, includes packet counters |
| `hostname` | The machine's name |
| `hostname -I` | Just the IP addresses, space separated |

---

## 2. Routing — `ip route`, `route -n`, `netstat -rn`

**What I understood:** the routing table is the decision list the kernel walks for **every** outbound packet: "given this destination address, which interface do I send it out of, and to which next hop?" The **default route** is the catch-all used when nothing more specific matches — effectively "the way out to the internet".

```
$ ip route show
default via 172.17.0.1 dev eth0
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.12
```

Two rules. Anything inside `172.17.0.0/16` is **on the same link**, so it goes out `eth0` directly with no router involved. Everything else goes to the **gateway `172.17.0.1`**, which forwards it on.

`ip route get` is the best troubleshooting command here — it asks the kernel to actually make the decision for one address and show its working:

```
$ ip route get 8.8.8.8
8.8.8.8 via 172.17.0.1 dev eth0 src 172.17.0.12 uid 0
    cache
```

"To reach 8.8.8.8, send via 172.17.0.1 out of eth0, using 172.17.0.12 as the source address." When connectivity breaks, this instantly tells you whether the problem is routing or something further up.

```
$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.17.0.1      0.0.0.0         UG    0      0        0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth0
```

Same table in the legacy format. `0.0.0.0/0.0.0.0` **is** the default route; flag `G` means it goes through a gateway, `U` means the route is up.

---

## 3. Connectivity testing — `ping`

**What I understood:** `ping` sends **ICMP echo request** packets and times the replies. It answers three questions at once: does the name resolve, is the host reachable, and how good is the path (latency and loss)? It does **not** test whether an application or port is working — a host can ping fine while its web server is down.

```
$ ping -c 4 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=63 time=55.8 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=63 time=62.8 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=63 time=52.9 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=63 time=50.7 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 50.711/55.543/62.792/4.554 ms
```

The numbers that matter: **0% packet loss** (nothing is being dropped), **avg 55.5 ms** round trip, and **mdev 4.5 ms** — jitter, the variation between packets. High loss means a broken or congested path; high jitter breaks voice and video.

`ttl=63` is a useful detail: TTL starts at 64 and is decremented by one per router, so 63 means the reply crossed **one** hop on the way back.

Pinging a name tests DNS at the same time:

```
$ ping -c 3 google.com
PING google.com (173.194.41.100) 56(84) bytes of data.
64 bytes from 173.194.41.100: icmp_seq=1 ttl=63 time=63.9 ms
...
3 packets transmitted, 3 received, 0% packet loss, time 2001ms
rtt min/avg/max/mdev = 63.919/68.954/78.310/6.621 ms
```

| Flag | Meaning |
|---|---|
| `-c N` | Stop after N packets (otherwise it runs forever) |
| `-i N` | Interval between packets |
| `-s N` | Payload size — useful for hunting MTU problems |
| `-W N` | Per-reply timeout |

---

## 4. Path tracing — `traceroute`

**What I understood:** `traceroute` finds every router between you and a destination. It works by sending packets with **deliberately small TTL values** — TTL 1 expires at the first router, which reports back "time exceeded", revealing itself; TTL 2 reveals the second, and so on. It tells you *where* along the path traffic is slow or dying, which `ping` cannot.

```
$ traceroute -m 8 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 8 hops max, 60 byte packets
 1  172.17.0.1 (172.17.0.1)  0.812 ms  0.045 ms  0.006 ms
 2  * * *
 3  * * *
 4  * * *
 ...
```

Hop 1 is the Docker bridge gateway, answering in well under a millisecond. Hops 2+ show `* * *`.

**`* * *` does not mean the path is broken** — the earlier `ping 8.8.8.8` proved the destination is perfectly reachable. It means those routers are configured **not to send ICMP time-exceeded replies**, which is normal for hardened networks, and is doubly expected here because the traffic is leaving a container inside a WSL2 VM behind NAT. `traceroute -T` (TCP) or `-I` (ICMP) sometimes gets further than the default UDP probes.

---

## 5. DNS resolution — `nslookup`, `dig`, `host`

**What I understood:** DNS turns names into IP addresses. Nothing else in networking works until this does, so it is the **first** thing to check when "the site is down". Common record types: **A** (IPv4), **AAAA** (IPv6), **MX** (mail), **CNAME** (alias), **NS** (nameserver), **TXT** (arbitrary text, used for SPF/verification).

```
$ nslookup github.com
Server:		192.168.65.7
Address:	192.168.65.7#53

Non-authoritative answer:
Name:	github.com
Address: 20.207.73.82
```

`Server:` is the resolver that answered, on the standard DNS port **53**. "Non-authoritative" means the answer came from a cache rather than from GitHub's own nameservers.

`dig` is the one to prefer — precise and scriptable:

```
$ dig github.com +short
20.207.73.82

$ dig github.com A +noall +answer
github.com.		13	IN	A	20.207.73.82

$ dig MX google.com +short
10 smtp.google.com.
```

In the answer line, `13` is the **TTL in seconds** — how long this result may be cached. A low TTL like that is typical of a service using load balancing or preparing to move.

```
$ host github.com
github.com has address 20.207.73.82
github.com mail is handled by 0 github-com.mail.protection.outlook.com.
```

Which resolver gets used is configured here:

```
$ cat /etc/resolv.conf
# Generated by Docker Engine.
nameserver 192.168.65.7
```

And `/etc/hosts` is checked **before** DNS — a static override, and the classic cause of "it resolves differently on my machine":

```
$ cat /etc/hosts
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
172.17.0.12	b7b333bace90
```

---

## 6. Sockets and listening ports — `ss`, `netstat`

**What I understood:** this answers "what is actually listening on this machine, and on which ports?" It is how you confirm a service really started, and how you find the process squatting on a port you need. `ss` is the modern replacement for `netstat` and is considerably faster.

A listener was started on port 9999 first so there was something to see:

```
$ ss -tuln
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:Port
tcp   LISTEN 0      1            0.0.0.0:9999      0.0.0.0:*
```

The flags decode as **`-t`** TCP, **`-u`** UDP, **`-l`** listening only, **`-n`** numeric (do not resolve names, which makes it instant).

`0.0.0.0:9999` means it is bound to **all** interfaces. Had it shown `127.0.0.1:9999`, the service would only be reachable from the machine itself — a very common reason a container or a remote client "cannot connect".

Add `-p` to get the owning process, which is what you actually need when a port is taken:

```
$ ss -tulnp
tcp   LISTEN 0      1     0.0.0.0:9999   0.0.0.0:*   users:(("nc",pid=3081,fd=3))
```

```
$ netstat -tuln
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State
tcp        0      0 0.0.0.0:9999            0.0.0.0:*               LISTEN
```

A quick summary of all socket states:

```
$ ss -s
Total: 6
TCP:   81 (estab 0, closed 80, orphaned 0, timewait 2)

Transport Total     IP        IPv6
TCP	  1         1         0
```

`timewait` sockets are normal — a closed connection lingers briefly so late packets are not misdelivered.

---

## 7. Port reachability — `nc` (netcat)

**What I understood:** `ping` proves a *host* is up; `nc -z` proves a specific **TCP port** is open, which is what actually matters for a service. This is the fastest way to tell a firewall problem from an application problem.

```
$ nc -zv github.com 443
Connection to github.com (20.207.73.82) 443 port [tcp/*] succeeded!

$ nc -zv -w 3 github.com 80
Connection to github.com (20.207.73.82) 80 port [tcp/*] succeeded!
```

`-z` means "scan only, send no data", `-v` verbose, `-w` timeout.

Bash can do the same with no tools installed at all, using its `/dev/tcp` pseudo-device — worth remembering for stripped-down containers:

```
$ timeout 5 bash -c 'cat < /dev/null > /dev/tcp/github.com/443' && echo 'port 443 reachable via bash /dev/tcp'
port 443 reachable via bash /dev/tcp
```

`nc` is also a listener (`nc -l -p 9999`) and a file-transfer tool, which is why it is nicknamed the network Swiss army knife.

---

## 8. HTTP clients — `curl`, `wget`

**What I understood:** these move a layer up, from "is the port open" to "is the **application** answering correctly". `curl` prints to stdout and is the better debugging tool; `wget` is the better downloader because it recurses and resumes.

`curl`'s `-w` flag turns it into a measuring instrument:

```
$ curl -s -o /dev/null -w 'HTTP %{http_code}  time=%{time_total}s  ip=%{remote_ip}\n' https://api.github.com
HTTP 200  time=0.499105s  ip=20.207.73.85
```

Status **200**, total time, and the IP actually connected to — all without printing the body.

`-I` fetches only the headers, which is usually all you need:

```
$ curl -sI https://github.com | head -8
HTTP/2 200
date: Tue, 01 Sep 2026 13:07:07 GMT
content-type: text/html; charset=utf-8
content-language: en-US
vary: X-PJAX, X-PJAX-Container, Turbo-Visit, Turbo-Frame, X-Requested-With, X-GitHub-Client-Version, Accept-Language, Sec-Fetch-Site,Accept-Encoding, Accept, X-Requested-With
etag: W/"3df5fd11ca5b9a0c6252c212016de248"
cache-control: max-age=0, private, must-revalidate
strict-transport-security: max-age=31536000; includeSubdomains; preload
```

`HTTP/2` and the HSTS header are visible, along with `cache-control`, `etag` and `vary` — headers are where you diagnose caching, redirects, content negotiation and TLS policy.

`wget --spider` checks a URL exists without downloading it:

```
$ wget -q -S --spider https://github.com
  HTTP/1.1 200 OK
  Date: Tue, 01 Sep 2026 13:07:07 GMT
  Content-Type: text/html; charset=utf-8
  content-language: en-US
  ETag: W/"3df5fd11ca5b9a0c6252c212016de248"
  Cache-Control: max-age=0, private, must-revalidate
  Strict-Transport-Security: max-age=31536000; includeSubdomains; preload
```

| Flag | Meaning |
|---|---|
| `curl -I` | Headers only |
| `curl -L` | Follow redirects |
| `curl -o file` | Save to a file |
| `curl -X POST -d 'data'` | Send a POST |
| `curl -H 'Header: value'` | Add a request header |
| `wget -c` | Resume a partial download |

---

## 9. ARP / neighbour table — `ip neigh`, `arp`

**What I understood:** IP addresses are logical; actual delivery on a local network happens by **MAC address**. ARP is the protocol that asks "who has 172.17.0.1?" and caches the answer. The neighbour table is that cache — it only ever contains hosts on the **same subnet**, because anything further away is reached via the gateway.

```
$ ip neigh show
172.17.0.1 dev eth0 lladdr 76:0d:e0:71:5d:24 REACHABLE

$ arp -a
? (172.17.0.1) at 76:0d:e0:71:5d:24 [ether] on eth0
```

The gateway's MAC is cached and the entry is `REACHABLE`. Other states are `STALE` (needs revalidating) and `FAILED` (no answer — a genuine local connectivity fault). Two devices claiming the same IP with different MACs here is how you spot an IP conflict or ARP spoofing.

---

## 10. Public IP and WHOIS

**What I understood:** behind NAT, your machine has no idea what public IP the world sees it as — you have to ask an external service. `whois` queries domain registry records: owner, registrar, and creation/expiry dates.

```
$ curl -s https://api.ipify.org
<REDACTED-PUBLIC-IP>
```

```
$ whois github.com | head -12
   Domain Name: GITHUB.COM
   Registry Domain ID: 1264983250_DOMAIN_COM-VRSN
   Registrar WHOIS Server: whois.markmonitor.com
   Registrar URL: http://www.markmonitor.com
   Updated Date: 2024-09-07T09:16:32Z
   Creation Date: 2007-10-09T18:20:50Z
   Registry Expiry Date: 2026-10-09T18:20:50Z
   Registrar: MarkMonitor Inc.
   Registrar IANA ID: 292
   Registrar Abuse Contact Email: abusecomplaints@markmonitor.com
   Domain Status: clientDeleteProhibited https://icann.org/epp#clientDeleteProhibited
```

`clientDeleteProhibited` is a registrar lock preventing accidental or malicious deletion — standard for a domain that matters.

---

## 11. Packet capture — `tcpdump`

**What I understood:** when every other tool says things look fine but the application still fails, `tcpdump` shows you the packets themselves. It is the ground truth. A `ping 8.8.8.8` was run in the background while capturing ICMP:

```
$ tcpdump -i any -c 5 -n icmp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on any, link-type LINUX_SLL2 (Linux cooked v2), snapshot length 262144 bytes
13:07:15.908514 eth0  Out IP 172.17.0.12 > 8.8.8.8: ICMP echo request, id 3, seq 2, length 64
13:07:15.960839 eth0  In  IP 8.8.8.8 > 172.17.0.12: ICMP echo reply, id 3, seq 2, length 64
13:07:16.910145 eth0  Out IP 172.17.0.12 > 8.8.8.8: ICMP echo request, id 3, seq 3, length 64
13:07:16.981566 eth0  In  IP 8.8.8.8 > 172.17.0.12: ICMP echo reply, id 3, seq 3, length 64
13:07:17.911755 eth0  Out IP 172.17.0.12 > 8.8.8.8: ICMP echo request, id 3, seq 4, length 64
5 packets captured
6 packets received by filter
0 packets dropped by kernel
```

You can see request/reply pairs matched by sequence number, and the round-trip measured directly from the timestamps: `13:07:15.960839 − 13:07:15.908514 ≈ **52 ms**`, which matches what `ping` reported independently.

| Flag / filter | Meaning |
|---|---|
| `-i any` | Capture on all interfaces |
| `-c N` | Stop after N packets |
| `-n` | Do not resolve names (much faster) |
| `-w file.pcap` | Write to a file for Wireshark |
| `port 80` | Only traffic on port 80 |
| `host 8.8.8.8` | Only traffic to/from one host |
| `tcp`/`udp`/`icmp` | Only that protocol |

---

## 12. Interface statistics

**What I understood:** cumulative counters per interface. Steadily rising `errors` or `dropped` points at hardware, driver or buffer trouble rather than anything in your application.

```
$ netstat -i
Kernel Interface table
Iface             MTU    RX-OK RX-ERR RX-DRP RX-OVR    TX-OK TX-ERR TX-DRP TX-OVR Flg
eth0             1500    54697      0      0 0         40830      0      0      0 BMRU
lo              65536        0      0      0 0             0      0      0      0 LRU

$ ip -s link show eth0
2: eth0@if102: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT
    link/ether 1e:ef:c0:5b:b9:c6 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    RX:  bytes packets errors dropped  missed   mcast
      77476988   54697      0       0       0       0
    TX:  bytes packets errors dropped carrier collsns
       2868217   40830      0       0       0       0
```

All error and drop counters are zero — a clean interface.

---

## Quick reference

| Question | Command |
|---|---|
| What is my IP? | `ip -brief addr` / `hostname -I` |
| How do I get out to the internet? | `ip route show` |
| Which route will this address take? | `ip route get 8.8.8.8` |
| Is that host reachable? | `ping -c 4 host` |
| Where does the path break? | `traceroute host` |
| Does the name resolve? | `dig name +short` |
| What is listening here? | `ss -tulnp` |
| Is that port open? | `nc -zv host port` |
| Is the web app answering? | `curl -I https://host` |
| What is my public IP? | `curl https://api.ipify.org` |
| What is on the wire? | `tcpdump -i any -n port 80` |

### The order I would work through a "network is broken" report

1. `ip -brief addr` — do I have an address at all?
2. `ip route show` — do I have a default route?
3. `ping <gateway>` — is the local network fine?
4. `ping 8.8.8.8` — is the internet reachable **by IP**?
5. `dig google.com` — if step 4 works but names fail, it is **DNS**.
6. `nc -zv host port` — host is up, but is the **port** open?
7. `curl -I` — port is open, but is the **application** healthy?
8. `tcpdump` — everything looks fine and it still fails; watch the packets.
