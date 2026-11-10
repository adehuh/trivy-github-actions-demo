# Trivy + GitHub Actions demo

GitHub Actions–only version of the 21-job pipeline from *GitLab CI vs GitHub Actions* (GitLab ignored).
Same job names, `needs` order and triggers as the PDF, but security jobs run **real Trivy** scans.

| PDF job | What runs here |
|---|---|
| secret_detection | `trivy fs --scanners secret` |
| snyk_dependencies | `trivy fs --scanners vuln` (SCA) |
| iac_security | `trivy config .` (Dockerfile + K8s) |
| kubernetes_validation | `trivy config k8s/` |
| license_compliance | `trivy fs --scanners license` |
| build_image | real `docker build`; push to GHCR on `main` → real `sha256` digest |
| snyk_container | `trivy image --input image.tar` |
| sbom | `trivy image --format cyclonedx / spdx-json` (artifact) |
| nightly_regression | nightly rebuild + Trivy rescan (02:00 UTC) |
| unit_test / integration_test | real `python -m unittest` |
| others | echo simulations, as in the PDF |

Gate policy: fail on **HIGH/CRITICAL with a fix available** (`--ignore-unfixed`).

Triggers: `pull_request` → validate…supply_chain · `push main` → full pipeline to production · `schedule` → nightly only · `workflow_dispatch` → same as PR path.

Manual production approval: Settings → Environments → `production` → Required reviewers.

Run locally:
```bash
python -m unittest discover -s tests -t .
docker build -t app . && trivy image --severity HIGH,CRITICAL --ignore-unfixed app
trivy config . && trivy fs --scanners secret,vuln,license .
```

## Terraform examples (CIDR)
- `examples/terraform/pass` — security group limited to `10.0.0.0/16` → passes Trivy.
- `examples/terraform/fail` — `0.0.0.0/0` / `::/0` → blocked (AWS-0107, AWS-0104). Skipped by the gate; a CI *policy self-test* requires Trivy to block it.
- Terraform is scanned statically only — never applied (no cloud credentials).

Live-demo guide: [steps.md](steps.md)
