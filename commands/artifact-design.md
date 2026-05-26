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

### 2. Invoke /impeccable with Torch artifact context

Run `/impeccable` with the user's argument, prepending the context block below. This gives impeccable the product register and design constraints for Torch internal tooling artifacts without needing PRODUCT.md.

**Prepend this context to whatever the user passed:**

```
Product context (use as PRODUCT.md equivalent — skip teach if this is present):

Product: Torch internal tooling artifacts — standalone HTML reports, dashboards, and documents generated for internal engineering and support teams
Register: product
Users: Engineers, support staff, team leads, and managers at Torch (a people development SaaS platform)
Brand voice: Direct, information-dense, professional. Prioritize scannability and data clarity over personality.
Strategic principles:
- Data first — every element earns its place with real information, no padding
- Scannability — readers skim reports fast; use visual hierarchy, pills, and stat cards to surface key findings
- Print-friendly — artifacts get shared as PDFs and screenshots in Slack; they must look good printed
- Self-contained — single HTML file, no external dependencies, inline all styles

Anti-references: Generic Bootstrap reports, unstyled HTML dumps, enterprise PDF exports with gray headers

Design constraints:
- Product register (internal tooling)
- Light theme only (artifacts shared in Slack, email, printed)
- System font stack: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif
- Monospace for IDs, emails, code values, config: "SF Mono", "Fira Code", "Cascadia Code", monospace
- OKLCH colors, no hex
- No side-stripe borders (border-left/right as accent), no gradient text, no glassmorphism, no em dashes
- Max width 920px, responsive at 680px, print styles required
- Single-file HTML with all CSS inlined in <style> tag
- Alternate section backgrounds between surface-0 and surface-1 (or equivalent subtle contrast) so each section is visually distinct when scanning

Design system elements (use when appropriate):
- Header: subject ID as colored pill, h1 title, meta line (type, author, date)
- Verdict/summary banner: amber background, one-paragraph key finding at top
- Stat cards: 3-4 key metrics in grid, large monospace values, semantic colors (.critical/.ok/.warn)
- KV grids: two-column definition lists on surface-1 background for entity details
- Data tables: uppercase small-caps headers, hover rows, status pills (pill-yes/pill-no/pill-pending/pill-neutral), .row-highlight for anomalous rows, .mono for IDs/emails
- Config callout spans: monospace red-soft background for unusual values
- Narrative blocks: surface-1 with border, paragraph explanations
- Code blocks: with .hl-pass (green), .hl-fail (red), .hl-dim (gray) highlight classes
- Timeline: horizontal node-and-track for chronological events
- Numbered action items: CSS counter with accent-colored circle numbers
- Footer: generated date + key identifiers
```

### 3. Let /impeccable drive

Once invoked, `/impeccable` owns the flow. It will:

- Skip `teach` (product context provided above)
- Load the `product` register reference
- Load the sub-command reference if one was used
- Execute the design work

### 4. Post-design

After `/impeccable` completes, if it produced or modified an HTML file:

1. Offer to upload via `/torch:upload-artifact` for internal sharing.
2. If the file lives in a git repo, offer to commit and push.

## Notes

- This skill is for standalone artifacts, not Torch platform UI. For platform design work, use `/impeccable` directly in the relevant repo.
- The design language matches what `/torch:triage` produces — triage reports are the canonical reference artifact.
- All design intelligence comes from `/impeccable`. This skill only injects Torch-specific context.
