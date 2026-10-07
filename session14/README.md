# Session 14 — Kubernetes Troubleshooting

**Student:** Siddhant Prasad (24BCS10255)
**Environment:** Windows 11 · Docker Desktop · Minikube (Kubernetes v1.37.0) · kubectl v1.34.1

Every failure in this document was **deliberately created** on the live cluster, observed,
diagnosed and fixed. Each scenario folder holds the `broken.yaml` that causes the failure and the
`fixed.yaml` that resolves it.

---

# TASK 1 — Troubleshooting commands

The commands that matter, and what each one is actually for:

| Command | What it tells you | When to reach for it |
|---|---|---|
| `kubectl get <res>` | Current status, restart counts, age | Always first — the 5-second overview |
| `kubectl get <res> -o wide` | Adds Pod IP, node, nominated node | "Which node is this on? What IP did it get?" |
| `kubectl describe <res>` | Full spec **plus the Events list** | The single most useful command — events explain *why* |
| `kubectl logs <pod>` | The container's stdout/stderr | The app started but misbehaves |
| `kubectl logs <pod> --previous` | Logs of the **crashed** container | CrashLoopBackOff — the current container is too young to be useful |
| `kubectl exec <pod> -- <cmd>` | A shell inside the running container | Verify files, env vars, connectivity from the Pod's view |
| `kubectl events` | Cluster-wide event stream | Something broke and you don't know which object yet |
| `kubectl explain <path>` | Schema documentation for any field | "What are the valid fields under a probe?" |
| `kubectl top nodes` / `top pods` | Live CPU/memory from metrics-server | Pending Pods, OOM kills, HPA questions |

A reliable order of attack:

```
kubectl get pods            →  what state is it in?
        │
        ▼
kubectl describe pod <name> →  the Events at the bottom name the cause
        │
        ├── container never started  →  image / scheduling / volume / config problem
        │                               (ImagePullBackOff, Pending, ContainerCreating,
        │                                CreateContainerConfigError)
        │
        └── container started, then died  →  application problem
                                             kubectl logs --previous
```

```powershell
kubectl get pods -o wide
kubectl top nodes
```

![Commands](01-commands/screenshots/commands.png)

`-o wide` adds the Pod IP and node columns, and `kubectl top nodes` shows real CPU/memory
consumption from metrics-server — the two pieces of information missing from a plain `get`.

---

# TASK 2 — Troubleshooting common issues

## 2.1 CrashLoopBackOff

**Problem:** the Pod starts, dies, and restarts over and over, with the restart count climbing.

**Cause in `01-crashloopbackoff/broken.yaml`:** the container's command exits `1` immediately.
Because `restartPolicy` defaults to `Always`, the kubelet restarts it with an increasing backoff
delay (10s, 20s, 40s …) — that backoff is what the status name refers to.

```powershell
kubectl apply -f 02-troubleshooting/01-crashloopbackoff/broken.yaml
kubectl get pod crashloop-demo
kubectl logs crashloop-demo --tail=3
```

![CrashLoopBackOff](02-troubleshooting/01-crashloopbackoff/screenshots/crashloop.png)

**Investigation.** `get pod` shows the restart counter rising and the status alternating between
`Error` (the instant it has just died) and `CrashLoopBackOff` (while the kubelet waits before the
next attempt). `kubectl logs` is what names the real cause — the container printed
`FATAL: config file /etc/app/config.yaml not found` before exiting. `describe` confirms it:

```
State:          Terminated
  Reason:       Error
  Exit Code:    1
Restart Count:  3
Warning  BackOff  3s (x4 over 43s)  kubelet  Back-off restarting failed container
```

**Root cause:** the application exits non-zero at startup. The Pod definition is fine; the
*process* fails.

**Fix:** correct the application's startup problem so the process stays alive
(`01-crashloopbackoff/fixed.yaml`). Result: `1/1 Running`, `RESTARTS 0`, and the log reads
`config loaded successfully`.

**Key insight:** for a crash loop, use `kubectl logs --previous`. The current container may be
too young to have logged anything; the previous one holds the error.

---

## 2.2 ImagePullBackOff / ErrImagePull

**Problem:** the Pod never starts; no container is ever created.

**Cause in `02-imagepull/broken.yaml`:** the image tag `nginx:1.27-this-tag-does-not-exist`
isn't in the registry.

```powershell
kubectl apply -f 02-troubleshooting/02-imagepull/broken.yaml
kubectl get pod imagepull-demo
kubectl describe pod imagepull-demo | Select-String -Pattern "ErrImagePull|ImagePullBackOff|not found"
```

![ImagePullBackOff](02-troubleshooting/02-imagepull/screenshots/imagepull.png)

**Investigation.** The two statuses are the same story at different moments:

- **`ErrImagePull`** — the pull was just attempted and failed.
- **`ImagePullBackOff`** — the kubelet is now waiting before retrying.

`kubectl logs` is useless here (there is no container yet). `describe` carries the answer in its
events: `Error: ErrImagePull` with the registry's "manifest not found" message.

