# RCA — CI pipeline `Unauthorized` on `shared` apply (Kubernetes/Helm resources)

Root-cause analysis for the Bitbucket pipeline failure applying the `shared`
root, where the Terraform Kubernetes/Helm/kubectl providers could not
authenticate to the `example-project-shared` EKS cluster.

| | |
|---|---|
| Date | 2026-07-07 |
| Severity | Blocking — `make apply ROOT=shared` failed in CI |
| Cluster | `example-project-shared` (account `ACCOUNT_ID`, `us-east-1`) |
| Auth mode | EKS **access entries** (`authentication_mode = "API"`) |
| Status | Resolved |

## Symptom

The pipeline's *Apply shared* step failed with:

```
Error: Unauthorized
  with kubernetes_storage_class.gp3,
  on storageclass.tf line 4 …

Error: the server has asked for the client to provide credentials
  with kubernetes_annotations.gp2_not_default,
  on storageclass.tf line 27 …

Error: Kubernetes cluster unreachable: the server has asked for the client to
provide credentials
  with module.argocd_bootstrap.helm_release.argocd,
  on ../../modules/argocd-bootstrap/main.tf line 5 …
```

All three failures are the same class of error: the AWS-only parts of the plan
succeeded, but every resource that talks to the Kubernetes API was rejected.

## Root cause

The cluster runs with `authentication_mode = "API"` (`modules/eks/main.tf`).
Under API auth, an IAM principal can only reach the Kubernetes API if it has an
**EKS access entry** — broad IAM permissions such as `eks:*` are *not*
sufficient. The Kubernetes/Helm/kubectl providers authenticate with a
short-lived token from `aws eks get-token`, which returns a token for the
calling IAM identity; the cluster then checks that identity against its access
entries.

Two compounding facts produced the failure:

1. **The CI identity had no access entry.** The pipeline assumes the pre-existing
   `example-ci-role` role (dedicated CI role, trusts the configured CI
   Bitbucket workspace OIDC) via its `CI_ROLE_ARN` repository variable. This role
   was never granted an EKS access entry, so its `get-token` output was rejected
   → `Unauthorized`.

   The repo was *designed* around a dedicated least-privilege `example-project-terraform-ci`
   role created by the `bootstrap` root, but that role was never actually created
   (its OIDC-provider resource collides with the pre-existing Bitbucket OIDC
   provider, so the bootstrap apply never completed those resources). The pipeline
   therefore falls back to the pre-existing admin role.

2. **Chicken-and-egg on first apply.** A `shared` apply first *refreshes* the
   already-existing Kubernetes resources (`kubernetes_storage_class.gp3`,
   `kubernetes_annotations.gp2_not_default`, `helm_release.argocd`) — created
   during an earlier local apply. That refresh needs a valid token *before*
   Terraform reaches the point where it would create the CI role's access entry.
   A brand-new CI principal fails at refresh and never gets far enough to grant
   itself access.

   The original `terraform_ci_role_arn` design *auto-derived* the admin entry from
   whoever ran `apply`. Because the cluster was bootstrapped locally by the SSO
   admin, every local apply seeded the SSO admin's entry and never the CI role's —
   so CI could never authenticate.

### Secondary issue (409 on remediation)

While fixing the above, the `shared` apply hit:

```
Error: creating EKS Access Entry (…AWSReservedSSO_AdministratorAccess…):
  409 ResourceInUseException: The specified access entry resource is already
  in use on this cluster.
```

The SSO AdministratorAccess role was listed in `cluster_admin_principal_arns`
*and* is the cluster creator (`enable_cluster_creator_admin_permissions = true`).
That produced two access entries for the same principal → 409.

## Resolution

Changes in `infra-terraform/projects/example-project/shared.tfvars`:

- Pinned `terraform_ci_role_arn` to the role the pipeline actually assumes:
  `arn:aws:iam::ACCOUNT_ID:role/example-ci-role`. This makes the CI
  access entry **stable** regardless of who runs `apply`, breaking the
  auto-derive-from-caller behaviour.
- Set `cluster_admin_principal_arns = []`. The SSO admin keeps cluster-admin via
  the cluster-creator access entry, so the redundant (409-causing) entry is
  removed.

