# EKS Platform — Terraform

Terraform codebase that provisions the AWS foundation for an EKS platform and
performs a **one-time ArgoCD bootstrap**. Everything else in the cluster
(Istio, Prometheus, cert-manager, external-dns, ESO, Velero, the AWS LB
Controller, Karpenter's Helm chart + NodePools, microservices, …) is owned by
the **GitOps repo** and reconciled by ArgoCD. Terraform's only in-cluster action
is installing ArgoCD and applying the root app-of-apps.

## What this provisions

- **VPC** — 3 AZs, NAT gateway per AZ, private `/20` + public + intra subnets, with the EKS/ELB/Karpenter discovery subnet tags.
- **EKS** — control plane (`authentication_mode = "API"`), KMS envelope encryption, all control-plane logs, restricted public endpoint, 5 core addons (coredns, kube-proxy, vpc-cni, eks-pod-identity-agent, aws-ebs-csi-driver), and a small fixed managed node group (`m6i.large`, 2/3/4).
- **Karpenter (AWS side only)** — controller + node IAM roles, SQS interruption queue, EventBridge rules, via EKS Pod Identity. No NodePool/EC2NodeClass CRs (GitOps).
- **IRSA roles** — scoped OIDC roles for the AWS LB Controller, external-dns, cert-manager, External Secrets, Fluent Bit, Velero, and EBS CSI.
- **Observability** — KMS-encrypted CloudWatch log groups (`retention_in_days = 14`).
- **WAFv2** — regional web ACL (Common, KnownBadInputs, SQLi managed groups + rate rule), **not associated** (annotate the in-cluster ALB with its ARN).
- **global (separate state)** — 3 ECR repos (scan-on-push + lifecycle), a public Route53 zone, and KMS keys (eks-secrets, logs, ebs, s3-backup) with rotation.
- **ArgoCD bootstrap** — `helm_release` + root app-of-apps `Application` → the GitOps repo.

## Layout

```
infra-terraform/
├── Makefile                 # per-project driver (see "Multi-project" below)
├── versions.tf              # canonical provider pins (reference only)
├── projects/                # per-project inputs — the ONLY place you edit per project
│   ├── _template/           # copy this to start a new project
│   └── example-project/          # {common,bootstrap,global,shared}.tfvars + backend.hcl
├── bootstrap/               # LOCAL state — creates the remote-state bucket + KMS + CI role
├── global/                  # account-wide: ECR, Route53, KMS   (its own state)
├── modules/                 # thin wrappers on upstream modules
│   ├── vpc/  eks/  karpenter/  irsa/  observability/  waf/  argocd-bootstrap/
└── environments/
    └── shared/              # the platform cluster (its own state); wires the modules together
```

The root directories (`bootstrap/`, `global/`, `environments/shared/`) are
**project-agnostic** — they contain no project-specific values. All of that
lives in `projects/<name>/`, which the Makefile feeds in via `-var-file` and
`-backend-config`. Adding a project = copy a folder, no code changes.

## Versions (pinned)

| Component | Version |
|---|---|
| Terraform | `>= 1.9` |
| hashicorp/aws | `~> 6.0` |
| hashicorp/kubernetes | `~> 2.0` |
| hashicorp/helm | `~> 2.0` |
| gavinbunney/kubectl | `~> 1.0` |
| terraform-aws-modules/vpc/aws | `~> 6.0` |
| terraform-aws-modules/eks/aws | `~> 21.0` |
| eks/aws//modules/karpenter | `~> 21.0` |
| iam/aws//modules/iam-role-for-service-accounts | `~> 6.0` |
| terraform-aws-modules/s3-bucket/aws | `~> 4.0` |

> **Deviations from the original spec (intentional, required to make it work):**
> 1. **AWS provider is `~> 6.0`, not `~> 5`.** The EKS module `~> 21.0` *requires*
>    the AWS provider `>= 6.x`; the two spec requirements were mutually exclusive
>    and the module version wins.
> 2. **IRSA submodule is `iam-role-for-service-accounts`, not `…-eks`.** The `-eks`
>    suffix was dropped when the IAM module went to v6. It is OIDC-based, so the
>    controller roles use OIDC IRSA (Karpenter and the addons still use Pod Identity).
> 3. **Karpenter `enable_v1_permissions` removed.** The v21 submodule scopes to the
>    Karpenter v1 API by default; the flag no longer exists.

## Prerequisites

- Terraform `>= 1.9`, AWS CLI v2 (used by the `kubernetes`/`helm`/`kubectl` exec auth).
- AWS credentials with permission to create the resources (or the bootstrap CI role).
- A registered parent domain if you want the Route53 zone to resolve publicly.
- Your GitOps repo URL + revision for the ArgoCD handoff.

## Multi-project template

This repo is a **template**: the same code serves many projects, each isolated
by its own state bucket (ideally its own AWS account). A project is defined
entirely by one folder:

```
projects/example-project/
├── common.tfvars     # name_prefix, region, tags   (all roots)
├── bootstrap.tfvars  # ci_trusted_principal_arns
├── global.tfvars     # domain_name, ecr_repositories
├── shared.tfvars     # vpc, eks, nodes, team ARNs, gitops, …
└── backend.hcl       # state bucket + region (filled after bootstrap)
```

`name_prefix` is the single knob that drives resource names **and** the derived
state bucket name (`<name_prefix>-eks-tfstate-<account_id>`) — there is no bucket
name to invent or keep in sync.

**Start a new project:**

```bash
make new-project NAME=acme      # copies projects/_template -> projects/acme
# edit projects/acme/*.tfvars (replace the REPLACE_ME values)
```

**Per-project account isolation.** Set `aws_profile` and/or `assume_role_arn` in
`common.tfvars` to point a project at its own AWS account. Both are optional —
leave them empty to use your default credential chain (env vars / default
profile / instance role). They apply to every root, and `shared` also threads
them into `aws eks get-token` so the Kubernetes/Helm providers authenticate as
the same identity. Recommended layout for strong isolation: one account per
project, with a `terraform` role in each that CI assumes via `assume_role_arn`.

## Apply order

Three independent states, applied in order via the Makefile
(`ROOT = bootstrap | global | shared`). No `cd`, no remembered flags.

```bash
# 1. bootstrap (local state) — creates the remote-state bucket + KMS + CI role
make init  PROJECT=example-project ROOT=bootstrap
make apply PROJECT=example-project ROOT=bootstrap
make output PROJECT=example-project ROOT=bootstrap     # prints `backend_hcl`
# paste that bucket line into projects/example-project/backend.hcl, then:

# 2. global (ECR, Route53, KMS)
make init  PROJECT=example-project ROOT=global
make apply PROJECT=example-project ROOT=global

# 3. shared (the cluster) — reads global's state, then installs ArgoCD
make init  PROJECT=example-project ROOT=shared
make apply PROJECT=example-project ROOT=shared
```

After step 3, ArgoCD owns the cluster; further platform changes go through the GitOps repo.

Under the hood each target runs `terraform -chdir=<root>` with
`-var-file=projects/<name>/common.tfvars -var-file=projects/<name>/<root>.tfvars`
and (for global/shared) `-backend-config=projects/<name>/backend.hcl`.
Prefer raw Terraform? The commands the Makefile prints with `make -n` work standalone.

## CI/CD (Bitbucket Pipelines)

`bitbucket-pipelines.yml` lives at the **repo root** (the infrastructure repository)
— Bitbucket only runs the file from the repository root) and drives Terraform here
via `make -C infra-terraform`. It manages `global` + `shared` only. **`bootstrap`
is never run by CI** — it's a one-time, human-run step (it creates the state bucket, KMS,
and the CI role the pipeline itself depends on). Auth is **OIDC** (no AWS keys in
Bitbucket): each step exchanges its step token for the dedicated CI role
via `AssumeRoleWithWebIdentity`.

