# Corrections, round 2 — from the device screenshots

Reviewed against the running app on `design/sushi-squad-brand` @ `c42eb1b`.

Four things, in order of how much they change the result. **#1 is a font fix that
needs no code changes at all and repairs the slashes everywhere, including in the
form files nobody is allowed to edit.**

---

## 1. Slashes, colons, commas — fixed in the font, not in the code

Replace `assets/fonts/SushiSans-Regular.ttf` with the patched copy in
`dart/assets/fonts/SushiSans-Regular.ttf`. Nothing else. No Dart change, no copy
change, no `displayRun` calls needed.

**What was wrong.** Sushi Sans maps these codepoints to *real glyph slots whose
outlines are empty*. Neither Flutter nor a browser falls back for a glyph that
exists-but-is-blank, so it draws nothing and leaves the advance width — a gap.
`Robot Died / Disabled` rendered as `Robot Died  Disabled`, and `3/5` as `3 5`.

**It was much wider than the twelve characters we'd found.** Reading the font's
`loca` table directly — a glyph is empty when `loca[n] == loca[n+1]` — turns up
**181** mapped-but-blank glyphs, the whole of Latin-1 among them:

```
" ' + , - / : ; < = > ? [ \ ] _ ` { | } ~ · °
¡ ¢ £ ¤ ¥ § © « » ¿ × ÷ ¼ ½ ¾
À Á Â Ã Ä Å Æ Ç È É Ê Ë Ì Í Î Ï Ñ Ò Ó Ô Õ Ö Ø Ù Ú Û Ü Ý
à á â ã ä å æ ç è é ê ë ì í î ï ñ ò ó ô õ ö ø ù ú û ü ý ÿ   (+ C0/C1 controls)
```

So **any scout whose name carries an accent** — José, Muñoz, Chloé — currently
has letters silently missing from every heading in the app. That is the part
worth caring about more than the slashes.

**The fix.** The patched font has those codepoints removed from its `cmap`. A
codepoint that is *absent* falls back normally — which is exactly why `•` (U+2022)
has been rendering correctly all along: it was never in the font's `cmap` at all.
So the app's existing `fontFamilyFallback: ['Poppins']` now picks up every one of
them automatically.

Verified before shipping: every glyph Sushi Sans actually draws is byte-identical
(`a` 1327 ink px, `Q` 1779, `0` 1484, `&` 1536 — unchanged); all 23 spot-checked
blanks now render via fallback; the space glyph stays blank. The original is kept
as `SushiSans-Regular-original-unpatched.ttf` if you ever need to diff.

**`AppTheme.displayRun()` is now redundant.** It still works, so nothing breaks —
but new code shouldn't need it, and the `MatchTimer` correction below drops its
use in favour of a plain `'$minutes:$seconds'`. Keep the helper for one release in
case you revert the font, then delete it.

**Please still file the glyphs upstream** on `SushiSquad7461/sushi-sans` —
`symbols/` only contains `! # $ % & ( ) @ ^ *`. Drawing the punctuation and the
accents in Sushi Sans itself is the real fix; this patch only makes the fallback
work.

## 2. Light mode is broken because the timer paints from the wrong pair

**Cause.** Both forms mount the timer as `AppBar(bottom: MatchTimer(...))`, so it
renders *inside* the app bar. The app bar is chrome — ink in **both**
brightnesses, which is the right call and `AppTheme.chrome()` implements it. But
`MatchTimer` paints itself from `colorScheme.surface` / `onSurface`:

- **light mode:** `surface` is white → a white slab wedged inside the black app
  bar, with black content, directly under a white-on-black title;
- **the empty black chip in the screenshot:** the chip's fill is
  `_getPhaseColor()`, which returns `colorScheme.onSurface` for TELEOP — black in
  light mode — while its label is hardcoded `brand.ink`, also black. Black on
  black. The same bug makes ENDGAME's `#c10000` fill carry a black label at
  2.2:1.

**Fix.** Replace `widgets/match_timer.dart` with the corrected copy in
`dart/lib/presentation/widgets/match_timer.dart`. Every timer behaviour is
unchanged — durations, phase thresholds, controller, haptics, `onMatchFinished`.
What changed:

