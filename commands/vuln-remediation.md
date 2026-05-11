---
name: torch:vuln-remediation
description: Remediate dependency vulnerabilities in the current repository via package upgrades, validate quality gates, and open a draft PR
argument-hint: "[jira-ticket-key]"
---

# Vulnerability Remediation

Remediate all dependency vulnerabilities in the current repository where a fix is available. Prefer package upgrades over code changes. If code changes are required, explain them before implementing.

**Arguments:** "$ARGUMENTS"

Follow these phases exactly. Do not skip phases.

---

## Phase 1: Setup

### 1. Determine the Jira ticket key

- If a Jira ticket key was provided as the first argument, use it.
- Otherwise, attempt to extract it from the current branch name (pattern: `[A-Z]+-\d+`, e.g. `APL-1234` from `feature/APL-1234-vulns`).
- If no ticket key can be determined, ask the user for it before proceeding.

The resolved ticket key is used for the branch name, commit message scope, and PR title.

### 2. Detect the default branch

```bash
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
```

### 3. Handle uncommitted changes

Run `git status`. If the working tree has uncommitted changes:

- **Unrelated to vulnerability remediation**: stop and ask the user to commit, stash, or discard them before re-running.
- **From a prior failed run on the same branch**: ask the user whether to keep them (in which case skip ahead to Phase 4 to validate, then Phase 5 to commit) or discard and start over.

Do NOT silently `git stash` — a stash here would be left dangling and the user might not realize their work is sitting in the stash list.

### 4. Sync the default branch

```bash
git checkout <default-branch>
git pull origin <default-branch>
```

### 5. Resolve the working branch

The command must be safe to re-run on an in-flight remediation. Fetch first so remote branches are known:

```bash
git fetch origin
```

Then handle the four cases:

- **Branch exists locally AND on remote** — check it out, pull, and rebase onto the freshly-synced default:

  ```bash
  git checkout <TICKET-KEY>
  git pull --rebase origin <TICKET-KEY>
  git rebase <default-branch>
  ```

- **Branch exists ONLY on remote** — track and check it out, then rebase onto default:

  ```bash
  git checkout -b <TICKET-KEY> origin/<TICKET-KEY>
  git rebase <default-branch>
  ```

- **Branch exists ONLY locally** — check it out and rebase onto default:

  ```bash
  git checkout <TICKET-KEY>
  git rebase <default-branch>
  ```

- **Branch does not exist anywhere** — create it from default:

  ```bash
  git checkout -b <TICKET-KEY>
  ```

If the rebase produces conflicts, resolve them before proceeding — do NOT blindly use `--theirs`/`--ours`, since the existing branch may already contain partial remediation work worth preserving.

---

## Phase 2: Scan

### 1. Run a human-readable grype scan

Show only findings that have a known fix:

```bash
grype dir:. --only-fixed -o table -q 2>&1
```

### 2. Capture structured JSON output for parsing

```bash
GRYPE_JSON=$(mktemp -t grype-results.XXXXXX.json)
grype dir:. --only-fixed -o json -q > "$GRYPE_JSON"
```

### 3. Short-circuit on zero findings

Parse the JSON. If there are **no findings with available fixes**, stop here:

- Print: "No remediable vulnerabilities found."
- Clean up: `rm -f "$GRYPE_JSON"`
- Do NOT proceed to Phase 3, Phase 4, or Phase 5 — running them on a clean repo produces nondeterministic lockfile churn and empty commits.

### 4. Build the remediation list

For each finding, extract:

- Package name
- Ecosystem / type (e.g. `python`, `npm`, `go-module`)
- Installed version
- Fixed-in version
- CVE ID
- Severity

### 5. Present a summary table

Show the user the findings as a table before proceeding to remediation.

---

## Phase 3: Remediate

Apply fixes for **every ecosystem detected in the scan**. Run **each** applicable section below — do not stop after the first match. A repo may contain multiple ecosystems (e.g. uv + npm + Go); every section whose gating files exist must be executed before moving to Phase 4.

For each finding, prefer the **minimum version bump** that resolves the vulnerability (patch over minor, minor over major).

### Override policy (applies to every ecosystem below)

**Manifest overrides for transitive dependencies are a LAST RESORT.** This includes `overrides` / `resolutions` (npm), `constraint-dependencies` (uv), `[tool.pdm.resolution.overrides]` (PDM), `replace` directives (Go), `[patch]` sections (Cargo), constraint pins in `requirements.in` (pip-tools), and explicit transitive pins in the manifest (Poetry, pipenv, Bundler).

For every transitive vulnerability, try these in order. Only escalate to the next step if the previous one cannot resolve it:

