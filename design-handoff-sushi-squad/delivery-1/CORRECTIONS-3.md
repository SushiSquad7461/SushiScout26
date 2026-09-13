# Round 3 — the FTC fix, and an honest parity review

Reviewed at `design/sushi-squad-brand` @ `c42eb1b`.

---

## Part 1 — Program Type becomes read-only once the event exists

`patches/program_type_readonly.dart` — a new `currentEventProvider`, plus a
`_buildProgramTypeSelector` that replaces the always-editable `SegmentedButton`.

**Apply it as a patch, not a file replacement.** The current
`settings_screen.dart` contains three fixes that must survive (see Part 2).

Behaviour:

- **No event document yet** → the segmented control is live, and the helper reads
  *"No matches yet for 2026TEST — the first one you save creates it as FTC."*
  This is true: `FirestoreRepository._getOrCreateEvent` creates the document from
  the match's own `programType` on first save. **No FTC API, no console.**
- **Event document exists** → a solid ink block showing the event's real program,
  the caption *"set by event 2026TEST"*, and *"An event is one program. To scout
  the other, enter a new event code above."*

So the control now only offers a choice when the choice is real. For your FTC
testing: set Program Type to FTC and Event Code to something unused
(`2026testftc`), and scout a match — the FTC form opens and the event document is
created as FTC.

Load failures resolve to "unlocked" on purpose: a wrong lock would strand a scout
offline with no way to pick their program, while a wrong unlock only means the
existing document wins, which is today's behaviour anyway.

---

## Part 2 — Why the app doesn't match the reference

I diffed all 22 files. The result is not what either of us assumed, and the most
useful part is *which* files diverged.

### The files I shipped as Dart match. The files I described in prose do not.

`login_screen.dart`, `settings_screen.dart`, `color_bar.dart` and
`brand_mascot.dart` came through with my doc comments verbatim — they are
essentially the files I wrote. Within the *same commit*:

| | shipped as Dart | described in prose |
| --- | --- | --- |
| files | login, settings, color_bar, brand_mascot, counter_card, theme | dashboard, match_details, match_timer |
| synthesised bold | none | 10 instances |
| stray radii | none | 3 |
| alpha washes | none | 1 |
| raw `TextStyle` losing the font | none | 1 |

That is a clean controlled experiment, and it answers the question you asked two
turns ago better than my ranked list did: **prose transfers structure and loses
detail, every time.** Not because the agent was careless — because a sentence like
"nothing is bold" doesn't attach to eleven specific call sites, and code does.

**The round-1 corrections in `CORRECTIONS.md` are still unapplied** — the bold,
the radii and the timer's alpha wash are all still on the branch. Applying that
file plus `CORRECTIONS-2.md` closes most of the visible gap on its own. Do that
before judging the parity again.

### Claude Code fixed four real bugs in my code

Credit where it's due, and don't revert any of these:

1. **`ColorBar` painted nothing** in some containers. `Flex` defaults to
   `CrossAxisAlignment.center`, which leaves the cross-axis constraint loose, and
   a childless `ColoredBox` collapses to zero there. It added
   `crossAxisAlignment: CrossAxisAlignment.stretch`. My bug, and it would have
   made the brand's own ownership mark invisible.
2. **The brand-tile row threw during layout.** `CrossAxisAlignment.stretch` inside
   a `SingleChildScrollView` forces an infinite height; everything after that Row
   was left unlaid-out and painted stacked at the top of the screen. It wrapped
   the row in `IntrinsicHeight`. Also my bug, and crash-level.
3. **Save + "Backfill this event" overflowed a phone by ~139px.** It changed the
   `Row` to a `Wrap`. Mine again.
4. **Chrome vs surface.** My `BrandAppBar` and `login_screen` read
   `colorScheme.onSurface` for what is conceptually *chrome* — ink in both
   brightnesses — so both inverted in dark mode. It introduced
   `AppTheme.chrome()` / `onChrome()` / `mutedOnChrome()` and used them
   throughout. That abstraction is better than what I shipped, and my
   `match_timer.dart` correction in round 2 is built on top of it.

### It also implemented something I left out entirely

`BrandSkewField` — the **15° cut**. The design system calls it *"the defining
motif"* and *"the single most recognisable thing about the brand"*: flat fields of
colour rotated 15° and sized to bleed past every edge, so a composition reads as a
diagonal slice rather than a rectangle.

**My reference has no 15° cut anywhere.** That is a real omission on my part, and
it is probably the largest single reason the app doesn't *feel* like the brand
document even where it matches my mockup pixel for pixel.

`BrandSkewField` is currently **defined but never used** — dead code. Wiring it in
is the highest-value visual change still available:

- **sign-in** — behind or above the mascot plate, as the brand book's splash pages
  do;
- **empty state** — a slice under the mascot;
- **section covers** — the settings screen's section heads, lightly.

Not on the dashboard list or the forms: those are dense data surfaces, and the
guide puts the motif on splash-like pages.

### What will never match, and why that's my fault

My reference draws a **custom UI vocabulary the app doesn't use**: bordered field
boxes with notched floating labels, three-cell segmented rows, custom switch
blocks. The app renders Material's `TextField` + `InputDecoration`,
`SegmentedButton` (with icons), and `Switch`.

The spec told Claude Code to *"restyle through `ThemeData` wherever possible"* —
correctly, since that is what keeps the forms untouched and the schema safe. But
my mockup then drew shapes only custom widgets could produce. Those two
instructions contradict, and the agent resolved the contradiction the way I asked
it to: it used Material widgets. So the settings screen and the form fields will
never look like my drawing, and chasing that difference means writing custom
widgets for every input in the app.

My recommendation: **accept the Material vocabulary and treat my reference as
correct for colour, type, geometry, spacing and layout only.** If you want the
custom field treatment, that is a separate, larger piece of work and I'd want to
scope it deliberately rather than have it inferred from a mockup.

---

## Suggested order

1. Apply `CORRECTIONS.md` (round 1) — bold, radii, wash, raw `TextStyle`.
2. Apply `CORRECTIONS-2.md` (round 2) — patched font, `match_timer.dart`, the two
   `AppTheme` helpers.
3. Apply `patches/program_type_readonly.dart` — this round.
4. Then re-compare against the reference. Tell me what still looks wrong and I'll
   write those files as Dart rather than describing them.
5. Optional, my recommendation: wire `BrandSkewField` into sign-in and the empty
   state. Say the word and I'll write both.

## Verify

```
flutter pub get && dart format lib && flutter analyze && flutter test
```

By hand: with `2026TEST` set, Program Type shows a read-only `FRC` block; change
the code to an unused one and the segmented control comes back; pick FTC, scout a
match, confirm `FtcDecodeForm` opens and the event document is created as FTC.
