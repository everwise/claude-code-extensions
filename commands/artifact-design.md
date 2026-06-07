---
name: torch:artifact-design
description: Design or redesign standalone HTML artifacts (triage reports, ad-hoc reports, prototypes) using /impeccable with Torch's internal tooling aesthetic
argument-hint: "[impeccable-command] <file-or-description>"
---

# Torch Artifact Design

Design, redesign, or polish standalone HTML artifacts — triage reports, ad-hoc investigation reports, data exports, internal dashboards, prototypes — using `/impeccable` with Torch's internal tooling design language pre-loaded.

## Usage

```
/torch:artifact-design path/to/report.html                    # Redesign existing artifact
/torch:artifact-design polish path/to/report.html              # Final quality pass
/torch:artifact-design bolder path/to/report.html              # Amplify bland artifact
/torch:artifact-design critique path/to/report.html            # UX review
/torch:artifact-design Create a comparison report for assessment completion rates
```

## Instructions

When this skill is invoked:

### 1. Parse the argument

- If no argument: show `/impeccable` command menu and note Torch artifact context will be auto-injected.
- If argument provided: pass through to `/impeccable` in step 2.

### 2. Load the Torch design system (authoritative source)

**Read these two files first. They are the canonical, mandatory design authority — read them before any design work:**

1. `~/.claude/design/torch-report-design.md` — the Torch report design system: color palette (exact hex), Gibonic/Inter type scale, 4px spacing grid, component patterns, anti-patterns, CSS custom properties, and the AI slop test.
2. `~/.claude/templates/torch-report-template.html` — the base HTML template. **Every artifact uses this as its structural starting point.** Follow the HTML comments inside it for required vs optional sections and how to adjust padding when the metrics bar is omitted.

These files define the non-negotiable rules:

- Exact Torch brand palette (hex, never OKLCH, never `#000`/`#fff`, never invented colors)
- Gibonic Semibold headings, Inter body, exact px type scale
- 4px spacing grid, 1100px max width
- Teal header with Torch logo, internal-use disclaimer
- Self-contained single-file HTML, all CSS inlined, zero external resources

### 3. Invoke /impeccable — Torch design system has precedence

Run `/impeccable` with the user's argument so it drives the craft process (UX review, hierarchy, scannability, copy, polish passes). But the Torch design system is the authority.

**Prepend this context to whatever the user passed:**

```
Design authority: The Torch report design system in ~/.claude/design/torch-report-design.md
and the base template ~/.claude/templates/torch-report-template.html are MANDATORY and
AUTHORITATIVE. Read both before designing. Use the base template as the structural starting point.

Precedence rule: Where /impeccable's defaults conflict with the Torch design system, the
Torch design system WINS. Specifically, the Torch system overrides impeccable on:
- Color: use exact Torch hex palette, NOT OKLCH or any other colors
- Typography: Gibonic headings / Inter body, exact px type scale (not impeccable's font choices)
- Spacing: 4px grid; Layout: 1100px max width
- Structure: the base template (teal header, internal-use disclaimer)

Apply /impeccable rules ONLY where they do not conflict — i.e. for craft and process the
Torch system does not specify: content hierarchy, scannability, visual rhythm, UX copy,
edge/empty states, responsive behavior refinement, accessibility, the slop/quality test,
and overall polish. Sprinkle these in on top of the Torch foundation.

Skip /impeccable's `teach` step — product context is the Torch design system above.

Product: Torch internal tooling artifacts — standalone HTML reports, dashboards, and
documents for internal engineering and support teams.
Register: product. Light theme only. Print- and Slack-friendly.
```

### 4. Let /impeccable drive (within Torch constraints)

Once invoked, `/impeccable` owns the craft flow but stays inside the Torch design system. It will:

- Skip `teach` (Torch design system is the product context)
- Load the sub-command reference if one was used
- Execute the design work using the Torch design system + base template as the foundation, layering impeccable's non-conflicting craft rules on top
- Run the AI slop test from DESIGN.md before finalizing

### 5. Post-design

After `/impeccable` completes, if it produced or modified an HTML file:

1. Offer to upload via `/torch:upload-artifact` for internal sharing.
2. If the file lives in a git repo, offer to commit and push.

## Notes

- This skill is for standalone artifacts, not Torch platform UI. For platform design work, use `/impeccable` directly in the relevant repo.
- The authoritative design language is the Torch report design system at `~/.claude/design/torch-report-design.md` plus the base template `~/.claude/templates/torch-report-template.html`. These override `/impeccable` defaults wherever they conflict.
- `/impeccable` supplies craft and process intelligence (hierarchy, scannability, copy, polish, slop test) layered on top of the Torch foundation — never replacing the Torch palette, type scale, spacing grid, or template structure.