- **PR** → `terraform plan` (global + shared), read-only.
- **Merge to `main`** → auto-apply `global`, then a **manual-gated** apply of
  `shared` (global always first — `shared` reads global's state).

**One-time setup:**

1. In `projects/<name>/bootstrap.tfvars`, set `bitbucket_workspace`,
   `bitbucket_workspace_uuid`, `bitbucket_repo_uuid` (Bitbucket → *Repository
   settings → OpenID Connect*), then re-run `make apply ROOT=bootstrap` to create
   the OIDC provider + CI role. Grab the ARN with `make output ROOT=bootstrap`.
2. Set **Repository variables** (*Repository settings → Repository variables*):
   `PROJECT`, `AWS_REGION`, and `CI_ROLE_ARN` (the `ci_role_arn` output).
3. Ensure `endpoint_public_access_cidrs` includes Bitbucket's egress IPs (or use
   an in-VPC self-hosted runner) so the `shared` apply can reach the EKS API.

### Deployment environments

The `apply` steps reference two Bitbucket **Deployment environments**, `global`
and `shared`. Create them under *Repository settings → Deployments*. They give you:

- **Scoped variables** — e.g. a per-env `CI_ROLE_ARN` if global/shared live in
  different accounts (overrides the repo-level variable for that step).
- **Deployment gating & tracking** — restrict who can deploy each environment and
  see a history of what applied when.

