---
name: torch:pr
description: Stage, commit, push, and create a GitHub PR with conventional commit format and repo-specific PR template
argument-hint: "[jira-ticket-key]"
---

# Create Pull Request

Create a GitHub pull request from the current feature branch. Handles staging, committing, pushing, and PR creation with conventional commit formatting and the repo's PR template.

## Steps

### 1. Determine context

- Identify the current repository by checking `git remote get-url origin` to get the repo name (e.g., `tasmania`, `torch-ui`, `torch-api`, `gen-ai-service`, etc.)
- Determine the **base branch**:
  - If the repo is `tasmania` or `torch-ui`: use `dev`
  - Otherwise: use `main`
- Get the current branch name with `git branch --show-current`

### 2. Validate branch

- If the current branch IS the base branch, **stop immediately** and tell the user: "Error: You are currently on the base branch (`<branch>`). Please check out a feature branch first."
- Do NOT proceed with any further steps.

### 3. Determine the Jira ticket key

- If a Jira ticket key was provided as an argument, use it.
- Otherwise, attempt to extract it from the branch name (pattern: `[A-Z]+-\d+`, e.g., `APL-4018` from `feature/APL-4018-some-description`).
- If no ticket key can be determined, ask the user for it before proceeding.

### 4. Fetch Jira context

- Use `acli jira workitem view <ticket-key>` to get the ticket title and description for context when writing the commit message and PR description.

### 5. Handle uncommitted changes

Run `git status` and `git diff` (staged + unstaged) to check for working tree changes.

- If there are **uncommitted changes** (staged or unstaged):
  1. Review all changes to understand what was done
  2. Stage all relevant changes with `git add` (be specific about files, avoid adding secrets or unrelated files)
  3. Create a commit following **conventional commit** format with the Jira key as scope:
     - Format: `type(TICKET-KEY): concise description`
     - Examples: `feat(APL-4018): add bulk upload field mapping`, `fix(APL-1234): resolve null pointer in profile sync`
     - Use a HEREDOC for the commit message
  4. If pre-commit hooks fail, fix the issues and create a NEW commit (do not amend)
- If there are **no uncommitted changes**, check if there are commits ahead of the base branch:
  - Run `git log <base>..HEAD --oneline` to see commits on this branch
  - If there are NO commits ahead of the base branch, **stop** and tell the user: "Error: No changes to create a PR from. The current branch has no commits ahead of `<base>`."

### 6. Push to remote

- Push the branch: `git push -u origin <current-branch>`
- If the push fails due to divergence, inform the user and ask how they'd like to proceed rather than force-pushing.

### 7. Read the PR template

- Look for `.github/PULL_REQUEST_TEMPLATE.md` in the current repository root.
- If found, use its structure for the PR body. Fill in all sections based on the changes and Jira context.
- If not found, use a basic format with: ticket reference, summary, and key details.

### 8. Create the pull request

Use `gh pr create` with:

- **Title**: conventional commit format with Jira key as scope
  - Format: `type(TICKET-KEY): concise summary`
  - The type should reflect the nature of changes (feat, fix, refactor, chore, docs, test, etc.)
- **Body**: filled-in PR template
  - Include the bare Jira ticket key (e.g., `APL-4018`) where the template asks for a ticket reference -- do NOT format it as a URL or markdown link
  - Keep the description of changes HIGH LEVEL -- focus on what and why, not specific code changes (unless the code changes are particularly noteworthy)
  - Fill in all template sections appropriately; use "None" for sections that don't apply
- **Base branch**: the determined base branch (`dev` or `main`)

Use a HEREDOC for the PR body to preserve formatting:

```bash
gh pr create --base <base-branch> --title "type(TICKET): summary" --body "$(cat <<'EOF'
...PR body...
EOF
)"
```

### 9. Output the result

- Display the PR URL so the user can review it.