**Root cause:** wrong image name or tag. The other three real-world causes of the same symptom:
a private registry with no `imagePullSecrets`, an authentication failure, or a registry the node
cannot reach.

**Fix:** use a tag that exists (`02-imagepull/fixed.yaml`) → `1/1 Running`.

---

## 2.3 Pending

**Problem:** the Pod exists but is never assigned to a node — it has no IP and no node.

**Cause in `03-pending/broken.yaml`:** it requests 64 CPUs and 200Gi of memory, which this
single-node cluster cannot satisfy.

```powershell
kubectl apply -f 02-troubleshooting/03-pending/broken.yaml
kubectl get pod pending-demo
kubectl describe pod pending-demo | Select-String -Pattern "Insufficient|FailedScheduling"
```

![Pending](02-troubleshooting/03-pending/screenshots/pending.png)

**Investigation.** `Pending` means **the scheduler could not place it**. The `FailedScheduling`
event states exactly which resource fell short (`Insufficient cpu`, `Insufficient memory`).

**Root cause:** resource requests larger than any node's allocatable capacity. Other common
causes of `Pending`: an unbound PVC, a `nodeSelector`/affinity rule matching no node, or a taint
with no matching toleration.

**Fix:** request what the cluster can actually give (`100m` / `64Mi`) → the Pod is scheduled onto
`minikube` and reaches `Running` with an IP.

**Key insight:** `Pending` is a *scheduling* problem, so `describe` is the only tool that helps —
there is no container to get logs from.

---

## 2.4 ContainerCreating (stuck)

**Problem:** the Pod is scheduled but stays in `ContainerCreating` indefinitely.

**Cause in `04-containercreating/broken.yaml`:** it mounts a ConfigMap named `app-settings`
that does not exist, so the kubelet cannot build the volume.

```powershell
kubectl apply -f 02-troubleshooting/04-containercreating/broken.yaml
kubectl get pod containercreating-demo
kubectl describe pod containercreating-demo | Select-String -Pattern "FailedMount|not found"
```

![ContainerCreating](02-troubleshooting/04-containercreating/screenshots/containercreating.png)

**Investigation.** A few seconds of `ContainerCreating` is normal (image pull, volume setup).
Stuck for minutes is not. The `FailedMount` warning names the missing object.

**Root cause:** a volume dependency that doesn't exist. Equally common: a missing Secret, an
unbound PVC, or a slow image pull.

**Fix:** create the ConfigMap the Pod is waiting for (`04-containercreating/fixed.yaml`). No Pod
edit and no restart needed — the kubelet retries the mount automatically and the Pod proceeds to
`1/1 Running`.

---

## 2.5 Service connectivity — selector mismatch

**Problem:** the Pods are healthy, but nothing can reach them through the Service.

**Cause in `05-service-connectivity/broken.yaml`:** the Service selects `app=web-application`
while the Pods are labelled `app=web-app`.

```powershell
kubectl apply -f 02-troubleshooting/05-service-connectivity/broken.yaml
kubectl get pods -l app=web-app --show-labels
kubectl describe svc web-service | Select-String -Pattern "Selector|Endpoints"
```

![Service broken](02-troubleshooting/05-service-connectivity/screenshots/service-broken.png)

**Investigation.** This is *the* diagnostic habit for Service problems: **check the endpoints.**

- `ENDPOINTS` is `<none>` and `describe svc` shows `Endpoints:` blank
- `Selector: app=web-application`, but `--show-labels` proves the Pods carry `app=web-app`

A connection attempt from inside the cluster fails accordingly:

```
wget: can't connect to remote host (10.101.167.58): Connection refused
```

**Root cause:** the Service selector doesn't match the Pod labels, so no Pod is ever added to the
Service's endpoint list.

**Fix:** align the selector (`05-service-connectivity/fixed.yaml`).

```powershell
kubectl apply -f 02-troubleshooting/05-service-connectivity/fixed.yaml
kubectl get endpoints web-service
```

![Service fixed](02-troubleshooting/05-service-connectivity/screenshots/service-fixed.png)

Both Pod IPs appear immediately (`10.244.0.32:80,10.244.0.33:80`) and the same request now
returns the nginx welcome page.

**Key insight:** empty endpoints ⇒ label/selector mismatch. Endpoints present but still failing
⇒ a port problem, which is the next scenario.

---

## 2.6 DNS

**Problem:** needing to confirm whether a name resolves, and what it resolves to, from a Pod's
point of view.

```powershell
kubectl apply -f 02-troubleshooting/06-dns/dns-debug-pod.yaml
kubectl exec dns-debug -- nslookup web-service.default.svc.cluster.local
kubectl exec dns-debug -- cat /etc/resolv.conf
```

![DNS](02-troubleshooting/06-dns/screenshots/dns.png)

**What the output proves.**

