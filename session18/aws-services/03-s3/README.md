# AWS S3 — Simple Storage Service (Storage)

**Student:** Siddhant Prasad (24BCS10255) · Session 18, Task 2

---

## What is S3?

S3 is **object storage**: you store whole files ("objects") addressed by a key, retrieved over an
HTTP API. It is not a filesystem — there is no partial write and no real directory tree — and it
is not a block device. In exchange you get effectively unlimited capacity, 99.999999999% (11
nines) durability, and no servers to manage.

| | Object storage (S3) | Block storage (EBS) | File storage (EFS) |
|---|---|---|---|
| Unit | Whole object | Disk block | File in a POSIX tree |
| Access | HTTP API | Attached to one instance | NFS mount, many instances |
| Scale | Unlimited | Fixed volume size | Elastic |
| Good for | Backups, media, static sites, data lakes | OS disks, databases | Shared application files |

The Terraform project in `../../terraform-s3-demo/` creates a bucket with versioning,
encryption, public-access blocking and a lifecycle rule — the concrete versions of what follows.

---

## Buckets

A bucket is the top-level container for objects.

- The name is **globally unique across all of AWS** (hence `campus-terraform-demo-24bcs10255`).
- A bucket lives in **one region**; data never leaves it unless you replicate it.
- DNS-compatible naming: lowercase, 3–63 characters, no underscores.
- There is no practical limit on the number of objects in a bucket.

## Objects

An object is the data plus its metadata.

- **Key** — the full name, e.g. `session18/hello.txt`. The `/` is just a character; the "folder"
  structure in the console is a presentation convenience built from key prefixes.
- **Value** — the bytes, up to 5 TB (uploads above 5 GB must use multipart upload).
- **Metadata** — content type, cache headers, and your own `x-amz-meta-*` keys.
- **Version ID** — present when versioning is enabled.
- **ETag** — a checksum, usable for integrity checks and conditional requests.

Objects are immutable: "modifying" one means replacing it (which creates a new version when
versioning is on).

## Storage classes

| Class | Designed for | Retrieval | Min. duration |
|---|---|---|---|
| **Standard** | Frequently accessed | Immediate | — |
| **Intelligent-Tiering** | Unpredictable access | Immediate | — |
| **Standard-IA** | Infrequent, needs fast access | Immediate | 30 days |
| **One Zone-IA** | Infrequent, reproducible data | Immediate | 30 days |
| **Glacier Instant Retrieval** | Archive, occasional instant reads | Milliseconds | 90 days |
| **Glacier Flexible Retrieval** | Archive | Minutes–hours | 90 days |
| **Glacier Deep Archive** | Long-term compliance archive | ~12 hours | 180 days |

Cheaper storage trades away retrieval speed and adds a minimum billing duration plus a retrieval
fee. One Zone-IA also gives up multi-AZ redundancy.

## Versioning

When enabled, every overwrite and delete preserves the previous object as a distinct version.

- Protects against accidental overwrite **and** accidental deletion — a `DELETE` just adds a
  **delete marker**; the data is still there behind it.
- Versioning can be suspended but **never switched back off**.
- Every version is billed, which is why it is normally paired with a lifecycle rule.
- **MFA Delete** can additionally require an MFA token to permanently remove a version —
  ransomware protection for critical buckets.

## Lifecycle policies

Rules that move or expire objects automatically as they age.

```
day 0            day 30              day 90             day 365
Standard ──► Standard-IA ──► Glacier Flexible ──► expired (deleted)
```

Typical actions:

- **Transition** current versions to a cheaper class after N days.
- **Expire** current versions after N days.
- **Expire non-current versions** after N days — the rule used in the Terraform project, which
  stops version history growing without bound.
- **Abort incomplete multipart uploads** after N days — cleans up invisible storage you are
  otherwise billed for.

## Encryption

**At rest** (server-side):

| Mode | Key managed by | Notes |
|---|---|---|
| **SSE-S3** (`AES256`) | AWS | On by default; what the Terraform project sets explicitly |
| **SSE-KMS** | AWS KMS, your CMK | Adds key policies and an audit trail of key usage |
| **SSE-C** | You supply the key per request | AWS stores no key |
| Client-side | You, before upload | S3 only ever sees ciphertext |

**In transit:** TLS. Enforce it with a bucket policy that denies requests where
`aws:SecureTransport` is `false`.

## Bucket policies

A **resource-based** JSON policy attached to the bucket. Because it carries a `Principal`, it can
grant cross-account access — something an identity policy alone cannot do.

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyUnencryptedTransport",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": [
      "arn:aws:s3:::campus-terraform-demo-24bcs10255",
      "arn:aws:s3:::campus-terraform-demo-24bcs10255/*"
    ],
    "Condition": { "Bool": { "aws:SecureTransport": "false" } }
  }]
}
```

Access can be controlled four ways, and they combine: **IAM identity policies**, **bucket
policies**, **ACLs** (legacy — disable them with Object Ownership), and **Block Public Access**,
which overrides everything else. Keeping Block Public Access on is the single most effective
guard against the classic "public S3 bucket" leak, which is why the Terraform project enables all
four of its settings.

## Other features worth knowing

- **Static website hosting** — serve a site straight from a bucket, usually fronted by CloudFront.
- **Pre-signed URLs** — time-limited links that grant temporary access to a private object
  without making it public.
- **Event notifications** — fire Lambda/SQS/SNS on object create or delete; the backbone of
  serverless data pipelines.
- **Replication** (CRR/SRR) — asynchronous copy to another region or bucket for DR or latency.
- **Object Lock** — WORM storage for compliance; even root cannot delete within the retention
  period.
- **S3 Select / Athena** — query objects in place with SQL instead of downloading them.

## Common use cases

- **Backups and archives** — with lifecycle transitions into Glacier.
- **Static website and asset hosting** — HTML/CSS/JS/images behind CloudFront.
- **Data lake** — raw Parquet/JSON queried by Athena, Glue and EMR.
- **Application uploads** — browsers PUT directly to S3 with pre-signed URLs, bypassing the app
  server.
- **Terraform remote state** — the state file in S3 with DynamoDB (or S3 native) locking; the
  standard pattern for team Terraform.
- **Log aggregation** — ALB, CloudTrail and VPC Flow Logs all deliver to S3 natively.
