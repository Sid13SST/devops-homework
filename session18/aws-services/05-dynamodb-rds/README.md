# AWS Database Services — DynamoDB & RDS

**Student:** Siddhant Prasad (24BCS10255) · Session 18, Task 2

---

## Choosing between them

| | DynamoDB | RDS |
|---|---|---|
| Model | NoSQL key-value / document | Relational (SQL) |
| Schema | Schema-less except the key | Fixed schema, enforced |
| Scaling | Horizontal, automatic, effectively unlimited | Vertical (bigger instance) + read replicas |
| Joins / transactions | Limited | Full SQL joins, ACID transactions |
| Query flexibility | Must be designed up front around access patterns | Ad-hoc queries any time |
| Latency | Single-digit milliseconds at any scale | Good, but degrades without tuning |
| Management | Fully serverless | Managed instance (you pick size, version, patch window) |

Rule of thumb: **known access patterns at huge scale → DynamoDB. Relational data with ad-hoc
queries and reporting → RDS.**

---

# DynamoDB

## NoSQL

DynamoDB is a managed NoSQL database. There are no servers, no connections to pool, and no
instance size — you call an HTTP API and AWS handles partitioning across storage nodes. The
trade-off for that scale is that you give up joins and ad-hoc querying: the **data model is
designed around the queries you intend to run**, not around normalisation.

## Tables

The top-level container. A table requires only a **primary key** definition; every other
attribute is optional per item.

- Capacity modes: **On-Demand** (pay per request, instant scaling) or **Provisioned** (set
  RCU/WCU, cheaper for steady predictable traffic, supports auto-scaling).
- Fully managed replication across three AZs — durability is built in.

## Items

A single record in a table, identified uniquely by its primary key. Maximum size **400 KB**,
which pushes large blobs into S3 with only the pointer stored in DynamoDB.

## Attributes

The name/value pairs inside an item — the equivalent of columns, except that **items in the same
table need not share the same attributes**. Types include scalar (`S`, `N`, `B`, `BOOL`, `NULL`),
document (`M` map, `L` list) and set (`SS`, `NS`, `BS`).

## Partition key

The attribute DynamoDB hashes to decide which physical partition stores the item.

- With no sort key, the partition key alone must be unique.
- Choosing it well is the single most important design decision: a key with few distinct values
  creates a **hot partition** that throttles while the rest of the table sits idle. Prefer
  high-cardinality values (`user_id`, `order_id`) over low-cardinality ones (`status`, `country`).

## Sort key

The optional second half of a composite primary key.

- Items sharing a partition key are stored **together, ordered by sort key**, which makes range
  queries extremely efficient: "all orders for user 42 between two dates" is one `Query`.
- The combination (partition key + sort key) must be unique.
- A common pattern encodes hierarchy into the sort key, e.g. `ORDER#2026-10-07#1234`, enabling
  `begins_with` queries.

### Query vs Scan

- **Query** — targets a single partition key, optionally filtered by sort key. Fast and cheap.
- **Scan** — reads *every* item in the table, then filters. Slow and expensive; avoid in
  production code.

### Secondary indexes

- **LSI (Local)** — same partition key, different sort key. Must be created with the table.
- **GSI (Global)** — a completely different partition and sort key, added any time. This is how
  you support a second access pattern without duplicating the table.

## DynamoDB use cases

- **Session and token stores** — key lookup by session ID, with TTL for automatic expiry.
- **Shopping carts and user profiles** — one item per user, read by `user_id`.
- **IoT / telemetry ingestion** — massive write throughput partitioned by device ID.
- **Leaderboards and activity feeds** — composite keys give ordered range reads.
- **Terraform state locking** — the classic DevOps use: a tiny table holding the lock item.

---

# RDS — Relational Database Service

## Relational database, managed

RDS runs a standard relational engine for you: AWS handles provisioning, OS and engine patching,
backups, monitoring and failover, while you keep normal SQL access. It is **not** serverless by
default — you choose an instance class, and it is billed while it runs. (Aurora Serverless v2 is
the serverless variant.)

