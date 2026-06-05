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
5. Read the design guidelines (~/.claude/design/triage-report.md) and HTML template (~/.claude/templates/triage-report-template.html)
6. Generate the HTML triage report using the template as structural starting point, following the design guidelines exactly
7. Write the report to ~/d/triage-reports/reports/{TICKET_ID}-triage.html
```

4. Upload the report to S3 for internal sharing via the `torch:upload-artifact` skill:

```
/torch:upload-artifact ~/d/triage-reports/reports/{TICKET_ID}-triage.html triage/{TICKET_ID}-triage.html
```

Do NOT git add, commit, or push the report. The file stays local and is shared via S3 only.

5. Report the file path and the shareable URL returned by the upload skill to the user.

Note: recipients need a @torch.io Google account to access.
