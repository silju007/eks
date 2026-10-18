# Infrastructure & GitOps Improvement Plan

Findings from a full review of both repos on 2026-07-09:
- **Infra repo**: `example-infra` (Terraform, EKS, account `ACCOUNT_ID`, `us-east-1`)
- **GitOps repo**: `example-platform-gitops` (ArgoCD app-of-apps, Helm)

Each item is self-contained and can be handed to Claude Code individually, e.g.:
`claude "implement item 1 from docs/improvement-plan.md"`

---

## P0 — Critical (fix before production traffic)

### 1. Fix single NAT gateway (HA violation)
- **Repo**: example-infra
- **File**: `infra-terraform/modules/vpc/main.tf` (~lines 24-27)
- **Problem**: Code sets `single_nat_gateway = true` while the comment and README claim "NAT gateway per AZ". Only 1 NAT exists — an AZ failure kills all cluster egress.
- **Fix**: Set `single_nat_gateway = false`, `one_nat_gateway_per_az = true`. Update README.md if needed.
- **Cost impact**: +~$65/month (2 extra NAT gateways + EIPs).
- **Verify**: `terraform plan` shows 2 new `aws_nat_gateway` resources, one per remaining AZ.

### 2. Restrict EKS public API endpoint
- **Repo**: example-infra
- **File**: `infra-terraform/projects/example-project/shared.tfvars` (`endpoint_public_access_cidrs`)
- **Problem**: Currently `["0.0.0.0/0"]` — the Kubernetes API is reachable from any IP (auth still required, but attack surface is maximal).
- **Fix**: Replace with office/VPN CIDRs + Bitbucket Pipelines egress IPs (see Atlassian's published IP ranges). Alternatively disable public access entirely and use the private endpoint via VPN.
- **Verify**: `aws eks describe-cluster --name example-project-shared --query 'cluster.resourcesVpcConfig.publicAccessCidrs'`

### 3. Switch Istio mTLS from PERMISSIVE to STRICT
- **Repo**: example-platform-gitops
- **File**: `config/istio-mtls/peer-authentication.yaml`
- **Problem**: `mode: PERMISSIVE` accepts plaintext in-mesh traffic (existing TODO in file).
- **Fix**: Confirm all workloads in `development`/`staging` have sidecar injection, then set `mode: STRICT`.
- **Verify**: `istioctl x describe pod <pod>` shows STRICT; services still pass readiness.

### 4. Verify Velero backup bucket name and test a restore
- **Repo**: example-platform-gitops
- **File**: `platform/velero.yaml`
- **Problem**: Bucket name `example-project-shared-velero-backups` is marked as a placeholder — if it doesn't match the Terraform-created bucket, backups fail silently.
- **Fix**: Compare with the Terraform output in `example-infra` (`environments/shared`, Velero S3 bucket). Then run `velero backup create test-backup` and `velero restore` into a scratch namespace.

---

## P1 — High (security hardening)

### 5. Switch Kyverno policies from Audit to Enforce
- **Repo**: example-platform-gitops
- **Files**: `config/kyverno-policies/*.yaml`
- **Problem**: `require-resource-limits` and `disallow-latest-tag` are `validationFailureAction: Audit` — violations are logged, not blocked.
- **Fix**: Check PolicyReports for existing violations, remediate, then flip to `Enforce`.

### 6. Dedicated IRSA role for Grafana (stop reusing fluent-bit role)
- **Repos**: both
- **Files**: `example-infra` `infra-terraform/modules/irsa/main.tf` (add role); `example-platform-gitops` `platform/kube-prometheus-stack.yaml` (Grafana serviceAccount annotation)
- **Problem**: Grafana's CloudWatch datasource reuses the fluent-bit role, which has log *write* permissions. Grafana only needs read.
- **Fix**: Add a `grafana` IRSA role in Terraform scoped to `cloudwatch:GetMetricData`, `logs:GetLogEvents`, `logs:StartQuery`, `logs:GetQueryResults`, etc. Export the ARN, update the GitOps annotation.

### 7. Tighten CI role IAM permissions
- **Repo**: example-infra
- **File**: `infra-terraform/bootstrap/ci-iam.tf` (~lines 135-151)
- **Problem**: CI role has wildcard resource ARNs on ec2, eks, iam, kms, etc. A compromised pipeline gets near-account-admin.
- **Fix**: Scope IAM actions to the resources Terraform actually manages (cluster name prefix `example-project-*`, specific KMS key ARNs, state bucket). Keep read-only `Describe*`/`List*` broad if needed for plans.

### 8. Environment separation / promotion flow in GitOps
- **Repo**: example-platform-gitops
- **Problem**: `development` and `staging` both track `main` — one merge changes both environments simultaneously; no independent rollback.
- **Fix (pick one)**:
  - a) Keep one branch but require PR approval + CODEOWNERS on `apps/staging/**` paths, or
  - b) Point staging Applications at a `release/staging` branch (change `targetRevision` in `apps/staging/*.yaml`).