- background `AppTheme.chrome(brand)`, rule and time readout
  `AppTheme.onChrome(brand)`, reset icon `AppTheme.mutedOnChrome(brand)`;
- TELEOP's phase colour is `onChrome` rather than `onSurface`;
- the chip label is derived from its fill by luminance, so it can never collide;
- the progress line and the play icon step up to paper when the phase fill is too
  dark to read on ink (ENDGAME), while the chip keeps the true phase colour.

**It needs two small additions to `theme/app_theme.dart`** — add these beside
`mutedOnChrome`:

```dart
/// Text or icon colour that reads on an arbitrary [fill].
static Color onFill(TeamBrand brand, Color fill) =>
    fill.computeLuminance() > 0.42 ? brand.ink : brand.paper;

/// [candidate] if it reads against [background], otherwise [fallback].
/// For thin lines and icons, where a dark accent on ink disappears.
static Color legibleOn(Color background, Color candidate, Color fallback) {
  final bg = background.computeLuminance();
  final fg = candidate.computeLuminance();
  final ratio = (max(bg, fg) + 0.05) / (min(bg, fg) + 0.05);
  return ratio >= 3.0 ? candidate : fallback;
}
```

with `import 'dart:math';` at the top of the file.

**Then audit for the same mistake elsewhere.** Anything rendered inside chrome
must use the chrome pair. Grep for `colorScheme.surface` and `onSurface` inside
`BrandAppBar`, `BrandEventBar`, `BrandActionBar` and the `match_details.dart`
`FlexibleSpaceBar`, and check each against light mode. The rule: **if it sits on
the app bar or the action bar, it is chrome; if it sits on the page, it is
surface.**

Also worth knowing: the phone in the screenshots is running a ColorOS-style
"force dark on all apps" setting, which inverts light-themed apps at the
compositor. Once light mode is coherent, re-test with that OS setting off before
chasing anything that still looks odd.

## 3. The wizard's counter card is fine — the page just opens mid-card

The Teleop screenshot shows a card containing only `step − 10 +`. That white line
above `step` is the card's internal `Divider`, not its top edge: the label and the
`[− value +]` row are scrolled off above. `CounterCard` is intact and correct.

Two real things on that screen, both small:

- **Section headings are centre-aligned** (`Mobility`, `Shooting Range`). The
  Initiative's headings sit at the left margin. Add
  `crossAxisAlignment: CrossAxisAlignment.start` — or wrap in `Align` — wherever
  the form emits a section heading. This is a form file, so it is your call
  whether it counts as "recolour only"; I'd take it, since it's alignment rather
  than structure.
- **`step`'s value can reach 10 while the counter's max step is 10** — fine, just
  confirm 3-digit values still fit the 80dp slot at step 10 (`999`).

## 4. FTC never opens — and this one is not a rebrand bug

`dashboard.dart:403`:

```dart
if (event.programType != programType) {
  ref.read(settingsProvider.notifier).setProgramType(event.programType);
}
```

The Firestore event document wins over the scout's setting. `2026TEST` was
created as an FRC event, so selecting **FTC** in settings is overwritten on the
next Scout Match tap and `FrcRebuiltForm` opens every time. `FtcDecodeForm`
itself is wired correctly — it is simply never reached.

This is pre-existing behaviour from `master`, not something the rebrand
introduced, and it is a product decision rather than a design one. Three options:

1. **Create a separate FTC event** (`2026TESTFTC` with `programType: 'FTC'`) and
   switch events. No code change; correct if one event really is one program.
2. **Let the setting win for a new event** — drop the override and pass the
   scout's `programType` into the dummy `Event` in the `event == null` branch.
3. **Make it visible** — keep Firestore authoritative but show the event's program
   as read-only text in settings instead of an editable `SegmentedButton`, so the
   control can't lie about what will happen.

I'd do 3 plus 1: the segmented control currently promises something it can't
deliver, which is the actual bug. Tell me which you want and I'll write it.

---

## Verify after

```
flutter pub get && dart format lib && flutter analyze && flutter test
```

By hand: put a slash in a checkbox title and confirm it renders; type an accented
scouter name and confirm no gaps; switch Appearance to **Light** and check the
timer band is ink with a readable phase chip on every phase (let it run past 0:30
for ENDGAME); confirm a form still saves `gameData` byte-identically.
