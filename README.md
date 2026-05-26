# Claude Code Extensions

Specialized agents and custom commands for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that enhance development workflows with targeted expertise, orchestrated collaboration, and automation.

## Installation

### Quick Install

```bash
git clone https://github.com/everwise/claude-code-extensions.git
cd claude-code-extensions
./install.sh
```

### Manual Install

```bash
git clone https://github.com/everwise/claude-code-extensions.git
cd claude-code-extensions

# Create Claude Code directories
mkdir -p ~/.claude/agents ~/.claude/commands

# Symlink agents and commands
ln -sf "$(pwd)/agents" ~/.claude/agents/torch
ln -sf "$(pwd)/commands" ~/.claude/commands/torch

# Verify
ls ~/.claude/agents/torch/
ls ~/.claude/commands/torch/
```

### Uninstall

```bash
cd claude-code-extensions
./install.sh --uninstall
```

## Prerequisites

### Required
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)

### Optional (by feature)
| Dependency | Used by | Install |
|---|---|---|
| [gh CLI](https://cli.github.com/) | PR commands, pr-comment-validator | `brew install gh` |
| [acli](https://developer.atlassian.com/cloud/acli/guides/install-acli/) | jira-workitem-implementer, jira-workitem-analyzer, triage | See Atlassian docs |
| [Firecrawl API key](https://firecrawl.dev) | meta-agent (web scraping) | `claude mcp add firecrawl -e FIRECRAWL_API_KEY=fc-<KEY> -- npx -y firecrawl-mcp` |

## Agents

### Orchestrators (multi-step workflow coordinators)

| Agent | Purpose | Delegates to |
|---|---|---|
| **feature-architect** | 3-phase development: explore, plan, implement | tdd-test-writer, debugger, code-quality-reviewer |
| **jira-workitem-implementer** | Jira ticket to PR, end-to-end | jira-workitem-analyzer, feature-architect, tdd-test-writer, iterative-quality-fixer |
| **pr-review-comment-resolver** | Systematic PR feedback resolution | iterative-quality-fixer |
| **iterative-quality-fixer** | Fix-test-verify cycles until gates pass | debugger, code-quality-reviewer |
| **meta-agent** | Generate new agent configurations from descriptions | — |

### Specialized agents

| Agent | Purpose |
|---|---|
| **debugger** | Root cause analysis for errors and test failures |
| **code-quality-reviewer** | Objective, production-focused code review |
| **tdd-test-writer** | Test-driven development — tests before implementation |
| **test-validator** | Validate tests cover behavior, not implementation details |
| **code-comment-reviewer** | Detect hamburger comments, verify accuracy |
| **pr-comment-validator** | Identify outdated PR comments after code changes |
| **jira-workitem-analyzer** | Extract implementation requirements from Jira tickets |
| **information-consolidator** | Consolidate scattered info into structured format |
| **datadog-log-searcher** | Query DataDog Logs API v2 with time filtering |
| **triage** | Investigate support tickets, generate HTML triage reports |
| **agent-efficiency-optimizer** | Optimize agent configurations for clarity |

### Agent chaining examples

```
Ticket to PR:
  jira-workitem-implementer → feature-architect → tdd-test-writer → PR

Quality pipeline:
  debugger → iterative-quality-fixer → code-quality-reviewer → gates pass

PR review cycle:
  pr-review-comment-resolver → iterative-quality-fixer → pr-comment-validator → clean PR
```

## Commands

Available as `/torch:<command>` in Claude Code:

| Command | Description |
|---|---|
| **pr** | Stage, commit, push, create GitHub PR with conventional commits |
| **pr-refresh-summary** | Refresh PR body to reflect all current changes |
| **pr-review** | AI-powered PR review with inline GitHub comments |
| **pr-gemini-review** | Trigger Gemini code review on current PR |
| **vuln-remediation** | Remediate dependency vulnerabilities via upgrades + draft PR |
| **triage** | Investigate Jira support ticket, generate HTML triage report |
| **upload-artifact** | Upload HTML to S3 artifacts bucket with shareable URL |
| **reopen-assessment** | Reopen a 360 assessment for additional feedback |

## Quick Reference

| Task | What to use |
|---|---|
| New feature or complex bug | `feature-architect` |
| Implement a Jira ticket | `jira-workitem-implementer` |
| Create a PR | `/torch:pr` |
| Review code quality | `code-quality-reviewer` |
| Fix linting/test failures | `iterative-quality-fixer` |
| Debug errors | `debugger` |
| Write tests first | `tdd-test-writer` |
| Address PR review comments | `pr-review-comment-resolver` |
| Create a new agent | `meta-agent` |
| Investigate support ticket | `/torch:triage` |
| Fix vulnerable dependencies | `/torch:vuln-remediation` |

## Documentation

Full agent documentation with usage examples: [agents/README.mdx](agents/README.mdx)

Command documentation: [commands/README.md](commands/README.md)
