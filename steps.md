# Live test steps — GitHub Actions + Trivy

Repo: https://github.com/adehuh/trivy-github-actions-demo (public)
Workflow: `.github/workflows/ci.yml` — 21 jobs, same as the PDF, Trivy for security.

Plan (≈ 30–40 min):

| # | What | Expected result |
|---|------|-----------------|
| 0 | Prepare tools | `trivy`, `gh`, `docker` work |
| 1 | Run everything locally | tests OK, all Trivy scans exit 0 |
| 2 | Explain the pipeline | 21 jobs, `needs`, triggers |
| 3 | **Demo A – Terraform CIDR** `0.0.0.0/0` | CI red at `iac_security` → fix → green |
| 4 | Demo B – leaked secret | CI red at `secret_detection` → fix → green |
| 5 | Demo C – vulnerable dependency | CI red at `snyk_dependencies` → fix → green |
| 6 | Merge → production approval | run waits → approve → production jobs run |
| 7 | Cleanup | branches deleted |

---

## 0. Prepare (do this before the session)

```bash
# tools
brew install trivy gh          # docker desktop must be running
trivy --version                # expect 0.76.x
gh auth status                 # logged in as adehuh

# get the code
cd ~/Desktop/PROJECT-WORKSPACE/t-devops
git clone https://github.com/adehuh/trivy-github-actions-demo.git   # skip if folder exists
cd trivy-github-actions-demo
git checkout main && git pull
```

No brew Trivy? Use Docker instead (same flags):

```bash
alias trivy='docker run --rm -v "$PWD:/src" -w /src -v trivycache:/root/.cache aquasec/trivy:0.76.2'
```

> Warm the vulnerability DB once (first run downloads ~80 MB):
> `trivy fs --scanners vuln . >/dev/null`

---

## 1. Run everything locally (same commands as CI)

```bash
# tests  (unit_test / integration_test jobs)
python3 -m unittest discover -s tests -t . -v

# secret_detection
trivy fs --scanners secret --exit-code 1 .

# snyk_dependencies  (Trivy SCA)
trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 .

# iac_security  (Dockerfile + K8s + Terraform)  — skip the intentionally bad example
trivy config --severity HIGH,CRITICAL --exit-code 1 --skip-dirs examples/terraform/fail .

# license_compliance
trivy fs --scanners license --severity HIGH,CRITICAL --exit-code 1 .

# build_image + snyk_container + sbom
docker build -t app:local .
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 app:local
trivy image --format cyclonedx --output sbom.cdx.json app:local
```

After each command: `echo $?` → `0` = pass, `1` = gate blocked.

---

## 2. Explain the pipeline (talking points)

```bash
gh workflow view "CI (Trivy)"
gh run list -L 5
```

- **Triggers**: `pull_request` → validate … supply_chain only; `push main` → full pipeline to production; `schedule` → nightly only.
- **`needs` = GitLab `stages`**: GitHub has no global stages; every dependency is explicit.
- **Gate policy**: `--severity HIGH,CRITICAL --ignore-unfixed --exit-code 1` → fail only on HIGH/CRITICAL that already have a fix.
- **`defaults.run.shell: bash`** → `bash -eo pipefail`. Without it, `trivy … | tee` returns `tee`'s exit 0 and the gate never fails. (The *policy self-test* step proves the gate works.)
- **Same image everywhere**: `build_image` saves `image.tar` → scan/SBOM use that exact file; on `main` it pushes to GHCR and passes the **real `sha256` digest** to staging/production.
- **Production approval**: `environment: production` + Required reviewers (Settings → Environments). YAML alone does not ask for approval.
- **Echo lines** from the PDF are kept, so logs show `[SECRET] …`, `[IAC] …`, then `>>> running: trivy …`.

---

## 3. Demo A — Terraform CIDR block (main demo)

Files already in the repo:

| File | CIDR | Trivy |
|------|------|-------|
| `examples/terraform/pass/main.tf` | `10.0.0.0/16` (VPC only) | ✅ 0 HIGH/CRITICAL |
| `examples/terraform/fail/main.tf` | `0.0.0.0/0`, `::/0` | ❌ AWS-0107 HIGH ×2, AWS-0104 CRITICAL |

> Terraform is **not executed** (no `terraform apply`, no AWS credentials). Trivy only reads the `.tf` files. This is written as a comment in `ci.yml` (`iac_security` job).

### 3.1 Show both examples locally

```bash
trivy config --severity HIGH,CRITICAL --exit-code 1 examples/terraform/pass ; echo "exit=$?"   # exit=0
trivy config --severity HIGH,CRITICAL --exit-code 1 examples/terraform/fail ; echo "exit=$?"   # exit=1
```

### 3.2 Break it on purpose in a PR

```bash
git checkout -b demo/terraform-open-cidr
mkdir -p terraform
```

Type this into `terraform/network.tf`:

```hcl
resource "aws_security_group" "web" {
  name        = "demo-web"
  description = "Web SG"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # BAD: open to the whole internet
  }

  egress {
    description = "All traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]   # BAD: unrestricted egress
  }
}
```

```bash
# local check first (shift-left)
trivy config --severity HIGH,CRITICAL --exit-code 1 terraform/ ; echo "exit=$?"   # exit=1

git add terraform/network.tf
git commit -m "demo: open security group"
git push -u origin demo/terraform-open-cidr
gh pr create --fill --base main

# watch CI
gh pr checks --watch            # iac_security (Trivy config) -> fail
```

