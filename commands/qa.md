---
name: torch:qa
description: Functionally QA a Jira work item in a live Torch environment — gather authoritative context, build a structured test plan, confirm it, then drive browser testing with screenshot proof
argument-hint: "[TICKET-ID] [env: local|dev|staging|prod]"
---

# Torch QA

Act as a Quality Assurance engineer: functionally test a Jira work item against the live Torch app. Resolve the ticket and environment, author a structured TEST PLAN, confirm it with the user, then drive the browser via the chrome-devtools MCP, capturing screenshot proof and tracking results as you go.

**One ticket → one artifact, many environments.** Each run targets a single environment, but results accumulate in **one** `plan.json` + `report.html` per ticket. Re-run on the next environment as the ticket promotes (dev → staging → prod); the new env's results are **added** to the same artifact without disturbing the others. Only environments actually tested appear in the report.

## Usage

```
/torch:qa APL-1234 dev          # Test APL-1234 on dev
/torch:qa APL-1234 staging      # Later: add staging results to the same artifact
/torch:qa APL-1234              # Infer environment from ticket status / fixVersion
/torch:qa                       # Infer ticket from current git branch, env from ticket
```

This command runs **interactively in the main thread** — it confirms the plan with you, asks before any database change, asks which account(s) to use on prod, and asks when the environment is ambiguous. It delegates only the read-only context-gathering and plan drafting to the `torch-qa` subagent (to keep context clean); all interaction and browser testing happen here.

## Instructions

### 1. Resolve the ticket

- If a ticket key (`[A-Z]+-[0-9]+`) was passed as an argument, use it.
- Else extract it from the current git branch: `git rev-parse --abbrev-ref HEAD` and match `[A-Z]+-[0-9]+`.
- If still none, ask the user for a ticket key. Do not guess.

### 2. Resolve the environment

If an environment was passed as an argument, use it. Otherwise fetch the ticket and infer:

```bash
acli jira workitem view <TICKET_ID>
```

Apply these rules, in order:

- **fixVersion shape (strongest signal):**
  - `v<YYYY>.<##>` (e.g. `v2026.11`) → regular release → **dev**
  - `v<YYYY>.<##>.<#>` (e.g. `v2026.11.1`) → hotfix → **staging**
- **Status (when fixVersion is absent or ambiguous):**
  - `In Progress` / `In Development` → **local**
  - `Ready for QA` / `In QA` → **dev**

If the signals conflict, are missing, or you are otherwise unsure, **ask the user** with `AskUserQuestion` (options: local, dev, staging, prod). Do not silently pick. (Each run tests one env; you can run again later for the next env in the promotion path.)

Map environment → app URL:
- `local` → `https://app.local.torch.dev`
- `dev` / `sandbox` / `staging` → `https://app.<env>.torch.io`
- `prod` → `https://app.torch.io`

State the resolved ticket + environment + app URL back to the user before proceeding. If `~/d/qa-test-results/<TICKET_ID>/plan.json` already exists (the ticket was tested on another env before), say so — this run **adds** the resolved env to that existing artifact.

### 3. Gather context and draft the test plan (delegate to `torch-qa`)

Spawn the `torch-qa` agent (Agent tool, `subagent_type: torch-qa`) in **research mode** with a prompt like:

```
Research mode. Author/extend the TEST PLAN for <TICKET_ID> targeting the <env> environment
(app URL <appUrl>). Do not drive the browser, do not touch any database, do not ask
questions. Follow the source-of-truth hierarchy in your definition: the ticket's
acceptance criteria / testing notes (or, for a Bug, the repro steps + expected behavior)
are authoritative; help.torch.io is second; archipelago code is third (treat the ticket's
own changed code as untrusted); recent Jira is weakly trusted.

ADDITIVE: if ~/d/qa-test-results/<TICKET_ID>/plan.json already exists, LOAD it and add <env>
additively — keep every existing case definition and id verbatim, append <env> to envsTested,
add environments.<env>, and add a results.<env> entry to each applicable case. Never disturb
other envs' results.

Per the multi-env schema in your definition: case definition (steps/expected/preconditions)
and validationQueries are CASE-LEVEL (shared across envs — author queries once). Put the
specific real testAccounts for <env> under results.<env>.testAccounts (role, email, tenant,
purpose), preferring existing accounts so a human can reproduce. If <env> is prod, do NOT
guess accounts — set them to a "provided by user at runtime" placeholder and flag it. Set
e2eCandidate judiciously (happy-path / critical → yes; silly edge case or heavy DB setup → no)
with a one-line rationale; fill e2eRecommendations.

Write the plan to ~/d/qa-test-results/<TICKET_ID>/plan.json. Return a concise brief: scope, the
env targeted (and which other envs already have results), cases by category, anything needing
my confirmation before execution (DB setup, prod accounts), cases worth adding to the torch-qa
E2E suite, and the absolute path to plan.json.
```

