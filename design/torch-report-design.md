# Torch Report Design Guidelines

Design system for Torch HTML reports. Read this file when generating any HTML report artifact.

**All values below come from the Torch design system. Use them exactly. Do not substitute generic/default values.**

---

## Core Principles

1. **Self-contained** — Every report is a single HTML file. All CSS lives in a `<style>` tag. Zero external resources: no CDN fonts, no external stylesheets, no JavaScript dependencies.
2. **Intentional, not decorative** — Every visual element earns its place. No ornamental gradients, no gratuitous animations, no visual filler.
3. **Data-first** — The content hierarchy serves the reader: summary → insight → detail. Lead with the answer, support with evidence.
4. **Torch-branded** — Reports are Torch artifacts. Use the Torch color palette, Torch type scale, and Torch spacing grid. Do not invent colors, font sizes, or spacing values outside this system.

---

## Color System

**MANDATORY: Use ONLY the Torch brand palette below. Never use pure `#000` or `#fff`. Never invent new colors.**

### Torch Brand Palette

| Name       | Hex       | Usage                                        |
| ---------- | --------- | -------------------------------------------- |
| Gold       | `#F2B61B` | Primary accent, key metrics, highlights      |
| Orange     | `#F14A08` | Secondary accent, CTAs, warm emphasis        |
| Maroon     | `#7A0800` | Brand primary (Torch logo), headings, weight |
| Teal       | `#003744` | Dark backgrounds, contrast sections          |
| Near Black | `#16000D` | Primary text, high-contrast elements         |
| Warm White | `#FFF8F4` | Page background, light surfaces              |
| Mint       | `#DDEFE5` | Success tint, positive indicators            |
| Ice        | `#D3F3F2` | Info tint, secondary highlights              |
| Dark Gold  | `#BF8D0B` | Muted gold for secondary use                 |

### Semantic Mapping

| Role              | Color          | Hex       |
| ----------------- | -------------- | --------- |
| Background        | Warm White     | `#FFF8F4` |
| Surface           | White (tinted) | `#FFFCFA` |
| Text primary      | Near Black     | `#16000D` |
| Text secondary    | —              | `#5A4D49` |
| Accent            | Maroon         | `#7A0800` |
| Accent hover      | Orange         | `#F14A08` |
| Highlight         | Gold           | `#F2B61B` |
| Highlight subtle  | —              | `#FDF3D7` |
| Link              | Maroon         | `#7A0800` |
| Border            | —              | `#E8DDD6` |
| Success           | Mint           | `#DDEFE5` |
| Success text      | —              | `#1A5C38` |
| Warning           | Gold           | `#F2B61B` |
| Warning text      | Dark Gold      | `#BF8D0B` |
| Danger            | Orange         | `#F14A08` |
| Danger text       | Maroon         | `#7A0800` |
| Dark section bg   | Teal           | `#003744` |
| Dark section text | Warm White     | `#FFF8F4` |

### Data Visualization Palette

Accessibility-tested colors for charts, graphs, and categorical data. Sufficient contrast from each other for colorblind-safe data viz.

| Name      | Hex       | Usage                             |
| --------- | --------- | --------------------------------- |
| Maroon    | `#7A0800` | Category 1, primary series        |
| Teal      | `#003744` | Category 2, secondary series      |
| Viz Green | `#3E8B47` | Category 3, positive trends       |
| Viz Teal  | `#5CB8B2` | Category 4, neutral/info series   |
| Viz Gold  | `#BF8D0B` | Category 5, warning/highlight     |
| Orange    | `#F14A08` | Category 6, alert/negative trends |

Use in this order for categorical data. For sequential data (e.g., heat maps), derive lighter/darker shades from a single hue rather than mixing categories.

### Color Strategy: Restrained

Reports default to warm neutrals (Warm White background, Near Black text) with Maroon as primary accent. Gold and Orange used sparingly for data emphasis and status. Teal available for contrast sections (e.g., summary header) but not required. Color conveys meaning, never decoration.

---

## Typography

**MANDATORY: Use the Torch type scale exactly. Do not invent font sizes or line heights.**

Two typefaces from the Torch design system:

- **Gibonic Semibold** — all titles and headings
- **Inter** — body text, captions, data, links

```css
/* Titles / headings — always Gibonic */
font-family: var(--font-heading);
font-weight: 600;

/* Body / data / captions — always Inter */
font-family: var(--font-body);
font-weight: 400;
```

For code or SQL snippets:

```css
font-family: var(--font-mono);
```

Since reports are self-contained HTML (no external fonts), include fallback stacks in CSS custom properties. If Gibonic/Inter are unavailable, system fonts apply gracefully.

