# Design Brief — Google Calendar Event Creator

## Direction
A calm, focused single-purpose tool. Emerald/jade primary on a warm-neutral field; one centered card, generous whitespace, no clutter. Premium utility, not a dashboard.

## Tone
Quiet, competent, trustworthy. The UI stays out of the way while the user supplies credentials and event details. Success feels earned, not celebrated.

## Differentiation
Most calendar tools are heavy dashboards. This is a single decision: create one event. The card is the whole app. No history, no lists, no chrome beyond the essential form.

## Color Palette (OKLCH)
| Token | Light | Dark | Role |
|---|---|---|---|
| background | 0.98 0.008 165 | 0.145 0.014 165 | page field |
| foreground | 0.15 0.015 165 | 0.95 0.01 165 | body text |
| card | 1.0 0.004 165 | 0.18 0.014 165 | elevated surface |
| primary | 0.42 0.14 165 | 0.72 0.15 165 | emerald — CTAs, focus |
| primary-foreground | 0.98 0.005 165 | 0.145 0.014 165 | text on primary |
| accent | 0.7 0.15 75 | 0.75 0.15 75 | warm gold — sparing highlights |
| muted | 0.95 0.01 165 | 0.22 0.02 165 | secondary surfaces |
| muted-foreground | 0.5 0.012 165 | 0.55 0.01 165 | helper text |
| border | 0.9 0.008 165 | 0.28 0.02 165 | hairlines |
| ring | 0.42 0.14 165 | 0.72 0.15 165 | focus ring |
| success | 0.6 0.16 150 | 0.7 0.16 150 | created-event state |
| destructive | 0.55 0.22 25 | 0.65 0.19 22 | error state |

## Typography
- Display: Space Grotesk — headings, app title, result headline. Tight tracking (-0.02em).
- Body: DM Sans — form labels, inputs, helper text, buttons. 100–1000 weight range.
- Mono: system monospace — token/ID display only.

## Elevation & Depth
- `shadow-subtle`: card resting state — soft 1–3px haze.
- `shadow-elevated`: card on hover / focus-within — 10–30px lift.
- `shadow-xs`: inputs at rest.
- Borders are hairline OKLCH, not shadows, for structure.

## Structural Zones
| Zone | Purpose | Treatment |
|---|---|---|
| Page header | App title + one-line description | Centered, display font, top of viewport |
| Card surface | The form (Client ID, access token, title, start, end) | Centered, max-w-md, shadow-subtle → elevated on focus |
| Action row | Primary CTA "Create event" | Full-width primary, gradient hover |
| Result state | Success/error display | Replaces form in-place; success uses --success, fade-in |

## Spacing & Rhythm
- Card padding: 1.75rem (28px). Field gap: 1.25rem. Label-to-input: 0.5rem.
- Page vertical centering: min-h-screen + flex. Card max-width: 28rem.
- 0.625rem radius scale (lg/md/sm) — soft, not pill, not square.

## Component Patterns
- Input: bg-card, border, radius-md, focus ring 2px primary, no inner shadow.
- Button primary: bg-primary text-primary-foreground, radius-md, hover lifts to gradient.
- Result panel: bg-muted/40, border-success/30, success icon, event link.
- Error panel: border-destructive/30, destructive text, retry CTA.

## Motion
- `fade-in` 0.4s cubic-bezier(0.4,0,0.2,1): result panel entrance, card mount.
- `transition-smooth` 0.3s: hover/focus state changes on inputs and buttons.
- No looping, no parallax, no decorative animation.

## Constraints
- No history view, no event list, no persisted events. Single form → single result.
- User supplies own Google Client ID + access token (manual entry, no OAuth flow).
- Event fields limited to: title, start time, end time. Nothing else.
- Must use googlecalendar-client mops package; no built-in calendar component.
- Light/dark theme via `.dark` class on root — no JS theme toggle required in scope.

## Signature Detail
The success result: a single emerald hairline-bordered panel, fade-in, with the event title set in Space Grotesk and a quiet "Open in Google Calendar" link. No confetti, no toast — the panel is the celebration.
