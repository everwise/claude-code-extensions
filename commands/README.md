# Commands

Custom Claude Code commands for streamlined workflows.

## Available Commands

- **pr** - Stage, commit, push, and create a GitHub PR with conventional commit format and repo-specific PR template
- **pr-refresh-summary** - Refresh PR summary to comprehensively reflect all current changes while preserving template structure
- **pr-review** - AI-powered PR review with inline GitHub review comments
- **pr-gemini-review** - Comment "@gemini-code-assist review" on the current PR
- **artifact-design** - Design or redesign standalone HTML artifacts (reports, dashboards, prototypes) with Torch's internal tooling aesthetic via /impeccable
- **triage** - Investigate a Jira support ticket and generate a polished HTML triage report
- **upload-artifact** - Upload an HTML file to the internal artifacts S3 bucket and return a shareable URL
- **reopen-assessment** - Reopen a 360 assessment for additional feedback

## Usage

Commands are automatically available in Claude Code as `/torch:<command>` when linked:

```bash
ln -sf $(pwd)/commands ~/.claude/commands/torch
```