- Recommended: (a) first — lowest friction; move to (b) when a production env is added.

---

## P2 — Medium (operability)

### 9. Add ArgoCD Notifications for sync failures
- **Repo**: example-platform-gitops
- **Fix**: Enable the notifications controller in the ArgoCD Helm values (bootstrapped from `example-infra` `modules/argocd-bootstrap`) and add a Slack trigger for `on-sync-failed` / `on-health-degraded`.

### 10. Add Terraform linting/scanning to CI
- **Repo**: example-infra
- **Files**: `bitbucket-pipelines.yml`, `infra-terraform/Makefile`
- **Fix**: Add `terraform fmt -check`, `tflint`, and `checkov` (or `trivy config`) as a PR step before `plan`. Add a pre-commit config for local use.

### 11. Reduce Istio trace sampling
- **Repo**: example-platform-gitops
- **File**: `config/istio-mtls/telemetry.yaml`
- **Problem**: `randomSamplingPercentage: 100.0` — Jaeger/Elasticsearch (2×30Gi) will fill fast under real traffic.
- **Fix**: Drop to 10–20% for staging; keep 100% only in development if desired.

### 12. Safer external-dns policy
- **Repo**: example-platform-gitops
- **File**: `platform/external-dns.yaml`
- **Problem**: `policy: sync` deletes Route53 records when an HTTPRoute is removed — one bad prune deletes DNS.
- **Fix**: Consider `policy: upsert-only` for staging/production zones (trade-off: manual cleanup of stale records).

### 13. Values schema for the shared microservice chart
- **Repo**: example-platform-gitops
- **File**: add `charts/microservice/values.schema.json`
- **Why**: Typos in `apps/*/values/*.yaml` currently surface only as render failures or silent defaults.

### 14. Document secret provisioning/rotation runbook
- **Repos**: both (`docs/`)
- **Why**: Alertmanager (Slack URL, PagerDuty key) and per-service secrets are expected to exist in AWS Secrets Manager under `example-project/<env>/<service>`, but there's no documented procedure for creating or rotating them, nor for rotating the ArgoCD GitOps SSH key.

---

## P3 — Low (polish)

### 15. Reconcile README/spec claims with code (NAT per AZ, Velero wave numbers).
### 16. Per-repo ECR lifecycle retention override (`ecr_image_retention_count` is a single global value of 20).
### 17. Enable NLB access logs to S3 for the istio-ingressgateway load balancer (bucket via Terraform).
### 18. Review Karpenter `general-purpose` consolidation (`consolidateAfter: 1m` may cause pod churn; consider 5m).
### 19. Monitor Prometheus TSDB growth (50Gi, 15d retention) and OpenCost data as workloads ramp.

---

## What's already good (keep doing this)

- Clean separation: Terraform owns AWS + cluster + IAM/IRSA; ArgoCD/GitOps owns everything in-cluster. Handoff via a single bootstrapped root Application is the right pattern.
- Remote state per root (bootstrap/global/shared), KMS-encrypted, S3-native locking, versioned bucket.
- Modules wrap community terraform-aws-modules at pinned versions; project template for reuse.
- OIDC-based CI (no static AWS keys), plan-on-PR, manual gate before `apply shared`.
- App-of-apps with sync waves, AppProjects fencing dev/staging teams to their namespaces, automated sync with prune+selfHeal and sane retry/backoff.
- All Helm chart versions pinned; no secrets in git (ESO + Secrets Manager via IRSA everywhere); shared microservice chart with probes, HPA, PDB, topology spread, restricted securityContext, NetworkPolicies, ResourceQuotas.
- Karpenter for workload nodes (spot-first general pool + tainted on-demand stateful pool), small managed node group only for bootstrap-critical pods.
