---
name: information-design
description: |
  Methodology for turning a set of facts into a presentation a reader can use
  — the difference between displaying data and presenting information.
  Covers: finding the hero fact, encoding semantics in structure, when a label
  earns its place, grouping by reader question, weight and color budgets,
  recognition over reading, and designing for sparse data.
  Use when: designing or reviewing a card, detail view, summary panel, row
  layout, ticket, receipt, or any surface that presents one record's fields.
version: 1.0.0
date: 2026-08-21
user-invocable: true
---

# Information Design

A record's fields can be *displayed* — label/value, label/value, uniform
weight, storage order — or *presented*: structured around what the reader is
trying to learn. Both carry the same facts. The first makes the reader do the
work; the second means the designer already did it.

The worked example throughout is a boarding pass. Displayed, it is ten rows:
Seat 22A, PNR XJ4K9L, Airline Singapore Airlines, Flight FX6796, From SIN,
To MXP, Terminal 2, Gate 14B, Boarding 18:45, Status On time. Presented, it
is a headline `SIN → MXP`, an airline logo with the flight number, gate and
terminal grouped under the route, a large boarding time, and one green
"On time". Same ten facts.

## 1. Scope

This skill is about presenting **one record's fields** on a surface a human
reads: cards, detail panels, tickets, rows, summaries.

It does not cover:

- Design tokens, ARIA mechanics, forms, theming → `/ux-design`
- Charts and aggregate data → a data-visualization skill if available
- Responsive layout mechanics → `/css-responsive`

## 2. Find the hero

Every record is *about* something. A boarding pass is about a journey; an
invoice is about an amount owed; a deployment is about a version reaching an
environment. That fact is the hero: largest type, first position, the thing a
glance retrieves without reading anything else.

- If you cannot name the hero, you have not understood the record yet — ask
  what question brings a reader to this surface.
- One hero. Two heroes are zero heroes.
- The hero is usually a *relationship or outcome*, not an identifier:
  `SIN → MXP`, `€1,240 due Mar 3`, `v2.4.1 → production` — not the booking
  reference, the invoice number, or the pipeline id.

## 3. Encode semantics in structure

Where the *shape* of the presentation can say what a label would say, delete
the label:

- `SIN → MXP` — the arrow carries "from" and "to". Two labels deleted, and
  the direction became visible instead of described.
- `Terminal 2 · Gate 14B` under the route — adjacency says "this is where
  you go", no "Location:" heading needed.
- A green value says "good state" before the word is read.

Structure is also what survives translation, skimming, and small screens —
words are read, shapes are seen.

## 4. A label must earn its place

Keep a label only when the value alone is ambiguous:

| Value | Label? | Why |
| --- | --- | --- |
| `MORGAN ARTHUR` | No | Its form says "a person's name" |
| `SIN → MXP` | No | The structure says "route" |
| An airline logo | No | Recognition, not reading |
| `22A` | **Yes** (Seat) | Bare, it could be anything |
| `XJ4K9L` | **Yes** (PNR) | Opaque code |
| `18:45` | **Yes** (Boarding) | A time, but *of what?* |

Two tests before dropping a label:

1. **Form test** — does the value's shape identify it? (`*/15 * * * *` reads
   as cron to its audience; `2GB` reads as a size.)
2. **Audience test** — label-dropping is earned by the reader's fluency, not
   by aesthetics. A frequent flyer knows what a PNR is; a first-time user of
   your tool may not know what `delta` means without its label. When the
   audience is mixed, keep the label but demote it.

Demoted labels are small, secondary-colored, and placed so the value reads
first.

## 5. Group by question, not by schema

The flat list's order is the data model's order. The presented card's order
is the reader's: each cluster answers one question.

Boarding pass clusters: *where am I going?* (route, terminal, gate) —
*when?* (boarding time) — *is anything wrong?* (status) — *bookkeeping*
(seat, PNR, name).

Method: write down the two or three questions that bring a reader to this
surface, sort every field under one of them, and let fields that answer no
question sink to the bottom — or off the surface entirely, onto a detail
view.

## 6. Weight and color budgets

- **Weight follows importance.** Type size and boldness form a scale; a
  field's size is a claim about how much it matters. Uniform sizing claims
  nothing matters, which is false.
- **Color is a budget of one.** Spend it on the single fact that changes and
  gets checked repeatedly — a status, an alert, a deadline. Color spent
  everywhere means nothing anywhere. Pair it with the word (never color
  alone — see `/ux-design` on contrast and color-blindness).
- Identifiers and codes the reader *copies* rather than reads (PNR, SHA,
  ref) render in monospace, quiet but exact.

## 7. Recognition over reading

Symbols the audience already holds beat words they must parse: logos, glyphs
(✈, →), established codes (SIN, MXP), badges. Costs to check first:

- **Assets must exist.** An airline has a logo; your internal tool probably
  does not. A missing-image placeholder is worse than the word.
- **Codes must be the audience's own.** Airport codes work on travelers;
  they would fail on someone booking their first flight.

## 8. Design the sparse state

The displayed list degrades gracefully — a missing field is one fewer row.
The presented card does not: a layout built around a hero looks broken when
the hero is absent. So:

- **Design for the emptiest realistic record**, not the demo record. If the
  hero can be missing, define what takes its place — usually a fallback to
  the flat form, or an invitation to provide the data.
- Never render an empty slot where the layout promises a value; collapse the
  slot instead.
- An invitation beats a wall of dashes: sparse data is a prompt to complete
  the record, and the surface is where the gap is noticed.

## 9. Semantics under the visuals

The presented card must still *be* the flat list underneath: a definition
list, a table, headings — whatever structure a screen reader can walk. The
visual hierarchy is a rendering of the semantic one, never a replacement for
it. Deleting a visible label (§4) does not delete the accessible name — the
structure or an ARIA label still carries it.

## 10. Process

1. Name the reader and the question that brings them here.
2. Pick the hero (§2) — and what replaces it when absent (§8).
3. Sort every field under a reader question (§5); evict the unsorted.
4. Decide each field's label: delete, demote, or keep (§4).
5. Assign the weight scale and spend the one color (§6).
6. Swap words for symbols only where the audience already owns them (§7).
7. Check the sparse state and the screen-reader reading (§8, §9).

## 11. Anti-patterns

| Anti-pattern | Problem | Fix |
| --- | --- | --- |
| Uniform label/value list for everything | Reader does all the work | Find the hero, group by question |
| Two heroes | Neither reads as the point | Demote one |
| Labels on self-evident values | Noise before signal | Form test, then delete |
| Label-less opaque codes | Value could be anything | Keep the label, demoted |
| Color on many fields | No field reads as urgent | One color, one meaning |
| Schema order | Answers nobody's question | Reader-question order |
| Demo-data layouts | Breaks on real sparse records | Design the emptiest state first |
| Logos/icons without assets | Placeholder worse than the word | Use the word |
| Visual hierarchy replacing semantic structure | Screen readers get soup | Structure first, style on top |
