# Sushi Squad rebrand — design handoff archive

Working reference only. **Deliberately not committed** — untracked on purpose.
The code these documents describe is already merged into `master` (PR #6,
merge commit `64a73fe`).

Previously this sat at the repo root as four separate items:
`design_handoff_sushi_squad_rebrand/`, `Sushi Squad branding overhaul2/`,
`Sushi Squad branding overhaul3/`, and a loose `CORRECTIONS.md`.

## What's here

| Folder | Was | Contents |
| --- | --- | --- |
| `delivery-1/` | `design_handoff_sushi_squad_rebrand/` | 21 files. Ships the **unpatched** font. |
| `delivery-2/` | `Sushi Squad branding overhaul2/` | 21 files. Ships the **patched** font. |
| `delivery-3/` | `Sushi Squad branding overhaul3/` | Byte-identical to `delivery-2`. |
| `delivery-1-CORRECTIONS.md.duplicate` | root `CORRECTIONS.md` | Exact duplicate of `delivery-1/CORRECTIONS.md` (same md5). |

Each delivery carries the same 21 files — all three `CORRECTIONS*.md`, `SPEC.md`,
`design-reference.html`, `font-fix-before-after.png`, the `dart/` reference
sources, and `patches/program_type_readonly.dart`. The deliveries differ in
**exactly one file**: `dart/assets/fonts/SushiSans-Regular.ttf`.

## The font, and a correction to the record

| | cmap entries | mapped-but-blank | patched? |
| --- | --- | --- | --- |
| `delivery-1` font (22,404 b) | 256 | 181 | no |
| `delivery-2` / `delivery-3` font (22,672 b) | 75 | 0 | **yes** |
| shipped in `master` (21,564 b) | 75 | 0 | yes |

**PR #6's description says the handoff's "patched" font was not patched. That is
wrong.** It was true only of `delivery-1`, which is what I read; `delivery-2` and
`delivery-3` contain a correctly patched font that I never opened. The reviewer
did deliver the fix.

The font now in `master` was patched independently, and is *functionally
identical* to `delivery-2`'s: same cmap coverage, zero outline or metric
differences across all 75 glyphs, same table set. The byte-size gap is compiler
padding. So nothing in the app needs changing — only the claim about the handoff
was wrong.

`delivery-1`'s font was overwritten in-place during the work and has been
restored from `c42eb1b` (md5 `5aade370…`, 22,404 bytes), so all three deliveries
are again as received.

## Status of the corrections

- **Round 1** (`CORRECTIONS.md`) — was already applied in `57fa022` before this
  work started, contrary to `CORRECTIONS-3.md`'s claim. Verified item by item.
- **Round 2** (`CORRECTIONS-2.md`) — applied. Font, the two `AppTheme` helpers,
  `match_timer.dart`. The chrome audit it asked for found no violations.
- **Round 3** (`CORRECTIONS-3.md`) — applied as a patch, not a file replacement,
  so the three settings layout fixes survived. `BrandSkewField` wired into
  sign-in and the dashboard empty state.

One bug found on device that no round caught: `BrandSkewField` reserved its
height and painted nothing, because a childless `ColoredBox` collapses to zero
width under a `Column`'s default cross-axis alignment — the same trap already
fixed in `ColorBar` directly above it.

## Still open upstream

`SushiSquad7461/sushi-sans` has only `! # $ % & ( ) @ ^ *` in `symbols/`.
Drawing the missing punctuation and the Latin-1 accents there is the real fix;
the cmap patch only makes fallback work. Once that lands, revert the patch and
delete `AppTheme.displayRun` / `displayMissingGlyphs`, which are deprecated and
already have zero call sites.