### Type Scale (Torch Design System)

**Use these exact sizes. Do not use rem or em for font sizes — use px to match the Torch design system.**

| Token                   | Size | Line height | Font    | Weight         | Usage                            |
| ----------------------- | ---- | ----------- | ------- | -------------- | -------------------------------- |
| Primary Title           | 36px | 48px        | Gibonic | 600 (semibold) | Report title                     |
| Secondary Title         | 24px | 32px        | Gibonic | 600 (semibold) | Major section headings           |
| Tertiary Title          | 20px | 24px        | Gibonic | 600 (semibold) | Subsection headings              |
| Large Text Regular      | 20px | 32px        | Inter   | 400 (regular)  | Summary metric values, lead text |
| Large Text Semibold     | 20px | 32px        | Inter   | 600 (semibold) | Emphasized large text            |
| Primary Text Regular    | 16px | 24px        | Inter   | 400 (regular)  | Body text, table cells           |
| Primary Text Semibold   | 16px | 24px        | Inter   | 600 (semibold) | Bold body text, table headers    |
| Primary Text Link       | 16px | 24px        | Inter   | 400 (regular)  | Inline links (underlined)        |
| Secondary Text Regular  | 14px | 24px        | Inter   | 400 (regular)  | Captions, metadata, small labels |
| Secondary Text Semibold | 14px | 24px        | Inter   | 600 (semibold) | Emphasized captions, tag labels  |
| Secondary Text Link     | 14px | 24px        | Inter   | 400 (regular)  | Small links (underlined)         |

### Typography Rules

- Body text max-width: 65–75ch for readability.
- Vary spacing between sections — not every gap identical. Larger gaps before major sections, tighter within.
- Headings get letter-spacing: -0.01em to -0.02em at larger sizes.
- Links use underline decoration, not color-only differentiation.

---

## Layout

### Page Structure

```
┌─────────────────────────────────────────┐
│  Header: title + generation date        │
├─────────────────────────────────────────┤
│  Summary metrics (if data-heavy)        │
├─────────────────────────────────────────┤
│  Section 1                              │
│  Section 2                              │
│  ...                                    │
└─────────────────────────────────────────┘
```

### Spacing

**MANDATORY: All spacing uses multiples of 4px. Do not use arbitrary rem/em values.**

Grid: `4, 8, 16, 24, 32, 40, 48, 64`

| Context                | Value     |
| ---------------------- | --------- |
| Page padding (desktop) | 32px 40px |
| Page padding (mobile)  | 16px      |
| Between major sections | 48px      |
| Within sections        | 24px      |
| Card padding           | 24px 32px |
| Table cell padding     | 8px 16px  |
| Inline element gap     | 8px       |
| Tight (icon + label)   | 4px       |

### Max Width

Content area: `1100px`, centered. Tables may overflow with horizontal scroll.

---

## Components

All component styles below use Torch design tokens. Do not override with arbitrary values.

### Summary Metrics

For data-heavy reports, lead with 3–5 key metrics in a horizontal row. Each metric:

- Label: Secondary Text Regular (14px/24px, Inter, `--text-secondary`)
- Value: Large Text Regular (20px/32px, Inter, `--near-black` or `--maroon` for emphasis)
- Optional trend indicator using data viz colors

Do NOT use the "hero metric card" anti-pattern (oversized number in a colored box with an icon). Keep metrics compact and scannable.

### Data Tables

```css
table {
  width: 100%;
  border-collapse: collapse;
  font-family: var(--font-body);
  font-size: 14px;
  line-height: 24px;
}

th {
  font-weight: 600;
  text-align: left;
  padding: 8px 16px;
  border-bottom: 2px solid var(--border);
  color: var(--text);
  position: sticky;
  top: 0;
  z-index: 1;
  background: var(--bg);
}

td {
  padding: 8px 16px;
  border-bottom: 1px solid var(--border);
}

tr:nth-child(even) {
  background: var(--bg);
}

tr:hover {
  background: var(--highlight-subtle);
}
```

- Right-align numeric columns.
- Use `font-variant-numeric: tabular-nums` for number columns.
- Wrap tables in a `.table-wrapper` div for horizontal scroll on narrow screens.

### Cards

Use cards to group related content — NOT as identical repeating grid items.

```css
.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 24px 32px;
}
```

Do NOT add left-side colored stripes to cards. Use subtle top borders or background tinting if category distinction is needed.

### Status Indicators

Use small colored dots or pills — not large badges or icons:

```css
.status {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-family: var(--font-body);
  font-size: 14px;
  line-height: 24px;
  font-weight: 600;
}

.status::before {
  content: '';
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: currentColor;
}
```

