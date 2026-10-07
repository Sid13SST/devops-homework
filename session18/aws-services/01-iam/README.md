# AWS IAM — Identity and Access Management (Governance)

**Student:** Siddhant Prasad (24BCS10255) · Session 18, Task 2

---

## What is IAM?

IAM is the service that controls **who can do what** in an AWS account. Every single AWS API call
is authenticated and then authorised against IAM policy before it is allowed. IAM is global (not
per-region), free to use, and it is the foundation of AWS security — a misconfigured IAM policy is
the most common cause of a cloud breach.

Two separate questions IAM answers:

| Question | IAM concept |
|---|---|
| Who are you? | **Authentication** — user, role, access key |
| Are you allowed to do this? | **Authorisation** — policy evaluation |

---

## Users

An **IAM user** is a long-lived identity for a person or an application.

- Has either a console password, programmatic access keys (access key ID + secret), or both.
- Credentials are permanent until rotated or deleted — which is exactly why they are risky.
- The **root user** (the email the account was created with) has unrestricted power. Best
  practice: enable MFA on it, create an admin IAM user, and then never use root again.

## Groups

A **group** is a collection of users that share a set of permissions.

- Attach policies to the group, add users to the group — permissions follow membership.
- Groups cannot be nested, and a group is not an identity (nothing can "log in as" a group).
- Typical groups: `Developers`, `DBAs`, `ReadOnlyAuditors`.

## Roles

A **role** is an identity with permissions that is **assumed temporarily** rather than logged into.

- No permanent credentials. Assuming a role returns short-lived STS credentials (15 min–12 h).
- A role has two policies: a **trust policy** (*who* may assume it) and **permission policies**
  (*what* it can do once assumed).
- This is the preferred way to grant access to:
  - **EC2 instances / EKS pods / Lambda functions** — via an instance profile or IRSA, so no keys
    are ever stored on disk
  - **Cross-account access** — another account's identity assumes a role in yours
  - **Federated users** — SSO / Google / corporate SAML identities

Roles over users, wherever possible: temporary credentials cannot be leaked for long.

## Policies

A **policy** is a JSON document listing permissions. The core elements:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOneBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::campus-terraform-demo-24bcs10255",
        "arn:aws:s3:::campus-terraform-demo-24bcs10255/*"
      ],
      "Condition": {
        "IpAddress": { "aws:SourceIp": "203.0.113.0/24" }
      }
    }
  ]
}
```

| Element | Meaning |
|---|---|
| `Effect` | `Allow` or `Deny` |
| `Action` | The API operations, e.g. `s3:GetObject`, or `s3:*` |
| `Resource` | The ARNs the actions apply to |
| `Condition` | Optional extra constraints (source IP, MFA present, tag match, time) |
| `Principal` | *Who* — required in resource-based and trust policies |

Policy types:

- **Identity-based** — attached to a user, group or role.
- **Resource-based** — attached to the resource itself (S3 bucket policy, SQS queue policy). These
  carry a `Principal` and enable cross-account access.
- **Permission boundary** — a ceiling on what an identity *can* be granted.
- **Service Control Policy (SCP)** — an Organizations-level ceiling across whole accounts.

## Permissions — how a request is evaluated

```
request
   │
   ▼
explicit DENY anywhere?  ──yes──► DENIED        (deny always wins)
   │ no
   ▼
explicit ALLOW present?  ──no───► DENIED        (implicit deny is the default)
   │ yes
   ▼
within every boundary / SCP?  ──no──► DENIED
   │ yes
   ▼
ALLOWED
```

Two rules worth memorising: **everything is denied by default**, and **an explicit `Deny` can
never be overridden by an `Allow`**.

## Least privilege

Grant only the permissions actually needed, on only the resources needed, and no more.

Practical steps:

1. Start from zero and add permissions as they prove necessary — never start from `*`.
2. Scope `Resource` to specific ARNs instead of `"*"`.
3. Use **IAM Access Analyzer** and **last-accessed data** to find and strip unused permissions.
4. Separate duties: the identity that deploys should not be the identity that audits.

## IAM best practices

| Practice | Why |
|---|---|
| Lock away the root user, enable MFA | Root cannot be restricted by policy |
| Use roles, not long-lived access keys | Temporary credentials limit blast radius |
| Require MFA for humans | Defeats stolen-password attacks |
| Attach policies to groups/roles, not individual users | Scales and stays auditable |
| Rotate any keys that must exist | Shrinks the window of a leak |
| Prefer AWS managed policies as a starting point, then tighten | Fewer mistakes than hand-writing from scratch |
| Enable CloudTrail | Every IAM decision becomes auditable |
| Use permission boundaries / SCPs | Stops privilege escalation by delegated admins |

## Common use cases

- **EC2 application needs S3 access** → instance profile role with a bucket-scoped policy. No
  keys on the instance.
- **CI/CD pipeline deploys to AWS** → OIDC federation (e.g. GitHub Actions) assuming a deploy
  role, so the pipeline holds no static secrets. This is the same principle the Session 16/17
  pipelines use with `GITHUB_TOKEN`.
- **Third-party auditor needs read-only access** → cross-account role with `ReadOnlyAccess` and a
  trust policy naming their account plus an external ID.
- **Developers need dev but not prod** → separate accounts, with a `Developers` group whose role
  can only be assumed in the dev account.
- **Break-glass emergency access** → a rarely used, heavily audited role requiring MFA.