1. **Targeted lockfile update** — e.g. `uv lock --upgrade-package <pkg>`, `poetry update <pkg>`, `pdm update <pkg>`, `pipenv update <pkg>`, `npm update <pkg>`, `go get -u <pkg>@<ver>`, `cargo update -p <pkg>`, `bundle update <pkg>`. This is the default path.
2. **Upgrade the parent direct dependency** — if the lockfile update is blocked because a direct dependency pins an old version of the transitive, upgrade the direct dependency to a release whose constraints allow the fixed transitive.
3. **Manifest override** — only after (1) and (2) are infeasible. When you do this, you MUST document it in the PR description: which override, which transitive package, why steps 1 and 2 didn't work, and what condition would let you remove it.

Also clean up any existing overrides that are no longer needed after this round of upgrades.

**Before each upgrade, check for breaking changes:**

- Review the package's changelog / release notes between the current and target version
- Look for `BREAKING CHANGE:` markers
- For major version bumps, analyze the impact before proceeding
- If breaking changes affect the codebase, either fix the code or note it as a blocker in the PR

### Python (uv workspace)

If `pyproject.toml` and `uv.lock` exist at the repo root:

1. For **direct dependencies** (listed in `[project.dependencies]` or `[dependency-groups]` in any workspace `pyproject.toml`): update the version pin/constraint in the relevant `pyproject.toml`, then run:

   ```bash
   uv lock
   uv sync --all-groups --all-packages
   ```

2. For **transitive dependencies** (not directly listed in any `pyproject.toml`): use `uv lock --upgrade-package` to upgrade only the vulnerable package in the lock file without constraining the manifest:

   ```bash
   uv lock --upgrade-package <package-name>
   uv sync --all-groups --all-packages
   ```

3. **Last resort only** — `constraint-dependencies` in `pyproject.toml` if `--upgrade-package` cannot resolve the vulnerability (e.g. when a direct dependency pins an old transitive version). Per the override policy above, this requires PR documentation explaining why steps 1 and 2 failed.

### Python (Poetry)

If `pyproject.toml` and `poetry.lock` exist:

1. For **direct dependencies** (listed in `[tool.poetry.dependencies]` or `[tool.poetry.group.*.dependencies]`): use `poetry add` to update to the fixed version:

   ```bash
   poetry add <package-name>@<fixed-version>
   ```

   Or edit `pyproject.toml` directly and run `poetry lock --no-update && poetry install`.

2. For **transitive dependencies**: update only that package in the lock:

   ```bash
   poetry update <package-name>
   ```

3. **Last resort only** — Poetry has no formal override mechanism. The workaround is to add the vulnerable transitive as an explicit direct dependency in `[tool.poetry.dependencies]` pinned to the fixed version, forcing Poetry's resolver to use it. Per the override policy above, this requires PR documentation explaining why steps 1 and 2 failed.

### Python (PDM)

If `pyproject.toml` and `pdm.lock` exist:

1. For **direct dependencies** (listed in `[project.dependencies]` or `[tool.pdm.dev-dependencies]`): use `pdm add` to update to the fixed version:

   ```bash
   pdm add "<package-name>>=<fixed-version>"
   ```

   Or edit `pyproject.toml` directly and run `pdm lock --no-update && pdm install`.

2. For **transitive dependencies**: update only that package in the lock:

   ```bash
   pdm update <package-name>
   ```

3. **Last resort only** — PDM exposes a first-class override table in `pyproject.toml`:

   ```toml
   [tool.pdm.resolution.overrides]
   vulnerable-pkg = "<fixed-version>"
   ```

   Per the override policy above, this requires PR documentation explaining why steps 1 and 2 failed.

### Python (pipenv)

If `Pipfile` and `Pipfile.lock` exist:

1. For **direct dependencies** (listed in `[packages]` or `[dev-packages]` in `Pipfile`): update with `pipenv install`:

   ```bash
   pipenv install "<package-name>~=<fixed-version>"
   ```

2. For **transitive dependencies**: update only that package in the lock:

   ```bash
   pipenv update <package-name>
   ```

3. **Last resort only** — pipenv has no formal override mechanism. The workaround is to pin the transitive directly in `[packages]` of the `Pipfile`, forcing pipenv's resolver to use it. Per the override policy above, this requires PR documentation explaining why steps 1 and 2 failed.

### Python (pip)

If `requirements.txt` exists and no `pyproject.toml` or `Pipfile`:

**With pip-tools** (if `requirements.in` exists):

1. For **direct dependencies**: update the version in `requirements.in`.
2. For **transitive dependencies**: do NOT add to `requirements.in`. Let pip-tools resolve:

   ```bash
   pip-compile requirements.in
   pip-sync requirements.txt
   ```

   If pip-tools doesn't pick up the fixed version, you may need to update a parent dependency or add a constraint comment in `requirements.in`.

**Without pip-tools** (flat `requirements.txt`):

1. Update pinned versions in `requirements.txt` to the fixed version.
2. Reinstall: `pip install -r requirements.txt`.

