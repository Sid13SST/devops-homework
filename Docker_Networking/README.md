# Docker Networking & Volumes — Homework

Source task: **Docker Networking & Volume Homework** (Task 1 container networking, Task 2 host network, Task 3 bind mount, Task 4 overlay networks).

Every command below was actually executed and the output is copied verbatim.

| Folder | What it is |
|---|---|
| [`bind-mount-demo/`](bind-mount-demo/) | The host folder bind-mounted into Nginx in Task 3 |
| [`screenshots/`](screenshots/) | Browser screenshots for Tasks 2 and 3 |

---

## Task 1 — Docker Container Networking

### What was built

Three containers across three user-defined bridge networks, with the **backend attached to two of them** so it can reach both sides while the frontend and database stay isolated from each other. This is the standard three-tier pattern: a web tier that must never touch the database directly.

```
        frontend-net                 backend-net              db-admin-net
   ┌────────────────────┐      ┌────────────────────┐      ┌──────────────┐
   │  frontend          │      │            database│      │ database     │
   │  (nginx:alpine)    │      │            (mysql) │      │ (admin path) │
   │  172.24.0.2        │      │         172.25.0.3 │      │ 172.26.0.2   │
   │                    │      │                    │      └──────────────┘
   │      backend ──────┼──────┼──── backend        │
   │      172.24.0.3    │      │     172.25.0.2     │
   └────────────────────┘      └────────────────────┘
              ▲                          ▲
              └──── one container, two network interfaces ────┘
```

### Create the three networks

```
$ docker network create frontend-net
a9bf21e5858bafd285df10a94ba5f2a404628a55eabfa862c1395c6f9afe0cb5
$ docker network create backend-net
3e2520c3941a48a914abb215702733b702295f0cb59f305ef9ffc902eb4af354
$ docker network create db-admin-net
73739be0c49a97e04f1e8a3d032840fefdd6321c2257271d640fdd0425efddfe
```

```
$ docker network ls
NETWORK ID     NAME           DRIVER    SCOPE
3e2520c3941a   backend-net    bridge    local
380a011dabce   bridge         bridge    local
73739be0c49a   db-admin-net   bridge    local
a9bf21e5858b   frontend-net   bridge    local
ca1c7c3c97b9   host           host      local
b7061e7020db   none           null      local
```

*(Unrelated project networks on this machine have been omitted from the listing above; the full output is unfiltered in the command history.)*

### Create the three containers

Nginx for the frontend, Alpine for the backend, MySQL for the database — as specified.

```
$ docker run -d --name frontend --network frontend-net nginx:alpine
75fdd5f12445d565d70621a444a5ecbdf996e75d1aee794b0de2b78b7e97151b

$ docker run -d --name backend --network backend-net alpine:3.20 sleep infinity
40f27c1d350753fc3ed0ffbe36317aace339cd2a88e0fd44074c0597b45e2070

$ docker run -d --name database --network backend-net -e MYSQL_ROOT_PASSWORD=StrongPass123 mysql:8.0
5102822ed514c47aa9772d15d9a5b9d3bce8a03cc01be80d5f580d0a4b816f60
```

`sleep infinity` keeps the Alpine container alive — a container exits as soon as its main process finishes, and Alpine's default command would return immediately.

### Add the backend to a second network

A container can only join one network in `docker run`. Additional networks are attached afterwards with `docker network connect`:

```
$ docker network connect frontend-net backend
(backend is now on backend-net + frontend-net)

$ docker network connect db-admin-net database
(database is now on backend-net + db-admin-net)
```

### Confirm membership

```
$ docker network inspect frontend-net --format '{{.Name}}: {{range .Containers}}{{.Name}} {{end}}'
frontend-net: backend frontend

$ docker network inspect backend-net --format '{{.Name}}: {{range .Containers}}{{.Name}} {{end}}'
backend-net: backend database

$ docker network inspect db-admin-net --format '{{.Name}}: {{range .Containers}}{{.Name}} {{end}}'
db-admin-net: database
```

Each container's addresses — note **backend has two**, one per network:

```
$ docker inspect backend --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}={{$v.IPAddress}} {{end}}'
backend-net=172.25.0.2 frontend-net=172.24.0.3

$ docker inspect frontend --format ...
frontend-net=172.24.0.2

$ docker inspect database --format ...
backend-net=172.25.0.3 db-admin-net=172.26.0.2
```

Every network got its own subnet: `172.24.0.0/16`, `172.25.0.0/16`, `172.26.0.0/16`.

