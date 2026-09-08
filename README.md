# Secure Static Portfolio on AWS

A personal portfolio/CV site running on a fully automated, monitored, and Infrastructure-as-Code-managed AWS architecture — built to demonstrate practical cloud architecture, security, automation, and operational maturity, not application code.

**Live site:** https://d2udnhhz7y9ums.cloudfront.net
**Companion project:** [Self-Hosted Cloud Infrastructure Homelab](https://github.com/leon-mihaljevic/home-lab) — the on-prem counterpart to this AWS deployment

---

## Architecture

![Architecture diagram](architecture.png)

**Content delivery (the core security model):**
```
Internet → CloudFront (OAC, HTTPS-only) → S3 (private bucket)
```
The bucket is never publicly reachable — every request is denied unless it arrives via CloudFront through Origin Access Control. Verified directly, not assumed: a raw request to the S3 object URL was tested and confirmed denied.

**Deployment pipeline:**
```
git push (site/**) → GitHub Actions (OIDC, no stored credentials) → S3
```

**Cache automation:**
```
S3 object change → Lambda (portfolio-cache-invalidation) → CloudFront cache cleared
```

**Observability:**
```
Lambda errors / CloudFront 5xx rate → CloudWatch Alarms → SNS → Email
```

**Everything above is managed as code:** the entire architecture — S3, CloudFront, Lambda, IAM roles/policies, the GitHub OIDC trust relationship, SNS topics, and CloudWatch alarms — is defined in [`terraform/`](terraform/) and was adopted into Terraform via `import` (not recreated), so the live infrastructure was never at risk during the migration to IaC.

## AWS services used

| Service | Purpose |
|---|---|
| **S3** | Origin storage for static site files, fully private |
| **CloudFront** | CDN, HTTPS termination, HTTP→HTTPS redirect, global edge caching |
| **Lambda** | `portfolio-cache-invalidation` — triggered by S3 object-create events, automatically invalidates the CloudFront cache on every deploy |
| **IAM** | Least-privilege user policy (resource-scoped to this project's exact ARNs), a scoped Lambda execution role, and a scoped GitHub Actions deploy role |
| **GitHub Actions + IAM OIDC** | CI/CD authentication with zero stored AWS credentials — short-lived tokens only |
| **CloudWatch + SNS** | Error-rate and failure alarms, emailed on trigger |
| **Terraform** | Full infrastructure-as-code, adopted via `import` against already-running resources |

## Security model

This project deliberately avoids the common "S3 static website hosting + public bucket" tutorial pattern. Instead:

- **Block Public Access** is enabled on the bucket — no ACLs, no public bucket policy, no exceptions.
- **CloudFront Origin Access Control (OAC)** is the only path into the bucket, via a SigV4-signed request. The bucket policy grants `s3:GetObject` only, scoped to this specific distribution's ARN.
- **No long-lived AWS credentials anywhere in CI.** GitHub Actions authenticates via OIDC — it presents a short-lived, signed token directly to AWS STS to assume a role, rather than storing an access key in GitHub Secrets.
- **Three separate IAM identities, each scoped to exactly what it needs and nothing more:**
  - `aws-portfolio-project-1` (human operator) — resource-scoped to this project's exact S3 bucket, CloudFront distribution, Lambda function, and the two IAM roles below. Not `s3:*`/`cloudfront:*`/`lambda:*` on everything — scoped to exact ARNs, list/enumerate-type actions excepted (AWS requires `Resource: "*"` for those by design).
  - `portfolio-cache-invalidation` execution role — one action (`cloudfront:CreateInvalidation`), one resource (this distribution's ARN). Nothing else.
  - `github-actions-deploy-portfolio` (OIDC role, trust scoped to this exact repo + branch) — `s3:PutObject`/`DeleteObject`/`ListBucket` on this bucket only. No CloudFront permissions at all — invalidation is the Lambda's job, kept deliberately separate.
- **Root is never used day-to-day** and has MFA enabled.

## Automation

**[`lambda/portfolio-cache-invalidation/lambda_function.py`](lambda/portfolio-cache-invalidation/lambda_function.py)** — an S3 "object created" event triggers this function, which calls CloudFront's `create_invalidation` API. No manual cache-clearing step exists anywhere in this project anymore.

**[`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)** — pushing to `main` with changes under `site/` triggers a sync to S3 via OIDC-authenticated GitHub Actions. Cache invalidation then happens automatically via the Lambda above — the two are deliberately decoupled, so invalidation stays correct regardless of *how* a file changes.

## Monitoring

Two CloudWatch alarms, each notifying a region-appropriate SNS topic by email:

- **`portfolio-lambda-errors`** — fires if the cache-invalidation Lambda fails (1+ error in 5 min)
- **`portfolio-cloudfront-5xx`** — fires if CloudFront's 5xx error rate exceeds 5% in 5 min

Both were tested end-to-end by deliberately breaking a permission, confirming the alarm fired and the email arrived, then restoring the permission — not just configured and assumed working.

## Infrastructure as Code

Everything in this project is defined in [`terraform/`](terraform/) and was brought under management via `terraform import` against the already-running, already-live infrastructure — deliberately not recreated from scratch, to avoid any risk of downtime or a changed CloudFront URL during the migration. Every `import` was followed by `terraform plan` to confirm zero drift before moving to the next resource.

**Deliberately left unmanaged** (referenced by ARN/value only, not adopted as Terraform resources):
- The AWS WAF Web ACL (see [Lessons learned](#lessons-learned) — found unintentionally attached, evaluated, and kept out of scope for this project's actual needs)
- The customer-managed IAM policy clone the Lambda console auto-generates for basic execution logging
- The `aws-portfolio-project-1` IAM user itself — it's the identity *running* Terraform, so it's kept out of self-management deliberately (a real bootstrapping consideration, not an oversight)

## Deployment process

```bash
# Site content: automatic via CI/CD on push to main (see .github/workflows/deploy.yml)
git push

# Infrastructure changes: always through Terraform, never the console
cd terraform
terraform plan   # review before ever applying
terraform apply
```

## Cost considerations

Designed to stay effectively free/negligible at portfolio-site traffic levels:

- **S3, CloudFront, Lambda:** free-tier allowances comfortably cover this project's actual usage (Lambda's free tier in particular is permanent, not time-limited).
- **CloudWatch + SNS:** free tier (10 alarms, 1,000 email notifications/month) is also permanent and far exceeds what this project uses.
- **No Route 53/custom domain, no RDS, no always-on compute.**
- **An AWS Budget alarm ($5/month threshold)** was configured before any resource was created, as a safety net.
- **A real cost lesson, not just a cost estimate:** while pulling the CloudFront config for Terraform, an AWS WAF Web ACL was discovered attached to the distribution that had never been deliberately configured — almost certainly opted into via a console default at some point. WAF has no free tier. Cost Explorer confirmed $0 actually billed, and it was evaluated and left in place as a deliberate, informed decision rather than removed reflexively — worth documenting either way, since catching an unintended paid resource *before* it accumulates real cost is exactly the kind of vigilance that matters in production AWS accounts.

## Lessons learned

- The CloudFront **origin path** setting is a path *inside* the bucket, not the bucket name itself — an early misconfiguration caused 403s until corrected.
- **OAC vs. the older OAI approach:** OAC is the current AWS-recommended pattern, integrating directly with SigV4 signing.
- **GitHub's OIDC `sub` claim uses an immutable numeric ID format** (`repo:owner@id/repo@id:ref:...`), not the human-readable `repo:owner/repo:ref:...` form most tutorials show. Diagnosed via CloudTrail by checking the actual `sub` value AWS received on a failed `AssumeRoleWithWebIdentity` call — a good reminder to verify federated-identity claims against the real request rather than trusting documentation examples to be current.
- **An unintended AWS WAF Web ACL was found attached to the distribution** during the Terraform migration — never deliberately configured, likely opted into via a console default. A reminder that "reading the actual live config" (which Terraform import forces you to do) surfaces things that assuming-the-console-matches-your-mental-model doesn't.
- **Lambda console "basic execution role" doesn't attach the AWS-owned managed policy** — it clones it into a customer-managed policy in your account first. Only discovered because Terraform's `import` failed against the ARN I assumed was correct.
- **New AWS Lambda runtimes can outpace Terraform provider support.** `python3.14` wasn't yet in any released AWS provider's validated runtime list — a real, if temporary, tooling gap rather than a configuration mistake.
- **`terraform import` teaches you AWS's actual resource model**, not just Terraform syntax — e.g., discovering that S3 is modeled as 4+ separate resources (bucket, versioning, public-access-block, policy) because that's genuinely how the underlying API is structured, not an arbitrary Terraform design choice.
- **Least-privilege IAM is iterative, not one-shot.** Every phase of this project (CloudWatch, SNS, OAC, Lambda code-signing config, IAM role paths) surfaced a permission gap only discoverable by actually hitting it — confirming policies through real usage, not just writing them and assuming they're complete.

## What's next (honest, not aspirational)

This project is considered feature-complete for its scope. Anything beyond this point (a custom domain, WAF with actual rules, multi-region failover, VPC-based compute) would be over-engineering for a static personal site — deliberately left out rather than added for their own sake. Future changes will show up here as they're made, with `terraform plan` as the source of truth for what's actually live.

---

Built by Leon Mihaljević ([@leon-mihaljevic](https://github.com/leon-mihaljevic)) while preparing for the AWS Solutions Architect Associate certification.
