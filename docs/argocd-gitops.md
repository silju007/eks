# ArgoCD GitOps Repository Integration Runbook

How ArgoCD authenticates to the private GitOps repo, how to reach the console,
and how to debug a repo that won't sync.

| Setting | Value |
| --- | --- |
| GitOps repo | `git@bitbucket.org:example-org/example-platform-gitops.git` |
| Tracked revision | `main` (`gitops_target_revision`) |
| Root app path | `bootstrap/` (`gitops_bootstrap_path`) |
| Auth method | SSH **read-only Access Key** (deploy key) |
| ArgoCD namespace | `argocd` |

Terraform installs ArgoCD and applies the **root app-of-apps** once; after that
ArgoCD reconciles everything else from the GitOps repo. Terraform's only ongoing
job here is the repository credential.

## How the connection works

1. `modules/argocd-bootstrap` installs ArgoCD (Helm) and creates an `Application`
   whose `repoURL` is `gitops_repo_url` (the `git@…` SSH URL above).
2. When `gitops_ssh_private_key` is set, Terraform creates a Kubernetes Secret in
   the `argocd` namespace labeled `argocd.argoproj.io/secret-type: repository`
   with `type=git`, `url=<repoURL>`, `sshPrivateKey=<key>`. ArgoCD auto-discovers
   it and uses it to clone.
3. The Secret `url` must **exactly** match the Application `repoURL` — both derive
   from the same `gitops_repo_url` var, so keep them SSH (don't mix in an HTTPS
   form).

> The private key is **sensitive** and is never committed. Supply it at apply time
> via `TF_VAR_gitops_ssh_private_key` (local) or the `GITOPS_SSH_PRIVATE_KEY`
> secured pipeline variable. If it's empty, ArgoCD gets no credential and a private
> repo will fail to sync.

## One-time setup: the SSH deploy key

1. **Generate a keypair** (no passphrase — an unattended controller can't unlock one):

   ```bash
   ssh-keygen -t ed25519 -C "argocd-example-project-gitops" -f argocd_gitops -N ""
   # produces: argocd_gitops (private)  argocd_gitops.pub (public)
   ```

2. **Add the PUBLIC key to Bitbucket** as a read-only Access Key on the GitOps repo:
   `example-platform-gitops` → **Repository settings → Access keys → Add key** →
   paste the contents of `argocd_gitops.pub`. (Read-only is exactly what GitOps needs.)

3. **Give the PRIVATE key to Terraform:**
   - **Pipeline (recommended):** *Repository settings → Repository variables* → add
     `GITOPS_SSH_PRIVATE_KEY`, value = the **base64 encoding** of `argocd_gitops`,
     and mark it **Secured**. Bitbucket flattens newlines in variable values, which
     corrupts a raw PEM key (ArgoCD then reports `ssh: no key found`); base64 has no
     newlines, so it survives intact. The pipeline decodes it back to
     `TF_VAR_gitops_ssh_private_key` on the plan + `shared` apply steps.

     ```bash
     base64 -w0 argocd_gitops   # macOS: `base64 -i argocd_gitops` — paste this as the variable value
     ```

   - **Local apply:** pass the raw key directly (no base64 needed — `$(cat …)`
     preserves the newlines):

     ```bash
     export TF_VAR_gitops_ssh_private_key="$(cat argocd_gitops)"
     make apply PROJECT=example-project ROOT=shared
     ```

4. **Delete your local private key** once it's stored (`rm argocd_gitops`).

5. **Apply `shared`** (pipeline or local). Terraform creates the repository Secret.

## Accessing the ArgoCD console

You need cluster access first (see `connect-to-cluster.md`).

1. **Get the initial admin password:**

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath='{.data.password}' | base64 -d; echo
   ```

2. **Port-forward the API/UI:**

   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8080:443
   ```

   Open <https://localhost:8080> (accept the self-signed cert) and log in as
   `admin` with the password above.

3. **Or use the CLI:**

   ```bash
   argocd login localhost:8080 --username admin --password '<password>' --insecure
   argocd repo list          # repo should show STATUS=Successful
   argocd app list           # root app + everything it spawns
   argocd app get root       # detail on the root app-of-apps
   ```

> Change the admin password after first login, or wire SSO — the
> `argocd-initial-admin-secret` is meant to be temporary.

## Verifying the repo connection

```bash
# repo should be reachable
argocd repo list
# STATUS: Successful  →  credential + host key OK

# root app should not be in ComparisonError
kubectl -n argocd get applications.argoproj.io
```

Or in the UI: **Settings → Repositories** shows the repo with a green
"Successful" connection status.

## Troubleshooting

| Symptom | Likely cause / fix |
| --- | --- |
| Repo status `Failed`, `authentication required` / `Permission denied (publickey)` | Deploy key not added to the repo, or the private key in `GITOPS_SSH_PRIVATE_KEY`/`TF_VAR` doesn't match the public Access Key. Regenerate/re-add the pair. |
| `Repository not accessible` / no credential used | `gitops_ssh_private_key` was empty at apply → no Secret created. Set the var and re-apply `shared`; confirm `kubectl -n argocd get secret gitops-repo`. |
| Repo works via SSH manually but ArgoCD says `Host key verification failed` | Host key missing from `argocd-ssh-known-hosts-cm`. bitbucket.org is included by default; if you use a custom host, add it to that ConfigMap. |
| `repoURL` and Secret `url` mismatch (one SSH, one HTTPS) | ArgoCD only matches a credential to an app by exact URL. Keep both on the `git@…` SSH form (both come from `gitops_repo_url`). |
| Root app `ComparisonError: app path does not exist` | `gitops_bootstrap_path` (`bootstrap/`) doesn't exist on `gitops_target_revision`. Create it in the GitOps repo or adjust the var. |
| Private key rejected: `Load key ... invalid format` / `ssh: no key found` | The secured variable lost its newlines — Bitbucket flattens multi-line values to one line. Store `GITOPS_SSH_PRIVATE_KEY` **base64-encoded** (`base64 -w0 argocd_gitops`); the pipeline decodes it. Verify the live key is multi-line: `kubectl -n argocd get secret gitops-repo -o jsonpath='{.data.sshPrivateKey}' \| base64 -d \| head -1` should be exactly `-----BEGIN OPENSSH PRIVATE KEY-----`. |
| App won't sync but repo is fine | Check the target namespace, project, and `kubectl -n argocd logs deploy/argocd-repo-server` / `deploy/argocd-application-controller`. |
| Can't reach the UI | Cluster access not set up (`connect-to-cluster.md`), or the endpoint CIDR allow-list excludes your IP. |

## Rotating the deploy key

1. Generate a new keypair; add the new public key as an Access Key on the repo.
2. Update `GITOPS_SSH_PRIVATE_KEY` (or `TF_VAR`) with the new private key and
   re-apply `shared` — Terraform updates the Secret in place.
3. Remove the old Access Key from Bitbucket.
