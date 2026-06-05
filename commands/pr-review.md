---
name: torch:pr-review
description: "AI-powered PR review with inline GitHub review comments (pending, never submitted)"
argument-hint: "<pr-number> [review-aspects]"
---

# AI-Powered PR Review with Inline GitHub Comments

Run a comprehensive pull request review using specialized agents, then post findings as **pending** inline review comments on the PR via the GitHub API.

**Arguments:** "$ARGUMENTS"

Parse the arguments: the **first argument** is the **PR number** (required). Any remaining arguments are optional review aspects.

---

## CRITICAL RULES

1. **NEVER submit the review.** Leave it as a PENDING review so the user can inspect, edit, or discard comments before submitting. Do NOT call the "submit review" API endpoint. Do NOT use `gh pr review --approve/--comment/--request-changes`. Do NOT pass `event: "APPROVE"` or `event: "COMMENT"` or `event: "REQUEST_CHANGES"` to the API. The review MUST remain PENDING.
2. **All comments MUST be prefixed** with `[🤖 Claude]` so they are clearly identified as AI-generated.
3. **Use `gh pr diff` for the diff** — never `git diff`. This ensures accurate file paths, line numbers, and exclusion of merge commits.
4. **NEVER touch git working tree.** Do not checkout to the PR branch, do not make changes in the git working tree.
5. **NEVER duplicate an existing finding.** Before posting any comment, check it against all existing non-resolved comments (including from `gemini-code-assist` and other human reviewers). If the same issue is already raised, do NOT post a duplicate.

---

## Review Workflow

### Step 1: Get PR Info and Diff

Use the PR number from the arguments.

```bash
# Get PR metadata using the provided PR number
gh pr view <PR_NUMBER> --json number,headRefOid,baseRefOid,headRefName,baseRefName,url

# Get the accurate diff (excludes merge commits, correct line numbers)
gh pr diff <PR_NUMBER>
```

Extract:

- `PR_NUMBER` — from the first argument
- `HEAD_SHA` — the head commit SHA (needed for review API: `commit_id`)
- `OWNER_REPO` — from `gh repo view --json nameWithOwner --jq '.nameWithOwner'` (e.g. `everwise/torch`)
- `OWNER` and `REPO` — the two halves of `OWNER_REPO`, split on `/`
- Changed file paths and diff hunks

### Step 2: Gather Existing Review Comments

Before running any review, pull **all existing non-resolved comments** on the PR and keep them in context for the entire review. These are used both for deduplication (Step 5) and for responding to `gemini-code-assist` (Step 8).

```bash
# Inline review comments (file/line-anchored), with resolution status via GraphQL
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            isResolved
            isOutdated
            comments(first: 50) {
              nodes { author { login } body path line diffHunk url }
            }
          }
        }
      }
    }
  }' -F owner="${OWNER}" -F repo="${REPO}" -F pr="${PR_NUMBER}"

# Issue-level (general) comments — includes gemini-code-assist summary comments
gh api "repos/${OWNER_REPO}/issues/${PR_NUMBER}/comments" \
  --jq '.[] | {author: .user.login, body: .body, url: .html_url}'
```

Build two in-memory lists:

- **Existing findings** — every comment from a `reviewThread` where `isResolved == false`, plus relevant issue-level comments. Record author, file, line, and the gist of each. Use this to deduplicate your own findings.
- **Unresolved gemini comments** — comments authored by `gemini-code-assist` (or `gemini-code-assist[bot]`) in any thread where `isResolved == false`. Capture each comment's thread, body, file, line, and `url` for Step 8.

### Step 3: Determine Review Scope

Parse `$ARGUMENTS` to decide which review aspects to run:

- **comments** — Analyze code comment accuracy and maintainability
- **tests** — Review test coverage quality and completeness
- **errors** — Check error handling for silent failures
- **types** — Analyze type design and invariants (if new types added)
- **code** — General code review for project guidelines
- **simplify** — Simplify code for clarity and maintainability
- **all** — Run all applicable reviews (default)

Based on changed files, determine which reviews apply:

- **Always applicable**: code-reviewer (general quality)
- **If test files changed**: pr-test-analyzer
- **If comments/docs added**: comment-analyzer
- **If error handling changed**: silent-failure-hunter
- **If types added/modified**: type-design-analyzer
- **After passing review**: code-simplifier

### Step 4: Launch Review Agents

Provide each agent with the **full `gh pr diff` output** so findings reference accurate file paths and line numbers. Also provide the **Existing findings** list from Step 2 and instruct each agent to skip anything already raised by another reviewer.

Launch agents sequentially by default, or in parallel if the user requests it.

Each agent should return findings in this structured format:

```
FILE: <path>
LINE: <line number in the diff's new file>
SEVERITY: critical | important | suggestion
FINDING: <description>
```

### Step 5: Deduplicate Findings Against Existing Comments

Before posting anything, compare every agent finding against the **Existing findings** list from Step 2.

For each finding, decide:

- **Already raised** (same issue, same location, by any reviewer including `gemini-code-assist`) → **drop it.** Do not post. Track it for the "Already Covered" summary section.
- **Net-new** → keep for posting in Step 7.

