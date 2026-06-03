---
name: torch:qa
description: Functionally QA a Jira work item in a live Torch environment — gather authoritative context, build a structured test plan, confirm it, then drive browser testing with screenshot proof
argument-hint: "[TICKET-ID] [env: local|dev|staging]"
---

# Torch QA

Act as a Quality Assurance engineer: functionally test a Jira work item against the live Torch app. Resolve the ticket and environment, author a structured TEST PLAN, confirm it with the user, then drive the browser via the chrome-devtools MCP, capturing screenshot proof and tracking results as you go.

## Usage

```
/torch:qa APL-1234 dev          # Test APL-1234 on dev
/torch:qa APL-1234              # Infer environment from ticket status / fixVersion
/torch:qa                       # Infer ticket from current git branch, env from ticket
```

This command runs **interactively in the main thread** — it confirms the plan with you, asks before any database change, and asks when the environment is ambiguous. It delegates only the read-only context-gathering and plan drafting to the `torch-qa` subagent (to keep context clean); all interaction and browser testing happen here.

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

If the signals conflict, are missing, or you are otherwise unsure, **ask the user** with `AskUserQuestion` (options: local, dev, staging). Do not silently pick.

Map environment → app URL:
- `local` → `https://app.local.torch.dev`
- `dev` / `sandbox` / `staging` → `https://app.<env>.torch.io`

State the resolved ticket + environment + app URL back to the user before proceeding.

### 3. Gather context and draft the test plan (delegate to `torch-qa`)

Spawn the `torch-qa` agent (Agent tool, `subagent_type: torch-qa`) in **research mode** with a prompt like:

```
Research mode. Author the TEST PLAN for <TICKET_ID> targeting the <env> environment
(app URL <appUrl>). Do not drive the browser, do not touch any database, do not ask
questions. Follow the source-of-truth hierarchy in your definition: the ticket's
acceptance criteria / testing notes (or, for a Bug, the repro steps + expected behavior)
are authoritative; help.torch.io is second; archipelago code is third (treat the ticket's
own changed code as untrusted); recent Jira is weakly trusted.

For each case, pre-author read-only validationQueries where a data check would confirm the
outcome, set e2eCandidate judiciously (happy-path / critical → yes; silly edge case or heavy
DB setup → no) with a one-line rationale and fill the e2eRecommendations rollup, and identify
the specific real testAccounts (role, email, tenant, purpose) the case is tested with —
prefer existing accounts in <env> so a human can log in and reproduce.

Write the plan to ~/d/qa-test-results/<TICKET_ID>/plan.json using the exact schema in your
definition. Return a concise brief: scope, test cases by category, any test-data or DB setup
that needs my confirmation, any cases worth adding to the torch-qa E2E suite, and the absolute
path to plan.json.
```

The agent reads the ticket, help center, and code, then writes `plan.json` and returns a brief.

### 4. Present the plan for confirmation (HTML via artifact-design)

