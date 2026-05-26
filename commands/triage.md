---
name: torch:triage
description: Investigate a Jira support ticket and generate a polished HTML triage report
argument-hint: "<TICKET-ID>"
---

# Triage Report Generator

Investigate a Jira support ticket, query databases, read source code, trace root cause, and generate a polished HTML triage report.

## Usage

```
/torch:triage TORCH-19647
```

## Instructions

When this skill is invoked:

1. Extract the ticket ID from the argument (e.g., `TORCH-19647`)
2. If no ticket ID provided, ask for one
3. Spawn the `triage` agent (defined in `~/.claude/agents/triage.md`) using the Agent tool with this prompt:

```
Triage ticket {TICKET_ID}.

Investigate the issue end-to-end:
1. Fetch the Jira ticket with: acli jira workitem view {TICKET_ID}
2. Identify affected services from the ticket description
3. Query databases (run pgpass first for connection details)
4. Read source code to trace behavior
5. Generate the HTML triage report following the design system in your instructions
6. Write the report to ~/d/triage-reports/reports/{TICKET_ID}-triage.html
```

4. After the agent completes, determine the report path from its output. Run `/impeccable` on the generated HTML file to polish the design. Pass it this context:

```
Redesign {REPORT_PATH}

This is a bug triage report. Product register (internal tooling).

Design requirements:
- Light theme only, OKLCH colors, no hex
- System font stack (-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui)
- Monospace for IDs, emails, code values ("SF Mono", "Fira Code", "Cascadia Code")
- NO side-stripe borders (border-left/right as accent), NO gradient text, NO glassmorphism, NO em dashes
- Max width 920px, responsive at 680px, print styles

Required elements:
- Header: ticket ID as colored pill, h1 title, meta line (type, assignee, date)
- Verdict banner: amber background, one-paragraph root cause summary at top
- Stat cards: 3-4 key metrics when applicable (grid, large monospace values, semantic color classes: .critical/.ok/.warn)
- KV grids: structured entity details as two-column definition lists on surface-1 background
- Data tables: uppercase small-caps headers, hover rows, status pills (pill-yes/pill-no/pill-pending/pill-neutral), .row-highlight for anomalous rows, .mono class for IDs/emails
- Config callout spans: monospace red-soft background for unusual/changed config values
- Root cause block: surface-1 with border, narrative paragraphs
- Code blocks: when tracing source bugs, with .hl-pass (green), .hl-fail (red), .hl-dim (gray) highlight classes
- Numbered action items: CSS counter with accent-colored circle numbers
- Footer: generated date + key identifiers

Keep all content and data from the investigation. Only redesign the visual presentation.
```

5. After impeccable completes, git add, commit, and push:

```bash
cd ~/d/triage-reports && git add reports/{TICKET_ID}-triage.html && git commit -m "{TICKET_ID}: triage report" && git push
```

6. Upload the report to S3 for internal sharing:

```bash
aws s3 cp ~/d/triage-reports/reports/{TICKET_ID}-triage.html s3://torch-internal-artifacts/triage/{TICKET_ID}-triage.html --content-type "text/html" --profile torch-cognito
```

7. Report the file path, git push status, and shareable URL to the user:

```
https://d6k0bi38kbaeg.cloudfront.net/triage/{TICKET_ID}-triage.html
```

Note: recipients need a @torch.io Google account to access.
