# AWS EC2 — Elastic Compute Cloud (Compute)

**Student:** Siddhant Prasad (24BCS10255) · Session 18, Task 2

---

## What is EC2?

EC2 provides resizable **virtual machines** in AWS. You choose the operating system image, the
hardware shape and the network placement, and AWS gives you a server you control at the OS level.
Billing is per-second (Linux) with no commitment, which is the "elastic" part — you can run 1
instance for a month or 100 instances for an hour.

EC2 is **IaaS**: you are responsible for the OS, patching, runtime and application. That is the
trade-off against containers (ECS/EKS) or serverless (Lambda), which hand more of the stack to
AWS.

---

## AMI — Amazon Machine Image

The template an instance boots from. It contains the root volume snapshot (OS + preinstalled
software), plus launch permissions and block device mappings.

- **AWS-provided**: Amazon Linux 2023, Ubuntu, Windows Server, …
- **Marketplace**: vendor-packaged images
- **Custom**: your own "golden image", built from a configured instance (often with Packer)

AMIs are **region-specific** — the same logical image has a different AMI ID in each region,
which is a classic Terraform gotcha (use a data source to look it up instead of hardcoding).

## Instance types

An instance type fixes the vCPU / memory / network / storage profile. The naming reads as
`family + generation + size`, e.g. `t3.micro`, `m6i.large`, `c7g.xlarge`.

| Family | Optimised for | Typical use |
|---|---|---|
| `t` | Burstable general purpose (CPU credits) | Dev boxes, low-traffic web apps |
| `m` | Balanced general purpose | App servers, small databases |
| `c` | Compute (high CPU per GB) | Batch processing, game servers, CI runners |
| `r` / `x` | Memory | In-memory caches, large databases |
| `i` / `d` | Storage (fast local NVMe) | NoSQL, data warehouses |
| `p` / `g` | GPU / accelerated | ML training and inference |

A `g` suffix (e.g. `c7g`) means AWS Graviton (ARM) — cheaper per unit of performance, but your
container images must be built for ARM.

## Key pairs

An SSH public/private key pair used for first login.

- AWS stores the **public** key and injects it into the instance at launch.
- You download the **private** key **once** — lose it and you cannot SSH in with it again.
- Linux: SSH as `ec2-user`/`ubuntu` with the key. Windows: the key decrypts the Administrator
  password.
- Modern alternative: **SSM Session Manager**, which needs no key pair, no open port 22, and no
  public IP, and logs every session. Preferred in production.

## Security Groups

A **stateful virtual firewall** attached to an instance's network interface.

- Rules are **allow-only** — there is no deny rule. Anything not allowed is dropped.
- **Stateful**: if inbound traffic is allowed, the response is automatically allowed out (and
  vice versa). No need for a matching return rule.
- Rules can reference **another security group** as the source, which is the clean way to express
  "only the web tier may reach the database tier".
- Default: all inbound denied, all outbound allowed.

```
Internet ──► SG-web  (allow 443 from 0.0.0.0/0)
                │
                ▼
             SG-app  (allow 8080 from SG-web)
                │
                ▼
             SG-db   (allow 5432 from SG-app)   ← never from the internet
```

## EBS — Elastic Block Store

Network-attached persistent block storage; the instance's "hard disk".

- Lives **independently of the instance** — stop/start keeps the data (unlike instance store).
- Tied to one **Availability Zone**; attach only to instances in that AZ.
- Types: `gp3` (general purpose SSD, the sane default), `io2` (provisioned IOPS for databases),
  `st1`/`sc1` (throughput/cold HDD).
- **Snapshots** are incremental backups stored in S3, and are how you copy a volume across AZs or
  regions.
- `DeleteOnTermination` controls whether the root volume survives instance termination — a
  frequent cause of accidental data loss.

**Instance store** is the alternative: physically attached NVMe, very fast, but **ephemeral** —
wiped on stop or termination.

## Public vs private IP

| | Private IP | Public IP | Elastic IP |
|---|---|---|---|
| Scope | Inside the VPC | Internet-routable | Internet-routable |
| Stability | Fixed for the instance's life | **Changes on stop/start** | Static until released |
| Cost | Free | Free while attached to a running instance | Charged when *not* in use |
| Needed for | All internal traffic | Direct inbound from the internet | Stable public endpoint |

Key points: an instance in a **private subnet** has no public IP and reaches the internet through
a **NAT Gateway**. A public IP is not a security boundary — the security group is.

## Instance lifecycle

```
            launch
              │
              ▼
          ┌────────┐   stop    ┌─────────┐   start   ┌────────┐
 pending─►│ running│──────────►│ stopped │──────────►│ running│
          └───┬────┘           └────┬────┘           └────────┘
              │ terminate           │ terminate
              ▼                     ▼
         shutting-down ──────► terminated   (EBS root volume usually deleted)
```

| Transition | What happens |
|---|---|
| **Stop** | Billing for compute stops; EBS persists; **public IP is released**; moves to a different physical host on start |
| **Reboot** | Same host, same IP, no state lost |
| **Hibernate** | RAM is written to the root EBS volume and restored on start |
| **Terminate** | Instance is destroyed permanently |

## Purchasing options

| Option | Discount | Trade-off |
|---|---|---|
| On-Demand | — | Most flexible, most expensive |
| Reserved / Savings Plans | up to ~72% | 1–3 year commitment |
| Spot | up to ~90% | AWS can reclaim it with a 2-minute warning |
| Dedicated Hosts | — | Physical isolation, licensing compliance |

## Common use cases

- **Traditional web application** — instances behind an Application Load Balancer in an Auto
  Scaling group across multiple AZs.
- **Legacy or licensed software** that cannot be containerised and needs OS-level control.
- **CI/CD build runners** — compute-optimised Spot instances for cheap, bursty builds.
- **Bastion / jump host** — though SSM Session Manager is the better modern answer.
- **ML training** — GPU instances (`p`/`g` families), usually Spot for cost.
- **Lift-and-shift migration** — the first step when moving a data-centre workload into AWS.