Match on substance, not exact wording — a finding at a nearby line describing the same root cause counts as a duplicate.

### Step 6: Check for Existing Pending Review

Before creating comments, check if the current user already has a pending review on this PR:

```bash
# Get current GitHub username
GH_USER=$(gh api user --jq '.login')

# List pending reviews by this user
gh api "repos/${OWNER_REPO}/pulls/${PR_NUMBER}/reviews" \
  --jq ".[] | select(.user.login == \"${GH_USER}\" and .state == \"PENDING\") | .id"
```

- **If a pending review exists**: reuse its `review_id` for adding comments.
- **If no pending review**: create one with `event: "PENDING"` (see Step 7).

### Step 7: Post Inline Comments

For each finding, post an inline review comment on the specific file and line.

**To create a new pending review (no existing one found):**

```bash
gh api "repos/${OWNER_REPO}/pulls/${PR_NUMBER}/reviews" \
  --method POST \
  -f commit_id="${HEAD_SHA}" \
  -f event="PENDING" \
  -f body=""
```

Save the returned `id` as `REVIEW_ID`, then add comments to it.

**To add a comment to the pending review:**

```bash
gh api "repos/${OWNER_REPO}/pulls/${PR_NUMBER}/reviews/${REVIEW_ID}/comments" \
  --method POST \
  -f body="[🤖 Claude] <finding description>" \
  -f path="<file_path>" \
  -f line=<line_number> \
  -f side="RIGHT" \
  -f commit_id="${HEAD_SHA}"
```

**If posting a comment to a multi-line block**, use `start_line` and `line` together:

```bash
  -f start_line=<start> \
  -f line=<end> \
  -f start_side="RIGHT" \
  -f side="RIGHT"
```

**Important**: The `line` number must correspond to a line within a diff hunk. If a finding references a line not in the diff, attach it to the nearest changed line in that file, or skip it and include it in the summary instead.

### Step 8: Respond to Unresolved Gemini Comments

For each **unresolved gemini comment** captured in Step 2, evaluate its finding against the code and decide one of three actions:

| Verdict | Action |
|---------|--------|
| **Agree, nothing to add** | Do NOT respond. Leave the comment as-is. |
| **Agree, but have additional insight** | Reply to the thread with the added insight only — do not restate gemini's point. |
| **Disagree** | Reply to the thread stating why, with specific reasoning or code references. |

Replies go to the existing thread (they are NOT part of the pending review — they post immediately), and must be prefixed with `[🤖 Claude]`:

```bash
# Reply to a gemini review-comment thread (use the comment ID of the gemini comment)
gh api "repos/${OWNER_REPO}/pulls/${PR_NUMBER}/comments/${GEMINI_COMMENT_ID}/replies" \
  --method POST \
  -f body="[🤖 Claude] <agreement insight or disagreement reasoning>"
```

Do not resolve or dismiss any thread — leave resolution to the user.

### Step 9: Print Summary

After posting all comments, print a summary to the terminal:

```
# PR Review Summary

**PR:** #<number> — <url>
**Review Status:** PENDING (not submitted — review and submit manually)
**Comments Posted:** <count>

## Critical Issues (<count>)
- [agent-name] file:line — description

## Important Issues (<count>)
- [agent-name] file:line — description

## Suggestions (<count>)
- [agent-name] file:line — description

## Findings Not Posted (outside diff range): (<count>)
- [agent-name] file:line — description

## Already Covered by Other Reviewers (<count>)
- [reviewer] file:line — description (skipped to avoid duplication)

## Gemini Comment Responses (<count>)
- file:line — AGREED (silent) | AGREED + insight | DISAGREED — short note

## Strengths
- What's well-done in this PR

⚠️  Review is PENDING. Go to the PR to review comments and submit:
<pr_url>
```

---

## Usage Examples

**Full review (default):**

```
/torch:pr-review 123
```

**Specific aspects:**

```
/torch:pr-review 123 tests errors
/torch:pr-review 123 comments
/torch:pr-review 123 code
```

**Parallel review:**

```
/torch:pr-review 123 all parallel
```

---

## Agent Descriptions

**comment-analyzer**:

- Verifies comment accuracy vs code
- Identifies comment rot
- Checks documentation completeness

**pr-test-analyzer**:

- Reviews behavioral test coverage
- Identifies critical gaps
- Evaluates test quality

**silent-failure-hunter**:

- Finds silent failures
- Reviews catch blocks
- Checks error logging

**type-design-analyzer**:

- Analyzes type encapsulation
- Reviews invariant expression
- Rates type design quality

**code-reviewer**:

- Checks CLAUDE.md compliance
- Detects bugs and issues
- Reviews general code quality

**code-simplifier**:

- Simplifies complex code
- Improves clarity and readability
- Applies project standards
- Preserves functionality

---

## Tips

- **PENDING reviews are drafts**: You can view, edit, and delete individual comments in the GitHub UI before submitting
- **Re-run safely**: If you re-run, it will reuse the existing pending review to avoid duplicates
- **Line number accuracy**: `gh pr diff` is the source of truth for line numbers — never use `git diff` which can diverge when merge commits are present
- **The review is NEVER submitted automatically** — you must go to GitHub and submit it yourself