## Supported engines

| Engine | Notes |
|---|---|
| **PostgreSQL** | Feature-rich open source; common default |
| **MySQL** | Most widely deployed open source |
| **MariaDB** | MySQL fork |
| **Oracle** | Commercial, BYOL or licence-included |
| **SQL Server** | Commercial, multiple editions |
| **Amazon Aurora** | AWS's own MySQL/PostgreSQL-compatible engine — up to 5× MySQL throughput, 15 read replicas, storage auto-grows |

## DB instances

The compute + storage unit running the engine.

- **Instance class** — `db.t4g.micro` through `db.r6g.16xlarge`, same families as EC2.
- **Storage** — `gp3` SSD (general), `io1/io2` (provisioned IOPS), magnetic (legacy), with
  **storage autoscaling** available.
- **Endpoint** — a DNS name applications connect to. On failover the DNS record is repointed at
  the standby, which is why applications must connect by endpoint, never by IP.
- **Parameter groups** (engine settings) and **option groups** (engine features) hold
  configuration.

## Security

Layered, and all four layers matter:

1. **Network** — place the instance in **private subnets** via a DB subnet group, and never
   enable public accessibility for a production database.
2. **Security groups** — allow the engine port (5432 / 3306) **only from the application's
   security group**, not from a CIDR.
3. **Authentication** — engine-native users, or **IAM database authentication** (token-based, no
   stored password), with credentials held in **Secrets Manager** and rotated automatically.
4. **Encryption** — at rest with KMS (must be enabled at creation; it cannot be turned on in
   place afterwards) and in transit with TLS.

## Backups

- **Automated backups** — daily snapshot plus continuous transaction logs, giving
  **point-in-time recovery** to any second within the retention window (1–35 days).
- **Manual snapshots** — kept until you delete them explicitly; survive instance deletion.
- Restoring **always creates a new instance** — you cannot restore in place, so DR runbooks must
  account for an endpoint change.

## Multi-AZ

Synchronous standby replica in a second Availability Zone.

- Purpose is **high availability, not performance** — the standby serves no reads (in the classic
  Multi-AZ instance deployment).
- Failover is automatic, typically 60–120 seconds, and the endpoint DNS is repointed.
- Also removes backup I/O impact, since backups are taken from the standby.

## Read replicas

Asynchronous copies that **do** serve read traffic.

- Up to 5 per source (15 for Aurora); can live in another region.
- **Eventually consistent** — replica lag means a read right after a write may return stale data.
- Can be **promoted** to a standalone primary, which makes them useful for migrations and for
  regional DR.

```
                    ┌──────────────────┐
   writes ────────► │  Primary (AZ-a)  │
                    └────┬────────┬────┘
            synchronous  │        │  asynchronous
                         ▼        ▼
              ┌──────────────┐  ┌──────────────┐
              │ Standby AZ-b │  │ Read replica │ ◄──── reads
              │ (HA only,    │  │ (scales reads)│
              │  no reads)   │  └──────────────┘
              └──────────────┘
```

## RDS use cases

- **Traditional web/enterprise applications** needing ACID transactions and joins.
- **Reporting and analytics** offloaded to read replicas so dashboards never slow the write path.
- **Lift-and-shift migrations** of an existing MySQL/PostgreSQL/Oracle database into AWS.
- **Multi-AZ production databases** where an AZ outage must not cause data loss.
- **E-commerce and financial systems** where correctness beats raw scale.

---

## Summary

| Need | Service |
|---|---|
| Joins, ad-hoc SQL, transactions | RDS |
| Millisecond key lookups at any scale | DynamoDB |
| Zero capacity planning | DynamoDB (or Aurora Serverless v2) |
| Existing SQL application migration | RDS |
| Unpredictable, spiky traffic | DynamoDB On-Demand |
| Strong relational constraints | RDS |
