# Claude Code Extensions

Specialized agents and commands for Claude Code that enhance development workflows through targeted expertise, orchestrated collaboration, and custom utilities.

## Prerequisites

### Required
- Claude Code CLI

### Optional (by feature)
- **[acli](https://developer.atlassian.com/cloud/acli/guides/install-acli/)** - for Jira workflows (`jira-workitem-implementer`, `jira-workitem-analyzer`)
- **[gh CLI](https://cli.github.com/)** - for GitHub operations (PR creation, issue management)
- **[Firecrawl API key](https://firecrawl.dev)** - for web scraping (`meta-agent`)

## Installation

```bash
# Clone the repository
git clone https://github.com/everwise/claude-code-extensions.git
cd claude-code-extensions

# Create Claude Code directories
mkdir -p ~/.claude/{agents,commands}

# Symlink agents and commands
ln -sf $(pwd)/agents ~/.claude/agents/torch
ln -sf $(pwd)/commands ~/.claude/commands/torch

# Verify
ls ~/.claude/agents/torch/
ls ~/.claude/commands/torch/
```

### 2. Setup Optional Dependencies

**For Firecrawl (meta-agent)**
```bash
claude mcp add firecrawl -e FIRECRAWL_API_KEY=fc-<YOUR_KEY> -- npx -y firecrawl-mcp
```

## Agent Architecture

The agents follow a hierarchical structure with orchestrational agents coordinating specialized capabilities:

```
├── ORCHESTRATIONAL AGENTS (workflow coordinators)
│   ├── feature-architect → 3-phase development planning
│   ├── jira-workitem-implementer → ticket to PR automation  
│   ├── pr-review-comment-resolver → systematic PR feedback
│   └── iterative-quality-fixer → quality gate enforcement
│
└── SPECIALIZED AGENTS (focused expertise)
    ├── debugger → error troubleshooting
    ├── code-quality-reviewer → production readiness
    ├── tdd-test-writer → test-driven development
    └── 7 other specialized agents
```

## Commands

Custom commands available as `/torch:<command>`:

- **pr** → Stage, commit, push, and create a GitHub PR
- **pr-refresh-summary** → Refresh PR summary to reflect all current changes
- **pr-review** → AI-powered PR review with inline GitHub comments
- **pr-gemini-review** → Trigger Gemini code review on current PR
- **triage** → Investigate a Jira support ticket and generate HTML triage report
- **upload-artifact** → Upload HTML to S3 artifacts bucket with shareable URL
- **reopen-assessment** → Reopen a 360 assessment for additional feedback

## Quick Reference

### Complex Development
- **New features/bugs**: `feature-architect`
- **Jira tickets**: `jira-workitem-implementer` 
- **Quality issues**: `iterative-quality-fixer`

### Code Review & Quality
- **PR feedback**: `pr-review-comment-resolver`
- **Code review**: `code-quality-reviewer`
- **Test creation**: `tdd-test-writer`

### Troubleshooting
- **Errors/failures**: `debugger`
- **Comment cleanup**: `pr-comment-validator`

## Documentation

📖 **[Complete documentation and usage guidelines →](agents/README.md)**

Individual agent specifications are in the `agents/` directory.