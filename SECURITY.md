# Security policy

This repository is an infrastructure-learning project and intentionally demonstrates
security controls for AWS, Terraform, Kubernetes, and GitHub Actions.

## Automated controls

Pull requests and `main` runs execute the quality and security gate in
[`.github/workflows/terraform.yml`](.github/workflows/terraform.yml):

- Terraform formatting, initialization, and validation
- Checkov scans for Terraform and GitHub Actions misconfigurations
- Trivy filesystem scans for high/critical configuration and secret findings
- Gitleaks full-history secret scanning
- SARIF results uploaded to GitHub Code Scanning when repository permissions allow

Cloud-backed Terraform plans are not run for fork pull requests. This prevents
untrusted fork code from accessing AWS credentials while retaining static security
coverage for those pull requests.

## Reporting a vulnerability

Do not open a public issue containing credentials or exploit details. Use GitHub's
private vulnerability reporting for this repository, or contact the repository owner
privately with reproduction steps and affected files.
