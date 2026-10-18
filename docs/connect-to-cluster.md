# Connecting to the `example-project-shared` EKS cluster (IAM Identity Center / SSO)

Steps to get `kubectl` access from your machine when you sign in via AWS IAM
Identity Center (SSO).

| | |
|---|---|
| Cluster name | `example-project-shared` |
| Region | `us-east-1` |
| Account | `ACCOUNT_ID` |
| Kubernetes version | `1.36` |
| Auth mode | EKS **access entries** (`authentication_mode = "API"`) |

## 1. Prerequisites

- **AWS CLI v2** — `aws --version` → `aws-cli/2.x`.
- **kubectl** — within one minor of 1.36 (`brew install kubectl`).
- An SSO profile in `~/.aws/config`. This example uses the profile name
  `example-project` (`projects/example-project/common.tfvars`). If it isn't
  SSO-configured yet:
  ```ini
  [sso-session owner]
  sso_start_url = https://<your-portal>.awsapps.com/start
  sso_region    = us-east-1

  [profile example-project]
  sso_session   = owner
  sso_account_id = ACCOUNT_ID
  sso_role_name  = <YourPermissionSetName>
  region         = us-east-1
  ```

## 2. Log in via SSO

```bash
aws sso login --profile example-project
aws sts get-caller-identity --profile example-project
```

`get-caller-identity` returns an **assumed-role** ARN like:
`arn:aws:sts::ACCOUNT_ID:assumed-role/AWSReservedSSO_<PermissionSet>_<hash>/<you>`

## 3. Write the kubeconfig

No `--role-arn` needed — your SSO session already *is* the permission-set role:

```bash
aws eks update-kubeconfig \
  --name example-project-shared \
  --region us-east-1 \
  --profile example-project
```

## 4. Verify

```bash
kubectl get nodes
kubectl get pods -A
```

The endpoint is currently public (`endpoint_public_access_cidrs = ["0.0.0.0/0"]`).
Once that's restricted, your egress IP must be in that list or calls time out —
edit `projects/example-project/shared.tfvars` and re-apply `shared`.

## 5. Getting authorized (`Unauthorized` on a fresh cluster is expected)

Your credentials work, but your SSO role has **no EKS access entry** yet — the
cluster was created by the CI role (`example-project-terraform-ci`), the only admin so far.
Grant your permission-set role cluster-admin **in code**, then apply via the
pipeline:

1. **Find your permission-set role ARN** (there's one per permission set):
   ```bash
   aws iam list-roles --profile example-project \
     --query "Roles[?contains(RoleName,'AWSReservedSSO')].Arn" --output text
   ```
   You'll get something like:
   `arn:aws:iam::ACCOUNT_ID:role/aws-reserved/sso.amazonaws.com/us-east-1/AWSReservedSSO_AdministratorAccess_<hash>`

2. **Strip the SSO path** — EKS stores the ARN path-less, so use ONLY:
   ```
   arn:aws:iam::ACCOUNT_ID:role/AWSReservedSSO_AdministratorAccess_<hash>
   ```
   > ⚠️ Using the full `/aws-reserved/sso.amazonaws.com/<region>/` path form makes
   > EKS and Terraform disagree forever (perpetual diff). Always drop the path.

3. **Add it** to `projects/example-project/shared.tfvars`:
   ```hcl
   cluster_admin_principal_arns = [
     "arn:aws:iam::ACCOUNT_ID:role/AWSReservedSSO_AdministratorAccess_<hash>",
   ]
   ```

4. **Apply `shared`** (via the pipeline, or `make apply PROJECT=example-project ROOT=shared`).
   This creates a cluster-scoped `AmazonEKSClusterAdminPolicy` access entry.

5. Re-run step 3 (`update-kubeconfig`) if needed and `kubectl get nodes` now works.

> Namespace-only access instead of admin? Use the team roles: add your principal
> to `dev_team_trusted_principals` / `staging_team_trusted_principals` in
> `global.tfvars`, apply, then `update-kubeconfig --role-arn …/example-project-dev-team`.

## 6. (Optional) ArgoCD UI

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
kubectl -n argocd port-forward svc/argocd-server 8080:443   # https://localhost:8080  (user: admin)
```

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Unauthorized` | No access entry for your SSO role — §5. |
| SSO creds expired | `aws sso login --profile example-project` again (sessions are short-lived). |
| Perpetual diff on the access entry | You used the full-path SSO ARN — switch to the path-less form (§5.2). |
| Calls hang / time out | Endpoint CIDR allow-list excludes your IP (§4). |
| `exec: aws: executable file not found` | AWS CLI v2 not on `PATH`. |
