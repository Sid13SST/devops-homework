# AWS VPC — Virtual Private Cloud (Networking)

**Student:** Siddhant Prasad (24BCS10255) · Session 18, Task 2

---

## What is a VPC?

A VPC is a **logically isolated virtual network** inside an AWS region that you control
completely: the IP address range, the subnets, the routing, and the firewalls. Nothing reaches
your instances unless the routing *and* the security rules both allow it.

A VPC spans **all Availability Zones in one region**. Subnets, by contrast, live in exactly one
AZ — which is why multi-AZ design always means multiple subnets.

---

## CIDR

**Classless Inter-Domain Routing** notation defines the address range: `10.0.0.0/16`.

The `/16` is the prefix length — the number of fixed bits. The remaining bits are host addresses:

| CIDR | Addresses | Typical use |
|---|---|---|
| `/16` | 65,536 | A whole VPC (the maximum AWS allows) |
| `/20` | 4,096 | A large subnet |
| `/24` | 256 | A standard subnet |
| `/28` | 16 | Smallest subnet AWS allows |

Two practical rules:

- **AWS reserves 5 addresses in every subnet** (network address, VPC router, DNS, future use,
  broadcast), so a `/24` gives you 251 usable IPs, not 256.
- Use **private ranges** (RFC 1918: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) and make
  sure they do not overlap with networks you may later peer with or connect by VPN. Overlapping
  CIDRs cannot be peered, and the VPC CIDR cannot be shrunk later.

## Subnets

A subnet is a slice of the VPC CIDR bound to one AZ.

```
VPC 10.0.0.0/16  (region: ap-south-1)
│
├── ap-south-1a
│   ├── 10.0.1.0/24   public   (web tier)
│   └── 10.0.11.0/24  private  (app + db tier)
│
└── ap-south-1b
    ├── 10.0.2.0/24   public
    └── 10.0.12.0/24  private
```

What makes a subnet "public" is **not a setting on the subnet** — it is the route table. A subnet
is public if its route table has a default route (`0.0.0.0/0`) pointing at an Internet Gateway.

## Route tables

A set of rules deciding where traffic leaves a subnet. Every subnet is associated with exactly
one route table (the VPC's main table by default).

| Destination | Target | Meaning |
|---|---|---|
| `10.0.0.0/16` | `local` | Traffic inside the VPC — always present, cannot be removed |
| `0.0.0.0/0` | `igw-…` | Internet-bound traffic → **makes the subnet public** |
| `0.0.0.0/0` | `nat-…` | Internet-bound traffic via NAT → **keeps the subnet private** |
| `10.1.0.0/16` | `pcx-…` | Traffic to a peered VPC |

Routing is **most-specific-match-wins**: a `/24` route beats a `/0` route.

## Internet Gateway (IGW)

A horizontally scaled, highly available component that connects the VPC to the internet.

- **One IGW per VPC.** Attaching it alone does nothing — you must also add the `0.0.0.0/0` route.
- Enables **both** inbound and outbound traffic.
- An instance also needs a **public IP** (or Elastic IP) to be reachable from the internet; the
  IGW performs the 1:1 NAT between the public and private address.

## NAT Gateway

Lets instances in **private** subnets make **outbound** connections (OS updates, API calls,
pulling container images) while remaining unreachable from the internet.

- Lives in a **public** subnet and needs an Elastic IP.
- Traffic is **outbound-only**: return packets for connections the instance initiated are
  allowed, but nothing can initiate a connection inward.
- Managed and AZ-scoped — for high availability you deploy one per AZ, since an AZ failure takes
  its NAT Gateway with it.
- It is a real cost item (hourly + per-GB). A **NAT instance** is the cheap DIY alternative;
  **VPC endpoints** avoid NAT entirely for AWS service traffic (e.g. S3), which is both cheaper
  and more secure.

```
private subnet instance ──► NAT Gateway (public subnet) ──► IGW ──► Internet
        ▲                                                             │
        └──────────────── return traffic only ────────────────────────┘
        ✗ no inbound connection can be initiated
```

## Security Groups vs Network ACLs

Both are firewalls, but they operate at different layers and behave differently. This distinction
is a classic exam and interview question:

| | Security Group | Network ACL |
|---|---|---|
| Attaches to | An **ENI** (instance) | A **subnet** |
| State | **Stateful** — return traffic auto-allowed | **Stateless** — you must allow return traffic explicitly |
| Rules | **Allow only** | **Allow and Deny** |
| Evaluation | All rules evaluated together | **Rules in number order**, first match wins |
| Can reference | Another security group | CIDR blocks only |
| Default | Deny all inbound, allow all outbound | Default NACL allows everything |

The stateless point matters in practice: with a NACL you must open the **ephemeral port range**
(1024–65535) inbound for replies to outbound requests, or connections hang mysteriously.

Use security groups as the primary control; reach for NACLs for coarse subnet-wide denies, such
as blocking a malicious IP range.

## Public vs private subnet

| | Public subnet | Private subnet |
|---|---|---|
| Default route | Internet Gateway | NAT Gateway (or none) |
| Inbound from internet | Possible | Impossible |
| Outbound to internet | Direct | Via NAT |
| Resources | Load balancers, bastion hosts, NAT Gateways | App servers, databases, caches |

The standard three-tier design keeps **only the load balancer** in public subnets. Application
servers and databases sit in private subnets and are reachable only through the load balancer or
via SSM — so there is no public attack surface at all.

## Other components worth knowing

- **VPC Endpoints** — private connectivity to AWS services without traversing the internet.
  *Gateway* endpoints (S3, DynamoDB) are free and route-table based; *Interface* endpoints
  (PrivateLink) put an ENI in your subnet.
- **VPC Peering** — one-to-one private connection between VPCs. Not transitive, and CIDRs must
  not overlap.
- **Transit Gateway** — a hub-and-spoke router that scales to many VPCs and on-premises links,
  replacing a mesh of peerings.
- **VPC Flow Logs** — records of accepted/rejected traffic, delivered to S3 or CloudWatch. The
  first thing to enable when debugging "why can't A reach B".
- **DHCP option sets / DNS** — `enableDnsSupport` and `enableDnsHostnames` control whether
  instances get resolvable DNS names.

## Common use cases

- **Three-tier web application** — public ALB subnets, private app subnets, private database
  subnets, spread over two or more AZs.
- **Private EKS / RDS deployment** — worker nodes and databases with no public IPs, pulling
  images through a NAT Gateway or VPC endpoints.
- **Hybrid cloud** — Site-to-Site VPN or Direct Connect joining the VPC to a corporate network.
- **Environment isolation** — separate VPCs (ideally separate accounts) for dev, staging and
  prod, so a mistake in dev cannot touch production.
- **Compliance isolation** — workloads handling regulated data in dedicated private subnets with
  Flow Logs and NACL restrictions.