The agent reads the ticket, help center, and code, then writes/extends `plan.json` and returns a brief.

### 4. Generate the report and confirm the plan

The report is **data-driven from a fixed template** — you never hand-write its HTML/CSS/JS.

- Generate `~/d/qa-test-results/<TICKET_ID>/report.html` by copying `~/.claude/templates/qa-report-template.html` and replacing the `__PLAN_JSON__` placeholder (the `const PLAN = __PLAN_JSON__;` line in the first `<script>`) with the **exact contents of `plan.json`**. That single embedded object drives everything: the multi-env verdict switcher, per-case cards, validation-query modal, and Copy-for-Jira.
  - Easiest reliable method: read the template, read `plan.json`, do a single string replace of `__PLAN_JSON__` with the JSON text, write `report.html`. (It is the only occurrence of that token.)
- **Regenerate, don't hand-edit.** On every update (plan edits during confirmation, and each test result during execution) re-run the same inject-from-template step so `report.html` always matches `plan.json`. Do not patch the HTML by hand and do not invoke `/torch:artifact-design` per update — the template is the canonical design.
- The template already encodes the agreed design (do not re-describe or re-style it): teal header with a connected **environment verdict group** (emoji-only `✅`/`❌`/`🚫` for pass/fail/blocked, text for partial/pending), a sticky **env switcher** that scopes the whole page to one environment, collapsible cards (caret · id · title + per-env emoji mini-badges, no background colors), a bordered no-background meta row (category · priority · E2E candidate), a neutral shared definition (preconditions/steps/expected) with a **case-level** "Validation queries (N)" control opening a near-fullscreen per-query copy modal, the active env's result block (status · accounts · result · screenshots, or skip reason), grey monospace, screenshots as `<img>` (file refs only), and a **"Copy for Jira"** button that copies concise Markdown for the **active** env. Only environments present in `envsTested` render; the switcher is the env selector (no separate dropdown).
- Show the user the agent's brief and the report path, then ask them to **confirm or edit** the plan before any testing runs (free-form review; use `AskUserQuestion` only for a clean confirm/adjust/cancel choice). Apply edits to `plan.json` and regenerate `report.html`.
- If `report.html` already existed from a prior environment's run, regenerating from the merged `plan.json` simply adds this env's column — earlier envs' results are preserved.

### 5. Execute the tests (chrome-devtools MCP, main thread)

**Preflight — require the chrome-devtools MCP.** Before any testing, confirm the chrome-devtools MCP tools (`navigate_page`, `take_snapshot`, `take_screenshot`, `click`, `fill`, `wait_for`, …) are actually available. If they are not, **stop — do not fall back to the Claude-in-Chrome extension** (the `computer` / browser_batch tools). The extension cannot save screenshots to disk (it returns in-memory image refs only), so the artifact's screenshot proof would silently break. Tell the user the chrome-devtools MCP isn't connected and to restart the Claude Code session so it loads (it is registered at user scope as `chrome-devtools`), then re-run. Resume only once the chrome-devtools tools are present.

Once the plan is confirmed, test on the **resolved environment** only, writing results into `results.<env>`. Work through `testCases` in priority order. For each case:

- **On `prod`, confirm the account first.** Production accounts belong to real customers — ask the user which account(s) to use (do not reuse a dev/staging login or guess) and record them in `results.<env>.testAccounts` before logging in.
- Drive the app with the chrome-devtools MCP:
  - `navigate_page` straight to the login URL with **both** `auth_type=email` (forces the username/password form instead of SSO) **and** `email=<test account>` prefilled — e.g. `https://app.dev.torch.io/login?auth_type=email&email=user289108@ewhosts.net` (prod: `https://app.torch.io/login?auth_type=email&email=<account>`). This skips the email-entry screen and lands on the password step. Password `ShopTrafficPlans`, fallback `Test@123`. If no test account is evident on a non-prod env, ask the user.
  - `take_snapshot` to get element `uid`s (prefer snapshot over screenshot for navigation), then `click` / `fill` by `uid`; `wait_for` text on async transitions.
  - Check `list_console_messages` and `list_network_requests` for errors a passing-looking UI might hide.
- **Validate in the database when the UI is not decisive.** Read-only queries are allowed freely in any environment — run `pgpass` for connection details, then `psql` with **no password** (handled by `~/.pgpass`). The case's `validationQueries` are **case-level** (shared across envs) — they were authored once; note env-specific param values in `results.<env>.actual` rather than duplicating queries. (Read queries need no confirmation; DB **writes** still do — see below.)
- **Cases may be intentionally skipped on this env** (e.g. destructive DB/lambda steps on prod): set `results.<env>.status = "skipped"` with a `skipReason`. Skipped ≠ untested.
- **Record the result immediately, per (case, env), before the next case** — do not batch to the end. Set `results.<env>.status` (`pass` / `fail` / `blocked` / `skipped`), fill `results.<env>.actual` and `ranAt`, recompute `environments.<env>.resultSummary` and `verdict`, then regenerate `report.html` from `plan.json` (step 4). Never touch other envs' results. An interrupted run still has every completed case saved.
- Capture screenshot proof where a visual outcome is the evidence (final state, a failure, before/after). Save to `~/d/qa-test-results/<TICKET_ID>/screenshots/<TC-ID>-<env>-<slug>.png` via `take_screenshot { filePath }` and add the path to `results.<env>.screenshots` (the template renders it as `<img>`). **Never inline base64.** One or two decisive frames per case — do not over-screenshot.

**Database changes:** only in `local`/pre-prod, only to set up a scenario, only sparingly, and **only after explicit user confirmation**. Run `pgpass` for connection details; use `psql` with no password (handled by `~/.pgpass`). Make the narrowest change possible and report exactly what changed. (On `prod`, avoid DB writes entirely — prefer read-only validation.)

### 6. Report

- Finalize `environments.<env>.verdict` (`pass` / `fail` / `partial`) for the env just tested and regenerate `report.html`.
- Tell the user: the env tested and its verdict, pass/fail/blocked/skipped counts, any failures with their evidence, the verdicts of any other envs already in the artifact, and any cases the agent flagged for the **torch-qa E2E suite** (with the one-line rationale) — be judicious, surface only genuine candidates.
- Report the absolute paths to `plan.json` and `report.html`, and where screenshots live. If more environments remain (e.g. just finished dev, staging/prod pending), remind the user they can re-run `/torch:qa <TICKET> <next-env>` to add it to the same artifact.
- Offer (do not auto-run) to share the report via `/torch:upload-artifact`.

Link all ticket references as `https://torchio.atlassian.net/browse/<TICKET_ID>`.

## Notes

- The authoritative methodology, source-of-truth hierarchy, and the multi-env `plan.json` schema live in the `torch-qa` agent definition (`~/.claude/agents/torch/torch-qa.md`). This command is the interactive driver around it.
- Subagents cannot interact with the user, so the `torch-qa` agent is used only for read-only research/plan drafting; confirmations, the browser session, prod-account and DB-change approvals stay in the main thread.
- The report is generated from the fixed template `~/.claude/templates/qa-report-template.html` by injecting `plan.json` — it is the canonical design. `/torch:artifact-design` is only for redesigning that template, not for routine report generation.
- One artifact per ticket accumulates results across environments. Test artifacts live under `~/d/qa-test-results/<TICKET_ID>/` (`plan.json`, `report.html`, `screenshots/`).