### Connectivity test results

| From | To | Shared network? | Expected | Result |
|---|---|---|---|---|
| backend | frontend | frontend-net | reachable | **0% loss** |
| backend | database | backend-net | reachable | **0% loss** |
| backend | database:3306 | backend-net | port open | **open** |
| frontend | database | **none** | **fail** | **DNS failure** |
| frontend | backend | frontend-net | reachable | **0% loss** |

**Test 1 — backend → frontend (shared `frontend-net`)**

```
$ docker exec backend ping -c 3 frontend
PING frontend (172.24.0.2): 56 data bytes
64 bytes from 172.24.0.2: seq=0 ttl=64 time=1.416 ms
64 bytes from 172.24.0.2: seq=1 ttl=64 time=0.129 ms
64 bytes from 172.24.0.2: seq=2 ttl=64 time=0.122 ms

--- frontend ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.122/0.555/1.416 ms
```

**Test 2 — backend → database (shared `backend-net`)**

```
$ docker exec backend ping -c 3 database
PING database (172.25.0.3): 56 data bytes
64 bytes from 172.25.0.3: seq=0 ttl=64 time=1.024 ms
64 bytes from 172.25.0.3: seq=1 ttl=64 time=0.126 ms
64 bytes from 172.25.0.3: seq=2 ttl=64 time=0.124 ms

--- database ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.124/0.424/1.024 ms
```

**Test 3 — the MySQL port is actually reachable**, not just the host:

```
$ docker exec backend nc -zv database 3306
database (172.25.0.3:3306) open
```

**Test 4 — frontend → database: the isolation proof**

```
$ docker exec frontend ping -c 2 database
ping: bad address 'database'
exit code = 1
```

This is the point of the whole exercise. The frontend and the database share **no** network, so Docker's embedded DNS server does not even resolve the name `database` for the frontend — it fails at name resolution, before any packet is sent. The database is genuinely unreachable from the web tier, enforced by Docker rather than by application code.

**Test 5 — frontend → backend (shared `frontend-net`)**

```
$ docker exec frontend ping -c 3 backend
PING backend (172.24.0.3): 56 data bytes
64 bytes from 172.24.0.3: seq=0 ttl=64 time=0.115 ms
64 bytes from 172.24.0.3: seq=1 ttl=64 time=0.129 ms
64 bytes from 172.24.0.3: seq=2 ttl=64 time=0.129 ms

--- backend ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.115/0.124/0.129 ms
```

### What I learned

**User-defined bridge networks give you automatic DNS by container name.** `ping frontend` works with no `/etc/hosts` editing and no IP addresses hard-coded anywhere. This does **not** work on the legacy default `bridge` network, where you would need the deprecated `--link`. It is the main reason to always create your own network.

**A network is a security boundary.** Test 4 is the whole three-tier pattern in one line of output: the frontend physically cannot reach the database. Attaching the backend to both networks makes it the only path between them.

**Names beat IPs.** The addresses above (`172.24.0.3` etc.) are assigned by Docker's IPAM and change every time a container is recreated. Application config should always use the container name.

---

## Task 2 — Host Network

### Pull Apache and run it on the host network

```
$ docker pull httpd:2.4
Status: Image is up to date for httpd:2.4
docker.io/library/httpd:2.4

$ docker run -d --name apache-host --network host httpd:2.4
993bac5fff03c07f3eb8d64d9eb833dd61cf2dca8a937887917df2541905abf7
```

```
$ docker ps --filter name=apache-host --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Networks}}'
NAMES         IMAGE       STATUS         PORTS     NETWORKS
apache-host   httpd:2.4   Up 4 seconds             host

$ docker inspect apache-host --format 'NetworkMode={{.HostConfig.NetworkMode}}'
NetworkMode=host
```

Note the **empty PORTS column**. That is the defining characteristic of host networking: there is no port mapping, because there is no separate network namespace to map *from*. The container binds port 80 directly on the host's stack.

Apache confirms it started and bound successfully:

```
$ docker logs apache-host
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 192.168.65.3. Set the 'ServerName' directive globally to suppress this message
[Tue Sep 01 12:57:54.258600 2026] [mpm_event:notice] [pid 1:tid 1] AH00489: Apache/2.4.68 (Unix) configured -- resuming normal operations
[Tue Sep 01 12:57:54.259524 2026] [core:notice] [pid 1:tid 1] AH00094: Command line: 'httpd -D FOREGROUND'
```