### Node.js (npm or yarn)

If `package.json` and `package-lock.json` exist:

1. Check for nested `package.json` files in subdirectories (e.g. `cdk/`, `frontend/`). Each needs to be handled separately.

2. For each location, try `npm audit fix` first:

   ```bash
   npm audit fix
   ```

3. If `npm audit fix` does not resolve the finding:
   - **Direct dependencies**: update the version in `package.json` and run `npm install`.
   - **Transitive dependencies**: use `npm update` to upgrade only that package without adding it to `package.json`:

     ```bash
     npm update <package-name>
     ```

     This updates `package-lock.json` while keeping `package.json` clean.

4. **Last resort only** — `overrides` (npm 8.3+) or `resolutions` (yarn) in `package.json`. Per the override policy above, this requires PR documentation explaining why steps 1–3 failed.

5. For subdirectories, `cd` into each and run the appropriate commands there.

### Go

If `go.mod` exists:

1. For **direct dependencies**: update the module version:

   ```bash
   go get package@v<fixed-version>
   go mod tidy
   ```

2. For **transitive dependencies**: update without adding to `go.mod`:

   ```bash
   go get -u package@v<fixed-version>
   go mod tidy
   ```

   Go's module system will update `go.sum` while keeping `go.mod` focused on direct dependencies.

3. **Last resort only** — if a direct dependency pins an old vulnerable transitive and cannot be upgraded, a `replace` directive in `go.mod` can force the resolution:

   ```go
   replace vulnerable/pkg => vulnerable/pkg v<fixed-version>
   ```

   Per the override policy above, this requires PR documentation explaining why steps 1 and 2 failed.

### Ruby

If `Gemfile` exists:

1. For **direct dependencies**: update the version in `Gemfile`, then:

   ```bash
   bundle install
   ```

2. For **transitive dependencies**: use `bundle update` to upgrade only that gem:

   ```bash
   bundle update <gem-name>
   ```

   Bundler updates `Gemfile.lock` while keeping `Gemfile` focused on direct dependencies.

3. **No manifest-override mechanism** — Bundler has no `overrides`/`resolutions`/`replace` equivalent. If steps 1 and 2 fail, the only path is pinning the transitive directly in the `Gemfile`. Per the override policy above, this requires PR documentation.

### Rust (Cargo)

If `Cargo.toml` and `Cargo.lock` exist:

1. For **direct dependencies**: update the version in `Cargo.toml`, then:

   ```bash
   cargo update
   ```

2. For **transitive dependencies**: use `cargo update` with the specific package:

   ```bash
   cargo update -p <package-name>
   ```

   This updates `Cargo.lock` while keeping `Cargo.toml` focused on direct dependencies.

3. **Last resort only** — if a direct dependency pins an old vulnerable transitive and cannot be upgraded, a `[patch]` section in `Cargo.toml` can override the resolution:

   ```toml
   [patch.crates-io]
   vulnerable-crate = "<fixed-version>"
   ```

   Per the override policy above, this requires PR documentation explaining why steps 1 and 2 failed.

### Other ecosystems

If none of the above apply, inspect the scan results for the package type and apply the idiomatic fix. Most modern package managers follow the same pattern:

- Update direct dependencies in the manifest file
- Use a targeted update command for transitive dependencies
- Avoid adding transitive deps to the manifest unless absolutely necessary

---

## Phase 4: Validate

Discover the repository's quality checks by reading `CLAUDE.md`, `README.md`, `Makefile`, `pyproject.toml`, and `package.json`. Then run all applicable checks:

1. **Linting** — e.g. `uv run ruff check`, `npm run lint`, `eslint`, `go vet ./...`
2. **Type checking** — e.g. `uv run mypy`, `npx tsc --noEmit`, `pyright`
3. **Unit tests** — e.g. `uv run pytest`, `npm test`, `go test ./...`
4. **Build checks** — e.g. `npm run build`, CDK synthesis, Docker builds if applicable

Linting, type checking, and build checks are independent and can be run **in parallel** (one tool call per category) to reduce wall-clock time. Tests should run last since they are the most likely to surface regressions that affect interpretation of the other checks.

**Common issues after upgrades:**

- **Type stubs compatibility**: if mypy reports type errors after a framework upgrade (e.g. Flask 2.x → 3.x), check if type stubs or third-party stubs need updates. Sometimes the framework's typing becomes stricter.
- **Companion upgrades**: some packages have peer dependency requirements. For example, upgrading `werkzeug` may require upgrading Flask to a compatible version.
- **Decorator syntax**: if type checkers complain about decorators, try using the called form `decorator()` instead of bare `decorator`.

If a version bump causes test or type-check failures:

- Attempt to fix the breakage (usually minor import or API changes, or type annotations).
- If a major version upgrade causes widespread breakage that cannot be easily fixed, **revert that single upgrade** and note it as a known remaining issue for the PR description.

Re-run the grype scan after all remediations to confirm findings are resolved:

```bash
grype dir:. --only-fixed -o table -q 2>&1
```

---

## Phase 5: Ship

### 1. Stage changed files explicitly

Stage only the files this remediation touched. Do NOT use `git add -A` — it risks staging build artifacts, IDE files, or scratch work unrelated to the vulnerability fixes.

Enumerate based on what was modified in Phase 3 and Phase 4. Typical candidates:

```bash
# Manifests and lock files (only those that exist and changed)
git add pyproject.toml uv.lock
git add requirements.in requirements.txt
git add package.json package-lock.json
git add go.mod go.sum
git add Gemfile Gemfile.lock
git add Cargo.toml Cargo.lock

# Any code files modified during Phase 3 (e.g. to absorb a breaking change)
git add <specific files touched>
```

Run `git status` after staging to confirm nothing unrelated is included.

### 2. Commit with conventional format

```bash
git commit -m "chore(<TICKET-KEY>): vulnerability remediation"
```

If pre-commit hooks fail, fix the issues and create a NEW commit (do not amend).

### 3. Push

```bash
git push -u origin HEAD
```

### 4. Open or update the PR

First, check whether a PR already exists for this branch:

```bash
gh pr list --head <TICKET-KEY> --state all --json url,number,state,isDraft
```

Then branch on the result:

#### 4a. No PR exists — create a new draft PR

Check for a repository PR template first:

```bash
[ -f .github/PULL_REQUEST_TEMPLATE.md ] && cat .github/PULL_REQUEST_TEMPLATE.md
```

If a template exists, use its structure for the PR body and fill in vuln-specific content (CVE list, override docs, verification checklist) into the appropriate sections.

If no template exists, use the default HEREDOC below:

```bash
gh pr create --draft \
  --title "chore(<TICKET-KEY>): vulnerability remediation" \
  --body "$(cat <<'EOF'
## Summary

Remediate dependency vulnerabilities identified by grype.

### Changes
<list each package upgraded: name, old version -> new version, CVE(s) resolved>

### Overrides applied
<for each manifest override added (npm overrides, uv constraint-dependencies, go replace, cargo [patch], Gemfile pins for transitives): the override, the transitive package, why steps 1 and 2 of the override policy failed, and what condition would let it be removed. Note 'None' if no overrides were needed.>

### Verification
- [ ] grype re-scan shows no remaining findings with available fixes
- [ ] Linting passes
- [ ] Type checking passes
- [ ] Unit tests pass

### Known issues
<any vulns that could not be resolved without major breaking changes, or note 'None'>
EOF
)"
```

#### 4b. An OPEN PR exists — update it in place

The push in step 3 has already refreshed the PR's diff. **Do NOT overwrite the existing PR body** — the user may have customized it. Instead:

1. Print the existing PR URL, number, and draft/ready state.
2. Tell the user the PR now contains the latest remediation commits.
3. Recommend `/torch:pr-refresh-summary` if they want the PR body regenerated to reflect the cumulative changes.

#### 4c. A CLOSED or MERGED PR exists

Stop and ask the user how to proceed. Do not silently create a new PR for the same ticket key. Options to offer:

- Reopen the existing PR (`gh pr reopen <number>`) if it was closed without merging.
- Use a new ticket / branch name if the closed PR represents a different remediation cycle.

### 5. Output the PR URL

Display the PR URL (newly created or pre-existing) so the user can review it.

---

## Troubleshooting

### UV workspace issues

If `uv sync` doesn't install all workspace packages:

- Use `uv sync --all-groups --all-packages` to sync all workspace members.
- The `--all-packages` flag is required for workspaces with multiple packages.

### Pre-commit hook failures

If hooks fail with import errors (e.g. `ModuleNotFoundError`):

- Check if the repo uses namespace packages (e.g. `shared/` at repo root shadowing `packages/torch-shared/shared`).
- Set `PYTHONPATH` before committing: `PYTHONPATH=packages/torch-shared git commit ...`
- Or configure the hook to set `PYTHONPATH` internally.

### Non-fast-forward push rejections

If `git push` fails with "non-fast-forward":

- The remote branch may have received updates (e.g. auto-merge from main).
- Rebase and retry: `git pull --rebase origin <branch> && git push`.

### Pre-push hook timeouts

Pre-push hooks often run full test suites. If they take too long:

- Be patient (they may take 60-90 seconds for comprehensive validation).
- Monitor the terminal output file to see progress.
- The hooks validate: linting, type checking, tests, and builds.

---

## Self-improvement

If you encounter architectures, package managers, or tooling not addressed above, propose updates to this command for future reuse. Mention the gap in the PR description or as a follow-up note to the user.