Environment names must match the `deployment:` values in the YAML exactly. Order
matters in the UI: put `shared` in the **Production** tier and `global` in
**Staging/Test** so the promotion order reads correctly. The `shared` step also
has `trigger: manual`, so it always waits for a click regardless of environment
config — **if you don't want to use environments at all, just delete the two
`deployment:` lines** and the manual gate still protects the cluster.

## Key variables (per project, in `projects/<name>/`)

| Variable | File | Purpose |
|---|---|---|
| `name_prefix` | common | Project slug; drives all names + the state bucket. |
| `region`, `tags` | common | Region + tag map applied everywhere. |
| `aws_profile`, `assume_role_arn` | common | Target this project's AWS account (see below). Empty = default creds. |
| `ci_trusted_principal_arns` | bootstrap | Who may assume the CI role (empty = skip). |
| `domain_name`, `ecr_repositories` | global | Route53 zone + ECR repos. |
| `dev_team_trusted_principals`, `staging_team_trusted_principals` | global | Who may assume each team role. Empty = role not created. |
| `environment` | shared | Cluster suffix (`example-project-shared`). |
| `vpc_cidr`, `azs` | shared | VPC CIDR (`/16`) and exactly 3 AZs. |
| `kubernetes_version` | shared | Control-plane version (`1.36`). |
| `node_instance_types`, `node_min/desired/max_size` | shared | Bootstrap node group. |
| `endpoint_public_access_cidrs` | shared | **Restrict** to CI egress + admin IPs. |
| `dev_team_role_arn`, `staging_team_role_arn` | shared | **Optional override** — normally left empty; shared reads the ARNs `global` creates via remote state. Set to pre-existing ARNs (e.g. SSO roles) to bypass role creation. |
| `log_retention_days` | shared | Default `14` — see the CloudWatch note below. |
| `gitops_repo_url`, `gitops_target_revision`, `argocd_chart_version` | shared | ArgoCD handoff. |

`state_bucket_name` is an **optional** override in bootstrap/shared; leave it
unset to use the derived name.

> **CloudWatch retention caveat:** CloudWatch Logs only accepts fixed retention
> values (…7, **14**, 30…). **There is no 15-day option.** `14` is the closest
> value under a 15-day target; use `30` if you must round up. A validation on
> `log_retention_days` enforces a legal value.

## Outputs consumed by the GitOps repo (`environments/shared`)

The GitOps manifests read these (SA role annotations, Karpenter EC2NodeClass,
ingress WAF annotation, external-dns zone, ECR image refs, …):

- `cluster_name`, `cluster_endpoint`, `cluster_oidc_provider_arn`, `region`
- `aws_lb_controller_role_arn`, `external_dns_role_arn`, `cert_manager_role_arn`, `external_secrets_role_arn`, `fluent_bit_role_arn`, `velero_role_arn`
- `karpenter_role_arn`, `karpenter_node_iam_role_arn`, `karpenter_queue_name`, `karpenter_instance_profile`
- `cloudwatch_log_group_name`, `waf_web_acl_arn`, `route53_zone_id`, `route53_zone_name`, `ecr_repository_urls`

## Validation

```bash
make fmt                              # or: terraform fmt -recursive
make validate ROOT=global             # validate needs no PROJECT
# offline validate without touching a backend:
cd global && terraform init -backend=false && terraform validate
```

`fmt`, `init`, and `validate` pass in `bootstrap/`, `global/`, and
`environments/shared/`. (Some `validate` warnings originate inside upstream
community modules — e.g. a deprecated `aws_region.name` attribute — not this code.)

## Notes on ordering & providers

- The `kubernetes`/`helm`/`kubectl` providers authenticate via the AWS CLI exec
  token and depend on the EKS outputs. Only `argocd-bootstrap` and the gp3
  StorageClass resources use them, so the rest of the plan is pure AWS.
- The EBS CSI addon role (OIDC) is created in `modules/irsa` and wired into the
  EKS addon. Terraform resolves this at the resource level, so there is no
  module cycle even though `irsa` depends on the cluster's OIDC provider.
- A future second cluster: add another root under `environments/` reusing
  `modules/*` and a new state key.