### Accessing it on port 80

```
$ docker run --rm --network host alpine:3.20 wget -qO- http://localhost:80
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>It works! Apache httpd</title>
</head>
<body>
<p>It works!</p>
</body>
</html>
```

**Apache is serving on port 80 of the host network namespace, with no port mapping — task complete.**

### An honest platform caveat worth understanding

The verification above was done from *inside* the host network namespace rather than from a Windows browser, and that is not an accident:

```
$ curl -i http://localhost:80        # from Windows
(no response)
```

`--network host` means **the Docker host**, and on Docker Desktop for Windows/macOS the Docker host is **the Linux VM**, not Windows. The container correctly binds port 80 inside that VM, but the VM's `localhost` is not Windows' `localhost`, so a Windows browser cannot reach it. (Docker Desktop has an opt-in "host networking" setting that bridges this; it was deliberately left alone here because enabling it requires restarting Docker Desktop, which would have killed unrelated containers running on this machine.)

**On a native Linux host, `curl http://localhost:80` would have returned the page directly** — that is the behaviour the task describes.

To also produce a browser-visible page on port 80 from Windows, the same image was run with an explicit port publish:

```
$ docker run -d --name apache-port80 -p 80:80 httpd:2.4
71ee4a952220c2f926eccb447102c2e93ed9dfc3945680f339876906021da77a

$ docker ps --filter name=apache-port80 --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
NAMES           IMAGE       STATUS         PORTS
apache-port80   httpd:2.4   Up 3 seconds   0.0.0.0:80->80/tcp, [::]:80->80/tcp

$ curl -i http://localhost:80
HTTP/1.1 200 OK
Date: Tue, 01 Sep 2026 12:58:52 GMT
Server: Apache/2.4.68 (Unix)
Last-Modified: Fri, 07 Nov 2025 08:23:08 GMT
ETag: "bf-642fce432f300"
Accept-Ranges: bytes
Content-Length: 191
Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>It works! Apache httpd</title>
</head>
```

![Apache on port 80](screenshots/apache-port80.png)

Notice the PORTS column is now populated — the visible difference between publishing a port and using the host network.

### Bridge vs host networking

| | Bridge (default) | Host |
|---|---|---|
| Network namespace | Own, isolated | **Shares the host's** |
| Port mapping | Required (`-p 8080:80`) | None — binds host ports directly |
| Container IP | Private (e.g. `172.17.0.2`) | The host's own IP |
| Port conflicts | Impossible between containers | **Yes** — two containers cannot both bind :80 |
| Performance | Slight NAT overhead | No NAT, marginally faster |
| Isolation | Good | **None at the network layer** |
| Use it for | Almost everything | High-throughput networking, or tools that need to see the host's real interfaces |

The trade-off: host networking removes the NAT hop and the port-mapping bookkeeping, at the cost of all network isolation and the ability to run two instances of the same service.

---

## Task 3 — Bind Mount

### Create the folder and the file

```
$ mkdir bind-mount-demo
$ cat > bind-mount-demo/index.html
<!doctype html>
<html>
  <head><title>Bind Mount Demo</title></head>
  <body style="font-family:sans-serif;text-align:center;padding-top:60px">
    <h1>Hello students</h1>
  </body>
</html>
```

### Bind mount it into Nginx

```
$ docker run -d --name nginx-bindmount -p 8090:80 \
    -v "$PWD/bind-mount-demo:/usr/share/nginx/html:ro" nginx:alpine
f36285248d50387a50526db826019cca0d7e8adcf978ced281dc45b61e4f0618
```

`-v host_path:container_path:ro` maps a directory straight from the host into the container. `:ro` makes it read-only from the container's side — good practice for static content, since Nginx has no reason to write there.

```
$ docker inspect nginx-bindmount --format '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}} (RW={{.RW}}){{end}}'
bind /run/desktop/mnt/host/c/Users/.../bind-mount-demo -> /usr/share/nginx/html (RW=false)
```

`Type` is **bind** (not `volume`), and `RW=false` confirms the read-only flag took effect.

### Verify the content

```
$ curl -s http://localhost:8090
<!doctype html>
<html>
  <head><title>Bind Mount Demo</title></head>
  <body style="font-family:sans-serif;text-align:center;padding-top:60px">
    <h1>Hello students</h1>
  </body>
</html>
```

![Before edit](screenshots/bindmount-before.png)

### Modify the file and verify without restarting

First, record exactly when the container started, so the "no restart" claim can be proven rather than asserted:

```
$ docker inspect nginx-bindmount --format '{{.State.StartedAt}}'
2026-09-01T12:59:06.535144495Z
```

Now edit `index.html` **on the host**, leaving the container running:

```
$ nano bind-mount-demo/index.html
<!doctype html>
<html>
  <head><title>Bind Mount Demo - Updated</title></head>
  <body style="font-family:sans-serif;text-align:center;padding-top:60px">
    <h1>Hello students - file edited on the host!</h1>
    <p>This change appeared without restarting the Nginx container.</p>
  </body>
</html>
```

Request the page again — **no restart, no rebuild, no `docker cp`**:

```
$ curl -s http://localhost:8090
<!doctype html>
<html>
  <head><title>Bind Mount Demo - Updated</title></head>
  <body style="font-family:sans-serif;text-align:center;padding-top:60px">
    <h1>Hello students - file edited on the host!</h1>
    <p>This change appeared without restarting the Nginx container.</p>
  </body>
</html>
```

**The proof that the container was never restarted:**

```
$ docker inspect nginx-bindmount --format '{{.State.StartedAt}}'
2026-09-01T12:59:06.535144495Z          <-- byte-identical to before the edit

$ docker ps --filter name=nginx-bindmount --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
NAMES             STATUS          PORTS
nginx-bindmount   Up 33 seconds   0.0.0.0:8090->80/tcp, [::]:8090->80/tcp
```

Same `StartedAt` timestamp, and an unbroken 33-second uptime spanning the edit.

Confirmed from inside the container as well:

```
$ docker exec nginx-bindmount cat /usr/share/nginx/html/index.html
<!doctype html>
<html>
  <head><title>Bind Mount Demo - Updated</title></head>
  ...
    <h1>Hello students - file edited on the host!</h1>

$ docker exec nginx-bindmount ls -l /usr/share/nginx/html/
total 0
-rwxrwxrwx    1 root     root           299 Sep  1 12:59 index.html
```

![After edit](screenshots/bindmount-after.png)

### Why this works, and when to use it

A bind mount is not a copy — the kernel maps the **same directory** into the container's filesystem namespace. There is only ever one copy of the file, so a change made on either side is visible to the other instantly. Nginx re-reads the file from disk on each request, so the next request simply picks up the new content.

**Bind mount vs named volume:**

| | Bind mount | Named volume |
|---|---|---|
| Syntax | `-v /host/path:/container/path` | `-v myvolume:/container/path` |
| Stored | Anywhere you choose on the host | Docker-managed (`/var/lib/docker/volumes`) |
| Host path | You control it exactly | Docker controls it |
| Portability | Tied to that host's layout | Portable |
| Best for | **Local development** — live source reload | **Production data** — databases, uploads |

The live-edit behaviour demonstrated here is exactly why bind mounts are the standard development workflow: edit source on the host, see the change immediately, with no image rebuild.

**A caveat:** files created inside the container are owned by the container's user, which can produce confusing root-owned files on a Linux host. The `:ro` flag used here sidesteps that entirely for static content.

---

## Task 4 — Overlay Network

### Research: what an overlay network is

The three networks in Task 1 were all **bridge** networks, and a bridge is strictly **single-host** — it is a virtual switch inside one Docker daemon. Containers on two different physical machines cannot join the same bridge.

An **overlay network** solves that: it spans **multiple Docker hosts**, so containers on different physical machines behave as though they are on one flat LAN, addressing each other by name with no port publishing and no knowledge of which host runs what.

**How it works.** Overlay networks use **VXLAN** (Virtual Extensible LAN) tunnelling. Each container's Ethernet frame is encapsulated inside a UDP packet (port **4789**), sent across the physical network to the host running the destination container, and decapsulated there. The containers see a normal layer-2 network; the physical network only sees ordinary UDP traffic. Swarm distributes network state, IP allocation and service records to every node via an encrypted gossip protocol, and `--opt encrypted` additionally IPsec-encrypts the data plane.

**Ports required between hosts:** TCP/UDP **7946** (control plane gossip), UDP **4789** (VXLAN data plane), TCP **2377** (swarm management).

**Use cases:**

* **Multi-host container communication** — the core purpose.
* **Docker Swarm services** — every swarm service sits on an overlay by default.
* **Scaling out** beyond one machine's CPU/RAM while keeping service discovery working.
* **High availability** — replicas spread across hosts; if one dies the others keep serving.
* **Environment separation** — separate overlays per environment across a shared cluster.

