# RCA — ArgoCD GitOps repo `ssh: no key found`

Root-cause analysis for the ArgoCD repository connection failing after the
`shared` apply, where the GitOps repo credential was present but unusable.

| | |
|---|---|
| Date | 2026-07-08 |
| Severity | Blocking — ArgoCD could not connect to the GitOps repo (no app sync) |
| Cluster | `example-project-shared` (account `ACCOUNT_ID`, `us-east-1`) |
| Component | `modules/argocd-bootstrap` → `gitops-repo` repository Secret |
| Status | Resolved |

## Symptom

`argocd repo list` reported the GitOps repo as `Failed` with no credential:

```
TYPE  NAME  REPO                                                       CREDS  STATUS  MESSAGE
git         git@bitbucket.org:example-org/example-platform-gitops.git  false  Failed  Unable to connect to repository: … unable to ls-remote HEAD on
                                                                                       repository: failed to list refs: ssh: no key found
```

## Root cause

The `gitops-repo` Kubernetes Secret existed and looked correct — right
`type=git`, matching `url`, and an `sshPrivateKey` beginning with
`-----BEGIN OPENSSH PRIVATE KEY-----`. But the key was **a single line**: every
newline had been collapsed to a space.

```
line count: 1        # a valid OpenSSH key is multiple lines
body line lengths: [410]
```

An OpenSSH/PEM key is only parseable with its real line structure (header,
wrapped base64 body, footer each on their own line). Flattened to one line, the
git SSH client cannot load it and reports `ssh: no key found`. The key
*material* was intact — only its formatting was destroyed.

The corruption entered via the pipeline. The private key is stored in the
Bitbucket **secured repository variable** `GITOPS_SSH_PRIVATE_KEY`, and
`bitbucket-pipelines.yml` passed it straight through:

```yaml
- export TF_VAR_gitops_ssh_private_key="${GITOPS_SSH_PRIVATE_KEY:-}"
```

**Bitbucket flattens newlines in variable values** — contrary to the assumption
baked into the old docs ("Bitbucket preserves newlines in secured variables").
Terraform then wrote that single-line string verbatim into the Secret
(`modules/argocd-bootstrap/main.tf`, `kubernetes_secret_v1.gitops_repo`).

This surfaced only now because it was gated behind an earlier failure: the CI
apply previously died at the EKS access-entry stage (see
`rca-ci-eks-unauthorized.md`). Once that was fixed, CI reached
`argocd-bootstrap` for the first time and created the Secret with the mangled
key.

## Resolution

Encode the key so it carries no newlines through the variable store, and decode
it back inside the pipeline. `bitbucket-pipelines.yml` (both the plan and
`shared`-apply steps):

```yaml
- export TF_VAR_gitops_ssh_private_key="$(printf '%s' "${GITOPS_SSH_PRIVATE_KEY:-}" | base64 -d)"
```

Operational steps:

1. Store `GITOPS_SSH_PRIVATE_KEY` **base64-encoded** (`base64 -w0 argocd_gitops`).
2. Confirm the public key (`argocd_gitops.pub`, comment `argocd-example-project-gitops`)
   is a read-only Access Key on the `example-platform-gitops` repo.
3. Re-run the `shared` apply — Terraform rewrites the Secret with a correctly
   formatted multi-line key.

Local applies are unaffected: `"$(cat argocd_gitops)"` preserves newlines, so the
raw key is passed directly.

Verification:

```bash
kubectl -n argocd get secret gitops-repo \
  -o jsonpath='{.data.sshPrivateKey}' | base64 -d | head -1
# -> -----BEGIN OPENSSH PRIVATE KEY-----   (on its own line)

argocd repo list        # STATUS: Successful
```

## Impact

- No production workload impact.
- ArgoCD could not clone the GitOps repo, so the app-of-apps did not sync until
  the credential was corrected.

## Follow-ups / recommendations

1. **Never apply `shared` without the key set.** The `gitops-repo` Secret is
   `count = gitops_ssh_private_key != "" ? 1 : 0`, so an apply with the variable
   empty (e.g. a local run that forgets to export it) will *destroy* the
   credential. Consider failing fast if the value is unexpectedly empty.
2. **Prefer base64 for any multi-line secret in CI variables** — the same
   flattening applies to other PEM keys/certs passed through Bitbucket.
3. **Key rotation** follows the same path: re-add the public Access Key, update
   the base64 `GITOPS_SSH_PRIVATE_KEY`, re-apply `shared`.