- The FQDN resolves cleanly to the Service's ClusterIP via CoreDNS at `10.96.0.10`.
- `/etc/resolv.conf` explains the behaviour of short names:
  ```
  search default.svc.cluster.local svc.cluster.local cluster.local
  nameserver 10.96.0.10
  options ndots:5
  ```
  A short name like `web-service` is tried against each search domain in turn, so the log shows
  `NXDOMAIN` for `web-service.cluster.local` **before** succeeding on
  `web-service.default.svc.cluster.local`. Those intermediate NXDOMAINs are normal, not a fault.
- A genuinely missing name returns `NXDOMAIN` for every search domain —
  `does-not-exist-service` failed on all of them.

**How to triage DNS:** confirm CoreDNS is running
(`kubectl get pods -n kube-system -l k8s-app=kube-dns`), then resolve the **FQDN** from a Pod. If
the FQDN works but the short name doesn't, the problem is search-domain/namespace related, not
CoreDNS.

---

## 2.7 Pod networking — wrong targetPort

**Problem:** the Service has endpoints and DNS resolves, yet every connection is refused. The
hardest of these to spot.

**Cause in `07-pod-networking/broken.yaml`:** the Service forwards to `targetPort: 8080`, but
nginx listens on `80`.

**Investigation.** Endpoints exist — and that is the trap:

```
NAME               ENDPOINTS                           AGE
netcheck-service   10.244.0.32:8080,10.244.0.33:8080   9s
```

The endpoint list shows port **8080**, which nothing is listening on, so:

```
wget: can't connect to remote host (10.98.204.39): Connection refused
```

**Root cause:** `targetPort` doesn't match the container's real listening port. Note the
distinction — `port` is what the Service exposes, `targetPort` is the container port it forwards
to.

**Fix:** set `targetPort: 80` (`07-pod-networking/fixed.yaml`) → the same request returns the
nginx page.

**Key insight:** read the **port numbers** in the endpoint list, not just whether endpoints
exist.

---

## 2.8 Configuration — missing ConfigMap key

**Problem:** the Pod is scheduled, the image pulls, but the container is never created.

**Cause in `08-configuration/broken.yaml`:** the container requires the key `DATABASE_URL` from
ConfigMap `app-env`, which only defines `APP_NAME`.

```powershell
kubectl apply -f 02-troubleshooting/08-configuration/broken.yaml
kubectl get pod config-demo
kubectl describe pod config-demo | Select-String -Pattern "CreateContainerConfigError|couldn"
```

![Configuration](02-troubleshooting/08-configuration/screenshots/configuration.png)

**Investigation.** The status is `CreateContainerConfigError` — distinct from a crash loop,
because the container was never built. The event is precise:

```
Error: couldn't find key DATABASE_URL in ConfigMap default/app-env
```

**Root cause:** a required `configMapKeyRef` key is absent. (Adding `optional: true` would let
the Pod start with the variable unset instead — appropriate only if the app can cope.)

**Fix:** add the key to the ConfigMap (`08-configuration/fixed.yaml`). The Pod then runs and logs
both values:

```
APP_NAME=troubleshooting-demo DATABASE_URL=postgres://app:app@postgres:5432/appdb
```

---

## 2.9 All scenarios fixed

```powershell
kubectl apply -f 02-troubleshooting/01-crashloopbackoff/fixed.yaml -f ... (all fixed manifests)
kubectl get pods
```

![All fixed](02-troubleshooting/screenshots-all-fixed.png)

Every previously broken Pod now reports `1/1 Running` with `RESTARTS 0`.

---

# Summary table

| Symptom | What it means | First command | Usual root cause |
|---|---|---|---|
| `CrashLoopBackOff` | Started, then died repeatedly | `logs --previous` | App exits non-zero |
| `ErrImagePull` / `ImagePullBackOff` | Image could not be pulled | `describe` | Bad tag, private registry, no auth |
| `Pending` | Scheduler found no node | `describe` | Insufficient resources, unbound PVC, taints |
| `ContainerCreating` (stuck) | Scheduled, setup blocked | `describe` | Missing ConfigMap/Secret/PVC |
| `CreateContainerConfigError` | Container never built | `describe` | Missing ConfigMap/Secret **key** |
| Service unreachable, no endpoints | No Pod matched | `get endpoints` + `--show-labels` | Selector ≠ Pod labels |
| Service unreachable, endpoints exist | Wrong port | `get endpoints` (read the port) | `targetPort` mismatch |
| Name does not resolve | DNS | `nslookup` FQDN from a Pod | Wrong namespace/FQDN, CoreDNS down |

# Key learnings

- **`kubectl describe` is the workhorse.** Its Events section names the cause for every failure
  that happens *before* the container starts.
- **`kubectl logs` only helps once a container has run** — and for crash loops you need
  `--previous`.
- **The status name tells you which phase failed:** `Pending` = scheduling, `ContainerCreating` =
  volume/setup, `ImagePullBackOff` = image, `CreateContainerConfigError` = config resolution,
  `CrashLoopBackOff` = the application itself.
- **For Service problems, always check endpoints first.** Empty ⇒ label/selector mismatch.
  Populated but refused ⇒ read the port numbers.