Show in browser: PR → Checks → `iac_security (Trivy config)` → log shows
`AWS-0107 (HIGH): Security group rule allows unrestricted ingress from any IP address.`
and later jobs (`build_image` …) are **skipped** because of `needs`.

### 3.3 Fix it

Change both `cidr_blocks` in `terraform/network.tf`:

```hcl
    cidr_blocks = ["10.0.0.0/16"]   # GOOD: only inside the VPC
```

```bash
trivy config --severity HIGH,CRITICAL --exit-code 1 terraform/ ; echo "exit=$?"   # exit=0

git commit -am "fix: restrict security group to VPC CIDR"
git push
gh pr checks --watch            # all green
```

Talking point: Trivy checks **any** CIDR rule — `0.0.0.0/0` (IPv4) and `::/0` (IPv6) both fail; private ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) or a specific office IP like `203.0.113.10/32` pass.

---

## 4. Demo B — leaked secret

> Use a **fake** token. Never paste a real one.

```bash
git checkout main && git pull
git checkout -b demo/secret-leak

# generate a fake GitHub-token-looking string
echo "GITHUB_TOKEN = \"ghp_$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)\"" > app/config.py

trivy fs --scanners secret --exit-code 1 . ; echo "exit=$?"   # CRITICAL: GitHub (github-pat), exit=1
```

Push it to show CI blocking:

```bash
git add app/config.py && git commit -m "demo: hardcoded token"
git push -u origin demo/secret-leak
gh pr create --fill --base main
gh pr checks --watch            # secret_detection (Trivy) -> fail; everything after is skipped
```

> If `git push` is rejected by **GitHub push protection**, that's fine: show it as a second layer of defense, then just demo the local Trivy result.

Fix:

```bash
cat > app/config.py <<'EOF'
import os
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")   # from env / GitHub Secrets
EOF
git commit -am "fix: read token from environment"
git push
gh pr checks --watch            # green
```

Talking point: in real life, a leaked secret must be **revoked/rotated** — removing it in a new commit doesn't remove it from git history.

---

## 5. Demo C — vulnerable dependency

```bash
git checkout main && git pull
git checkout -b demo/vulnerable-dep

echo "requests==2.19.0" >> requirements.txt
trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 . ; echo "exit=$?"
# requests CVE-2018-18074 HIGH, fixed in 2.20.0 -> exit=1

git commit -am "demo: old requests"
git push -u origin demo/vulnerable-dep
gh pr create --fill --base main
gh pr checks --watch            # snyk_dependencies (Trivy SCA) -> fail
```

Fix:

```bash
sed -i '' 's/requests==2.19.0/requests==2.34.2/' requirements.txt
trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 . ; echo "exit=$?"   # exit=0
git commit -am "fix: bump requests to 2.34.2"
git push
gh pr checks --watch            # green
```

---

## 6. Merge → production approval

Merge the fixed Terraform PR (Demo A):

```bash
gh pr merge demo/terraform-open-cidr --squash --delete-branch
gh run list -L 1                # new push run on main
gh run watch                    # stops at production_deploy: "Waiting"
```

Approve in browser: Actions → the run → yellow banner **Review deployments** → tick `production` → **Approve and deploy**.

Or approve from the terminal:

```bash
RUN_ID=$(gh run list -L 1 --json databaseId --jq '.[0].databaseId')
ENV_ID=$(gh api repos/adehuh/trivy-github-actions-demo/environments/production --jq .id)
gh api -X POST repos/adehuh/trivy-github-actions-demo/actions/runs/$RUN_ID/pending_deployments \
  -F "environment_ids[]=$ENV_ID" -f state=approved -f comment="approved in live demo"
gh run watch $RUN_ID            # production_deploy, smoke, monitor -> green
```

Show in logs: `[PROD] Promote EXACT image ghcr.io/adehuh/trivy-github-actions-demo@sha256:…; no rebuild`.

---

## 7. Cleanup

```bash
gh pr close demo/secret-leak     --delete-branch
gh pr close demo/vulnerable-dep  --delete-branch
git checkout main && git pull
git branch -D demo/secret-leak demo/vulnerable-dep 2>/dev/null
```

Old runs waiting for approval: Actions → run → **Cancel workflow** (or `gh run cancel <id>`).

---

## Cheat sheet

| Need | Command |
|------|---------|
| Latest runs | `gh run list -L 5` |
| Watch a run | `gh run watch <id>` |
| Only failed logs | `gh run view <id> --log-failed` |
| Re-run failed jobs | `gh run rerun <id> --failed` |
| Manual run (PR path) | `gh workflow run "CI (Trivy)"` |
| Open in browser | `gh run view <id> --web` |
| Trivy JSON output | `trivy config -f json -o out.json .` |
| Ignore one finding (with reason) | add `AWS-0104` line to `.trivyignore` |

| Trivy check | Meaning |
|-------------|---------|
| AWS-0107 | SG ingress from `0.0.0.0/0` / `::/0` |
| AWS-0104 | SG egress to `0.0.0.0/0` |
| KSV-0125 | K8s image from untrusted registry (MEDIUM, not gated) |
| github-pat | hardcoded GitHub token |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `TOO MANY REQUESTS` downloading DB | `trivy.yaml` already uses `mirror.gcr.io`; re-run job |
| `build_image`: `error from registry: denied` | first GHCR push only; job retries 3×, or `gh run rerun <id> --failed` |
| Job green but Trivy found issues | check `defaults.run.shell: bash` is still in `ci.yml` (pipefail) |
| Production job not waiting | Settings → Environments → production → Required reviewers set? |
| Nightly job never ran | runs only on `schedule` at 02:00 UTC (09:00 WIB) |