---

## Anti-Patterns — Do NOT

These patterns signal low-quality, template-driven output. Avoid them:

1. **No side-stripe borders** — colored left borders on cards are a generic template tell.
2. **No gradient text** — never apply gradient fills to text.
3. **No glassmorphism** — no frosted-glass effects, no backdrop-filter on content areas.
4. **No hero-metric template** — avoid oversized single numbers in colored boxes with decorative icons.
5. **No identical card grids** — if you have a grid of cards, vary their content density or layout. Don't stamp out 6 identical boxes.
6. **No decorative icons** — don't add emoji or icon fonts for decoration. If you need an icon, use a simple inline SVG or omit it.
7. **No rainbow status bars** — status/progress should use meaningful colors, not a spectrum.
8. **No modal-first patterns** — reports are static documents, not apps. No modals, popups, or interactive overlays.
9. **No dark patterns** — no fake interactivity (buttons that look clickable but aren't, unless they serve a real purpose like print).
10. **No arbitrary colors** — every color must come from the Torch palette above. No `#333`, no `#f5f5f5`, no `steelblue`.
11. **No arbitrary spacing** — every margin/padding must be a multiple of 4px from the spacing grid.
12. **No arbitrary font sizes** — every font size must come from the Torch type scale.

---

## Responsive

Reports should be readable on screens from 375px to 1440px+.

```css
@media (max-width: 768px) {
  /* Stack metric cards vertically */
  /* Reduce Primary Title to 24px/32px */
  /* Reduce Secondary Title to 20px/24px */
  /* Switch table to horizontal scroll */
  /* Reduce page padding to 16px */
}

@media print {
  /* Remove backgrounds that waste ink */
  /* Ensure tables don't break mid-row */
  /* Show URLs after links */
}
```

---

## Base Template

**MANDATORY: Every report MUST use the base template at `~/.claude/templates/torch-report-template.html` as its structural starting point.**

The template provides:

- Teal header with Torch logo (white SVG), report title, generation date, and internal-use disclaimer
- **Optional** overlapping metrics bar for 3–5 key KPIs (omit when not appropriate — see comments in template)
- Content area with section, table, and progress bar patterns
- All Torch CSS custom properties pre-configured
- Responsive breakpoints for mobile

Read the template file before generating any report. Follow the HTML comments inside it for which sections are required vs optional and how to adjust padding when the metrics bar is omitted.

---

## Required Elements

Every report MUST include:

1. **Title** — clear, descriptive report title (Primary Title token: 36px Gibonic semibold).
2. **Internal-use disclaimer** — "For internal use only, do not distribute" in the header meta line.
3. **Viewport meta** — `<meta name="viewport" content="width=device-width, initial-scale=1">`.
4. **UTF-8 charset** — `<meta charset="utf-8">`.

---

## CSS Custom Properties Template

**Start every report with these variables. Do not modify the values — they are the Torch design system.**

```css
:root {
  /* Torch brand palette */
  --gold: #f2b61b;
  --orange: #f14a08;
  --maroon: #7a0800;
  --teal: #003744;
  --near-black: #16000d;
  --warm-white: #fff8f4;
  --mint: #ddefe5;
  --ice: #d3f3f2;
  --dark-gold: #bf8d0b;

  /* Data visualization */
  --viz-green: #3e8b47;
  --viz-teal: #5cb8b2;

  /* Semantic mapping */
  --bg: #fff8f4;
  --surface: #fffcfa;
  --text: #16000d;
  --text-secondary: #5a4d49;
  --accent: #7a0800;
  --accent-hover: #f14a08;
  --highlight: #f2b61b;
  --highlight-subtle: #fdf3d7;
  --border: #e8ddd6;
  --success: #ddefe5;
  --success-text: #1a5c38;
  --warning: #f2b61b;
  --warning-text: #bf8d0b;
  --danger: #f14a08;
  --danger-text: #7a0800;

  /* Typography */
  --font-heading: 'Gibonic', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  --font-body: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  --font-mono: 'SF Mono', SFMono-Regular, ui-monospace, Menlo, monospace;

  /* Layout */
  --max-width: 1100px;
}
```

---

## AI Slop Test

Before finalizing any report HTML, verify:

- Would a human designer look at this and think "template"? If yes, rethink it.
- Is every color from the Torch palette? If not, fix it.
- Is every font size from the Torch type scale? If not, fix it.
- Is every spacing value a multiple of 4px? If not, fix it.
- Could you remove an element and lose nothing? If yes, remove it.
- Does the layout respond to the actual data shape, or is it a fixed grid regardless of content?
