# DevOps Homework — Section B

All eight DevOps homework tasks, each in its own folder with its own `README.md`.

| | |
|---|---|
| **Author** | Siddhant Prasad |
| **Enrollment number** | 24BCS10255 |

---

## Submission index

The submission form has one field per topic. Each links to that topic's `README.md`:

| # | Topic | Folder | Source handout |
|---|---|---|---|
| 1 | **Docker Images** | [`Docker_Images/`](Docker_Images/README.md) | Docker Multi-Stage Build Homework |
| 2 | **Docker Fundamentals** | [`Docker_Fundamentals/`](Docker_Fundamentals/README.md) | Docker Homework Tasks — Hello World Applications |
| 3 | **Git and GitHub** | [`Git_and_GitHub/`](Git_and_GitHub/README.md) | Git Homework Tasks |
| 4 | **Shell Scripting** | [`Shell_Scripting/`](Shell_Scripting/README.md) | Shell Scripting Homework Task |
| 5 | **Docker Networking** | [`Docker_Networking/`](Docker_Networking/README.md) | Docker Networking & Volume Homework |
| 6 | **Linux Fundamentals** | [`Linux_Fundamentals/`](Linux_Fundamentals/README.md) | Linux Homework Tasks |
| 7 | **Networking** | [`Networking/`](Networking/README.md) | Networking Homework Tasks |
| 8 | **Kubernetes Services** | [`session-11-kubernetes-services/`](session-11-kubernetes-services/README.md) | Session 11 — Kubernetes Services |

---

## What is in each folder

### 1. [Docker Images](Docker_Images/README.md)
Multi-stage Dockerfile built and run on **port 8080**, displaying *"Hello World from Docker multi-stage build"*, verified with `docker ps`, `curl` and a browser screenshot. Includes a measured size comparison against a single-stage build of the same app — **472 MB → 19.5 MB (96% smaller)**. Plus three separate application deployments (Node.js, Python, Java).

### 2. [Docker Fundamentals](Docker_Fundamentals/README.md)
Six containerised Hello World web apps — `nodejs-app`, `python-app`, `java-app`, `Apache-app`, `React-app`, `nginx-app` — each with its own Dockerfile, built, run and verified. All six confirmed returning HTTP 200 with browser screenshots. The React app is a real Vite production build compiled inside the image.

### 3. [Git and GitHub](Git_and_GitHub/README.md)
`git commit -a -m` vs `git commit -m`, demonstrated with the case that actually distinguishes them (untracked vs modified-tracked files). Then a full cherry-pick exercise: 4 commits on `main`, 3 on a feature branch, one specific commit cherry-picked across and verified — including proof that the picked commit gets a **new SHA**.

### 4. [Shell Scripting](Shell_Scripting/README.md)
`sysinfo.sh` — a system information script using variables, `read -p`, `mkdir`, `touch`, `date`, `hostname`, `whoami`, `df`, `ps` and `>` output redirection, with a full annotated run.

### 5. [Docker Networking](Docker_Networking/README.md)
Three containers across three networks with the backend dual-homed, including a **connectivity matrix that proves the frontend cannot reach the database**. Apache on the host network. A bind mount edited live, with `StartedAt` timestamps proving the container was never restarted. Plus a real overlay network created in swarm mode with 3 replicas and VIP-based service discovery.

### 6. [Linux Fundamentals](Linux_Fundamentals/README.md)
Soft vs hard links demonstrated at the inode level, including the decisive delete-the-original test. `adduser` vs `useradd` with proof of what each does and does not create. `journalctl` run against a real systemd host with a live service. A worked command cheat sheet across 12 categories.

### 7. [Networking](Networking/README.md)
Twelve categories of networking commands — `ip`, `route`, `ping`, `traceroute`, `dig`/`nslookup`/`host`, `ss`/`netstat`, `nc`, `curl`/`wget`, `arp`, `whois`, `tcpdump` — each executed, with output and an explanation of what it means and when to reach for it.

### 8. [Kubernetes Services](session-11-kubernetes-services/README.md)
All five Service types — **ClusterIP, NodePort, LoadBalancer, Headless and ExternalName** — on a Minikube cluster, sharing one Nginx Pod named `web`. ClusterIP was tested with `curl` from inside the cluster. NodePort and LoadBalancer were opened in the browser through `minikube service --url`. Headless DNS returned the Pod IP directly, and ExternalName returned a CNAME to `google.com`. Each Service folder has its YAML, terminal and browser screenshots, and a README.

---

## How this work was done

Everything in these READMEs was **actually executed** on this machine, and the outputs are copied verbatim rather than written from memory. Where a command failed or behaved differently than the task text implies, that is documented honestly rather than papered over.

**Environment:**

| | |
|---|---|
| Host OS | Windows 11 |
| Docker | 29.4.1 (Docker Desktop, WSL2 backend) |
| Git | 2.47.1 |
| Linux commands | Run inside `ubuntu:24.04` containers |
| `journalctl` / `systemctl` | Run inside a systemd-enabled Ubuntu 24.04 container |
| Screenshots | Headless Chromium rendering each running container |

**Evidence files.** Alongside each README, the folders contain the demo scripts and the complete unedited transcripts (`*-demo.sh`, `*-output.txt`), so every claim can be re-run and checked.

---

## Two notes on the handouts

Two tasks referenced material that was not included in the PDFs I was given. Rather than guess and risk answering the wrong question, both are flagged clearly in place:

1. **Networking, Task 1** refers to "commands and repo shared in devops-hero github repo" — no link was provided. The Networking README covers the standard Linux networking toolkit comprehensively instead.
2. **Docker Images, Task 1** says to clone "the repository containing the multi-stage Dockerfile" — no link was provided. A multi-stage application was written from scratch that satisfies every stated requirement (port 8080, the exact required output string, verified with `docker ps`).

If either repository is supplied, those sections can be re-run against it.

---

## Reproducing everything

Each folder's README contains the exact build/run/cleanup commands for that task. In general:

```bash
git clone <this-repo-url>
cd devops-homework

# Example: the multi-stage build
cd Docker_Images/multistage-app
docker build -t multistage-app:latest .
docker run -d --name multistage-demo -p 8080:8080 multistage-app:latest
curl http://localhost:8080/text
# -> Hello World from Docker multi-stage build
```