- Generate an HTML view of the plan using the `/torch:artifact-design` skill so it carries the Torch report aesthetic. Source the content from `~/d/qa-test-results/<TICKET_ID>/plan.json`; write the report to `~/d/qa-test-results/<TICKET_ID>/report.html`. Render each test case as a card with id, title, category, priority, **test accounts**, steps, expected outcome, a status badge (all `pending` at this stage), and — when present — its E2E-candidate flag.
- **Consistent full-width layout.** Every top-level section must share the **same width** (one shared container `max-width`, e.g. a single `.section`/`.card` class — no section narrower than the others). Apply the same rule **inside each test case card**: every sub-section (accounts, steps, expected, validation-queries control, result) spans the full width of the card. No half-width or shrink-to-content blocks.
- **Collapsible test case cards.** Each card has a clickable header (id · title · status badge · priority) that expands/collapses the body, so a reviewer can scan all cases quickly then drill in. JavaScript is allowed — use a simple toggle. Default state: collapsed (or expanded for `fail` cases so failures are visible at a glance).
- **Test accounts per case.** Render each case's `testAccounts` as a full-width block inside the card: role, email, tenant, and purpose, formatted so a human can copy a login and reproduce the test manually.
- **Validation queries are interactive (JavaScript is allowed on the report).** When a case has `validationQueries`, render a full-width "Validation queries (N)" control inside the card that is **collapsed by default** so it does not clog the page. Clicking it opens a **near-fullscreen modal** listing each query in a monospace `<pre>` with a per-query **Copy** button (copies that query's SQL to the clipboard) and a label showing its `database` and `purpose`. The modal closes on backdrop click or Esc. Keep this component within the Torch design system (colors, type) per `/torch:artifact-design`.
- Show the user the brief and the report path, then ask them to **confirm or edit** the plan before any testing runs (free-form review; use `AskUserQuestion` only for a clean confirm/adjust/cancel choice). Apply any edits to `plan.json` and regenerate the affected rows in `report.html`.
- This first generation establishes the styled report. **Subsequent updates are in-place `Edit`s** — do not re-run the full `/torch:artifact-design` process on every test case.

### 5. Execute the tests (chrome-devtools MCP, main thread)

Once the plan is confirmed, work through `testCases` in priority order. For each case:

- Drive the app with the chrome-devtools MCP:
  - `navigate_page` to `appUrl`; log in if needed (password `ShopTrafficPlans`, fallback `Test@123`). If no test account is evident, ask the user for one.
  - `take_snapshot` to get element `uid`s (prefer snapshot over screenshot for navigation), then `click` / `fill` by `uid`; `wait_for` text on async transitions.
  - Check `list_console_messages` and `list_network_requests` for errors a passing-looking UI might hide.
- **Validate in the database when the UI is not decisive.** Read-only queries are allowed freely in any environment — run `pgpass` for connection details, then `psql` with **no password** (handled by `~/.pgpass`). Record every query you actually run on the case's `validationQueries` (`database`, `purpose`, exact `query`) so it surfaces in the report's collapsible query modal. (Read queries need no confirmation; DB **writes** still do — see below.)
- Record the result: set the case `status` (`pass` / `fail` / `blocked` / `skipped`), fill `actual`, update `resultSummary`. Update both `plan.json` and `report.html` (including any new validation queries and their collapsible/modal entry).
- Capture screenshot proof where a visual outcome is the evidence (final state, a failure, before/after). Save to `~/d/qa-test-results/<TICKET_ID>/screenshots/<TC-ID>-<slug>.png` via `take_screenshot { filePath }`, add the path to the case's `screenshots`, and reference the file in the HTML (`<img src="screenshots/...">`). **Never inline base64.** One or two decisive frames per case — do not over-screenshot.

**Database changes:** only in `local`/pre-prod, only to set up a scenario, only sparingly, and **only after explicit user confirmation**. Run `pgpass` for connection details; use `psql` with no password (handled by `~/.pgpass`). Make the narrowest change possible and report exactly what changed.

### 6. Report

- Set the final `verdict` in `plan.json` (`pass` / `fail` / `partial`) and finalize `report.html` with the result summary.
- Tell the user: verdict, pass/fail/blocked counts, any failures with their evidence, and any cases the agent flagged as worth adding to the **torch-qa E2E suite** (with the one-line rationale) — be judicious, surface only genuine candidates.
- Report the absolute paths to `plan.json` and `report.html`, and where screenshots live.
- Offer (do not auto-run) to share the report via `/torch:upload-artifact`.

Link all ticket references as `https://torchio.atlassian.net/browse/<TICKET_ID>`.

## Notes

- The authoritative methodology, source-of-truth hierarchy, and the `plan.json` schema live in the `torch-qa` agent definition (`~/.claude/agents/torch/torch-qa.md`). This command is the interactive driver around it.
- Subagents cannot interact with the user, so the `torch-qa` agent is used only for read-only research/plan drafting; confirmations, the browser session, and DB-change approvals stay in the main thread.
- Test artifacts live under `~/d/qa-test-results/<TICKET_ID>/` (`plan.json`, `report.html`, `screenshots/`).