Seeded the entry with **one local apply as the SSO admin** (an identity that
already has cluster access), which broke the chicken-and-egg:

```bash
cd infra-terraform
AWS_PROFILE=example-project AWS_REGION=us-east-1 make apply PROJECT=example-project ROOT=shared AUTO=1
```

> Note: `AWS_PROFILE` must be exported for local runs — the S3 backend does **not**
> read the provider's `aws_profile` var and otherwise falls back to an empty
> credential chain (seen as `403 AccessDenied` acquiring the state lock).

Verification:

```
$ aws eks list-associated-access-policies --cluster-name example-project-shared \
    --principal-arn arn:aws:iam::ACCOUNT_ID:role/example-ci-role
… AmazonEKSClusterAdminPolicy  scope=cluster
```

### Second failure — caller-dependent creator entry (409 in CI)

After the above, the CI run failed again:

```
Error: creating EKS Access Entry (…:role/example-ci-role):
  409 ResourceInUseException …
  with module.eks.module.eks.aws_eks_access_entry.this["cluster_creator"]
```

`enable_cluster_creator_admin_permissions = true` makes the module create a
"cluster creator" access entry for **whoever runs the apply**. Locally that
resolves to the SSO admin; in CI it resolves to `example-ci-role`. So the
CI apply tried to *replace* the creator entry (SSO admin → example-ci-role),
which collided (409) with the explicit `example-ci-role` entry added by
`terraform_ci_role_arn`.

Worse, the replace ran **destroy-before-create**: it destroyed the SSO admin's
creator entry and then failed to create the new one — leaving the **SSO admin
with no cluster access** (`ListAssociatedAccessPolicies` →
`ResourceNotFoundException`). IAM/EKS-API access was unaffected, so recovery was
still possible.

**Fix:** the creator-admin feature is incompatible with applying from multiple
identities. It is now configurable (`modules/eks` var
`enable_cluster_creator_admin_permissions`) and set to **false** for the `shared`
root (`environments/shared/main.tf`). All admins are listed explicitly instead:

- `cluster_admin_principal_arns` — the SSO AdministratorAccess role (restored).
- `terraform_ci_role_arn` — `example-ci-role`.

**Recovery** (SSO admin locked out of k8s but retains EKS-API access): a normal
apply refresh would fail (SSO admin can't read existing k8s resources), so the
SSO admin access entry was recreated via an EKS-API-only apply:

```bash
AWS_PROFILE=example-project AWS_REGION=us-east-1 \
  make apply PROJECT=example-project ROOT=shared AUTO=1 EXTRA='-refresh=false'
```

A subsequent normal `plan` returned **No changes**, confirming k8s access is
restored and state is converged and caller-independent.

After this, re-running the pipeline's *Apply shared* step succeeds.

> Minor residual: the EKS secrets-KMS key's administrator principal is also
> caller-derived, so it flips between the SSO admin and CI role on alternating
> applies. This is an in-place, non-destructive policy update (both identities
> keep key access via the account-root default statement) — noise, not a failure.

## Impact

- No production workload impact (ArgoCD/GitOps unaffected).
- CI was blocked from applying `shared` until the access entry was seeded.

## Follow-ups / recommendations

1. **Least-privilege CI (optional).** CI currently runs as an AdministratorAccess
   role. To adopt the intended least-privilege `example-project-terraform-ci` role: import
   the existing Bitbucket OIDC provider into the `bootstrap` state, apply
   `bootstrap` to create `example-project-terraform-ci`, repoint the `CI_ROLE_ARN`
   repository variable, and re-pin `terraform_ci_role_arn`.
2. **Onboarding new admin/CI principals.** Any new IAM principal that must run
   `shared` applies needs its EKS access entry seeded once by an existing
   cluster-admin (add it to `cluster_admin_principal_arns` / `terraform_ci_role_arn`
   and apply from an identity that already has access).
3. **SSO ARN form.** If the SSO admin is ever re-added to `cluster_admin_principal_arns`,
   use the **path-less** permission-set ARN
   (`role/AWSReservedSSO_AdministratorAccess_<hash>`) to avoid a perpetual diff.