Overlay networks require **swarm mode** (or an external key-value store on older Docker). That is the practical catch: `docker network create -d overlay` fails outright on a standalone daemon.

### Demonstration

Rather than only describing it, an overlay network was actually created and used. A single-node swarm is enough to exercise the real overlay driver.

```
$ docker swarm init
Swarm initialized: current node (jmq83f07n0lxyze8gpepe2qdh) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token <REDACTED-JOIN-TOKEN> 192.168.65.3:2377
```

*(The join token is a credential that would let any machine join this swarm, so it is redacted here rather than published.)*

```
$ docker network create -d overlay --attachable app-overlay
g0nvn8vqioen664quann1uned

$ docker network ls --filter driver=overlay
NETWORK ID     NAME          DRIVER    SCOPE
g0nvn8vqioen   app-overlay   overlay   swarm
1x0x4x1mzk06   ingress       overlay   swarm
```

Note **`SCOPE = swarm`**, not `local` — the defining difference from a bridge network. `ingress` is the overlay Swarm creates automatically for its routing mesh.

`--attachable` allows standalone containers to join; without it only swarm services can.

**Deploy a replicated service onto it:**

```
$ docker service create --name web --network app-overlay --replicas 3 -p 8095:80 nginx:alpine
verify: Service ct2j0ud9b6x89wzm7aww93l34 converged

$ docker service ls
ID             NAME      MODE         REPLICAS   IMAGE          PORTS
ct2j0ud9b6x8   web       replicated   3/3        nginx:alpine   *:8095->80/tcp

$ docker service ps web
NAME      NODE             DESIRED STATE   CURRENT STATE
web.1     docker-desktop   Running         Running 19 seconds ago
web.2     docker-desktop   Running         Running 19 seconds ago
web.3     docker-desktop   Running         Running 19 seconds ago
```

**3/3 replicas running.** On a multi-node swarm those three tasks would be scheduled across different physical machines, and the `NODE` column would show three different hostnames — the overlay is what lets them still form one service.

```
$ docker network inspect app-overlay --format '{{.Name}} driver={{.Driver}} scope={{.Scope}} attachable={{.Attachable}}'
app-overlay driver=overlay scope=swarm attachable=true

$ curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://localhost:8095
HTTP 200
```

**Service discovery across the overlay** — the part that makes it useful:

```
$ docker run --rm --network app-overlay alpine:3.20 nslookup web
Non-authoritative answer:
Name:	web
Address: 10.0.1.2

$ docker run --rm --network app-overlay alpine:3.20 wget -qO- http://web | grep -i title
<title>Welcome to nginx!</title>
```

The name `web` resolves to `10.0.1.2` — a single **Virtual IP (VIP)**, not any individual container's address. Swarm load-balances connections to that VIP across all three replicas transparently. A client just connects to `web` and never needs to know how many replicas exist or where they run. That is the payoff: **location-transparent, load-balanced, name-based service discovery across an arbitrary number of hosts.**

### Cleanup — the machine was restored to its original state

```
$ docker service rm web
web
$ docker network rm app-overlay
app-overlay
$ docker swarm leave --force
Node left the swarm.

$ docker info --format 'Swarm: {{.Swarm.LocalNodeState}}'
Swarm: inactive
```

### Network driver comparison

| Driver | Scope | Purpose |
|---|---|---|
| `bridge` | Single host | Default; isolated network on one machine |
| `host` | Single host | Share the host's network stack, no isolation |
| **`overlay`** | **Multi-host** | **Connect containers across machines (needs swarm)** |
| `macvlan` | Single host | Give a container a real MAC/IP on the physical LAN |
| `none` | — | No networking at all |
| `ipvlan` | Single host | Like macvlan, sharing the host's MAC |

---

## Summary

| Task | Status | Key evidence |
|---|---|---|
| 1. Three containers, three networks, backend on two | Complete | `backend-net=172.25.0.2 frontend-net=172.24.0.3`; frontend→database fails |
| 2. Apache on the host network, port 80 | Complete | `NetworkMode=host`, empty PORTS column, page served on :80 |
| 3. Bind mount with live edit | Complete | Identical `StartedAt` before and after the edit |
| 4. Overlay network research | Complete | Real overlay created, 3/3 replicas, VIP `10.0.1.2` |

### Cleaning up Tasks 1–3

```bash
docker rm -f frontend backend database apache-port80 nginx-bindmount
docker network rm frontend-net backend-net db-admin-net
```
