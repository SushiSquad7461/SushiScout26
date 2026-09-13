# SushiScout 26 — Sushi Squad rebrand: implementation spec

For Claude Code. Flutter, `frontend/`, Dart SDK `^3.10.4`.

**Design intent:** the app was stock Material 3 seeded from one salmon hex, with
`Icons.sports_soccer` standing in as a logo. This replaces that with Team 7461's
actual identity from the Sushi Squad Design Initiative — the "Bubblegum Forest"
palette, Sushi Sans/Poppins + Mohave type, square geometry, the colour bar as
the ownership mark, and the four mascots in place of a logo.

**Hard constraints:**

1. **The scouting forms and the database schema do not change.** No file under
   `screens/frc_rebuilt_form.dart` or `screens/ftc_decode_form.dart` is edited,
   and nothing in this change reads or writes `gameData`, `MatchReport`,
   `toFirestore`/`fromFirestore`, or any Firestore path.
2. **Original functionality is preserved.** Every callback, provider read,
   validator, error path and async guard stays as-is. Where a widget is
   restyled, its behaviour is untouched. Notes below call out the three places
   where a naive swap *would* have deleted functionality.
3. Recolour and retype only, except for two deliberate structural moves that
   were reviewed and approved: the FAB becomes a full-width action bar, and
   settings moves from a bottom sheet to a screen.

---

## 1. Files to add or replace

| Source in this project | Destination | Action |
| --- | --- | --- |
| `flutter/lib/presentation/theme/team_brand.dart` | `lib/presentation/theme/team_brand.dart` | **new** |
| `flutter/lib/presentation/theme/app_theme.dart` | `lib/presentation/theme/app_theme.dart` | **replace** |
| `flutter/lib/presentation/widgets/color_bar.dart` | `lib/presentation/widgets/color_bar.dart` | **new** |
| `flutter/lib/presentation/widgets/brand_mascot.dart` | `lib/presentation/widgets/brand_mascot.dart` | **new** |
| `flutter/lib/presentation/widgets/counter_card.dart` | `lib/presentation/widgets/counter_card.dart` | **replace** |
| `flutter/lib/presentation/screens/auth/login_screen.dart` | `lib/presentation/screens/auth/login_screen.dart` | **replace** |
| `flutter/lib/presentation/screens/settings_screen.dart` | `lib/presentation/screens/settings_screen.dart` | **new** |
| `assets/mascots/{nori,peepo,sparkie,daimler}.svg` | `assets/mascots/` | **new** |
| `assets/fonts/SushiSans-Regular.ttf` | `assets/fonts/` | **new** |

`lib/presentation/widgets/settings_sheet.dart` is superseded by
`settings_screen.dart`. Delete it **after** step 4 updates its one call site.
Everything else is edited in place per §5.

## 2. pubspec.yaml

```yaml
dependencies:
  flutter_svg: ^2.0.17        # ADD — mascots are vector
  google_fonts: ^7.0.0        # already present, no change

flutter:
  assets:
    - assets/fonts/           # already present
    - assets/mascots/         # ADD

  fonts:                      # ADD — Sushi Sans, the team display face
    - family: SushiSans
      fonts:
        - asset: assets/fonts/SushiSans-Regular.ttf
```

One asset, no `weight:` lines. Sushi Sans ships as a single master and the
Initiative sets display type at **400** — "nothing is bold; hierarchy comes from
size and from the blank line under a heading" — so nothing ever asks for a weight
the file doesn't have and the engine never fakes one.

`assets/fonts/Roboto-Regular.ttf` is now unused — Mohave and Poppins both come
from `google_fonts` at runtime. Leave the file; removing it is a separate call.

## 3. main.dart

Four lines in `SushiScoutApp.build`:

```dart
// remove:
final Color seedColor = AppTheme.getSeedColor(colorSeedStr);
// ...
theme: AppTheme.lightTheme(seedColor),
darkTheme: AppTheme.darkTheme(seedColor),

// add:
final brand = AppTheme.brandFor(colorSeedStr);
// ...
theme: AppTheme.light(brand),
darkTheme: AppTheme.dark(brand),
builder: (context, child) => BrandScope(brand: brand, child: child!),
```

Add `import 'presentation/theme/team_brand.dart';`. `themeMode` is untouched —
it still follows the system.

`BrandScope` is an `InheritedWidget` that makes the active brand reachable from
any widget, which is what keeps `CounterCard`'s constructor unchanged. Read it
with `BrandScope.of(context)`.

`colorSeedStr` still comes from `PrefKeys.colorSeed`; `TeamBrands.byId` falls
back to Sushi Squad for the legacy values already on scouts' devices
(`'salmon'`, `'blue'`, `'green'`, `'purple'`, `'orange'`).

## 4. dashboard.dart — surgical edits only

This file is ~700 lines and almost all of it is export, auth, sync and
navigation logic. **Do not rewrite it.** Five edits:

**4a. Do NOT replace the app bar with `BrandAppBar`.** The bar is a
`SliverAppBar.medium` inside a `CustomScrollView`, and it carries
`ConnectionStatusChip`, the search `IconButton`, the export `IconButton` and the
`PopupMenuButton` (trash / settings / sign out). Swapping in a
`PreferredSizeWidget` would delete all four and the collapse behaviour. Keep the
`SliverAppBar.medium` exactly as it is and change only its `bottom:` — replace
the `Chip` in the `PreferredSize` with:

```dart
bottom: BrandEventBar(brand: BrandScope.of(context), eventCode: eventCode),
```

`BrandEventBar` is a `PreferredSizeWidget` of height `40 + 6` that renders the
event code in brand label type and hangs the colour bar off the bottom edge of
the app bar. The `Chip` and its `secondaryContainer` fill go away.

**4b. FAB → full-width action bar.** Move it off `floatingActionButton:` and
onto `bottomNavigationBar:`, passing the **existing async closure verbatim** as
`onPressed` — all of it: the `AppHaptics.medium()`, the `getEvent` timeout, the
`event == null` dummy-`Event` branch, the Firestore-wins `setProgramType`, both
`Navigator.push`es, and the `catch` with its `debugPrint` and SnackBar.

```dart
bottomNavigationBar: BrandActionBar(
  brand: BrandScope.of(context),
  label: 'Scout Match',
  onPressed: () async { /* the existing closure, unchanged */ },
),
```

Then drop the now-dead `ScaleAnimation` wrapper and the
`const SliverPadding(padding: EdgeInsets.only(bottom: 88))` that reserved room
for the FAB. Keep the `import '../../core/animations.dart';` — `AppHaptics` is
still used.

**4c. `_MatchCard` recolour.** Layout unchanged (4dp alliance strip,
`IntrinsicHeight`, 48dp badge, title/summary/scouter column, sync icon):

* the badge's `allianceColor.withValues(alpha: 0.15)` fill + `allianceColor`
  text becomes a solid `colorScheme.onSurface` block with `colorScheme.surface`
  text — an accent tint on a surface is the one thing the Initiative rules out;
* the alliance pill's `withValues(alpha: 0.1)` fill becomes a solid
  `allianceColor` block with white text;
* `color: colorScheme.surfaceContainerLow` → the `Card` theme already supplies
  surface + a 2px rule, so remove the override;
* the sync `Icon` pair (`check_circle_rounded` / `schedule_rounded`) becomes
  `SyncSquare(brand: brand, synced: match.isSynced)`, which keeps the same
  `Tooltip` strings.

Leave `onTap`, `onLongPress`, `_showContextMenu`, `_moveToTrash` and its Undo
SnackBar alone.

**4d. Empty state.** Replace the `BoxShape.circle` container +
`Icons.ramen_dining_rounded` with `MascotPlate(brand: brand, name:
Mascots.daimler, width: double.infinity, height: 260)`. Keep both strings; they
already read in the team's voice.

**4e. Settings call site.** In `_openSettings`:

```dart
void _openSettings(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );
}
```

Swap the `settings_sheet.dart` import for `settings_screen.dart`. The
`PopupMenuButton` case that calls it is unchanged.

## 5. match_details.dart — recolour only

Layout stays exactly as written: the `SliverAppBar.expandedHeight: 200` header,
the match badge, the alliance pill, the scouter row, the FRC/FTC chips and the
`_SectionCard` stack with its left accent strip.

* The header's `allianceColor` background becomes `colorScheme.onSurface`, and
  the badge inside it becomes solid `allianceColor`. Alliance colour reads as the
  badge rather than as a 200dp flood — that was the single biggest source of red.
* The badge's `BoxShape.circle` → square (remove the `shape:`).
* `_RatingRow`'s five `Icons.star` become five 14dp squares, filled to `value`
  and outlined for the remainder, matching `SyncSquare`.
* The `robot_died` warning keeps its `errorContainer` semantics but as a 2px
  `colorScheme.error` outline rather than a filled block.
* `_SectionCard`'s strip stays **4dp** — do not widen it.

Both `_buildFrcSections` and `_buildFtcSections` keep every row. Schema coverage
is tabulated in §8; no label was renamed.

## 6. match_timer.dart — recolour only

Structure unchanged: 4dp `LinearProgressIndicator`, play/pause + reset buttons,
phase chip, `MM:SS` countdown from 2:15, and the `_phaseColor` switch.

`_phaseColor` returns theme colours instead of hardcoded ones — AUTO
`brand.accentHighlight` (french), TELEOP `colorScheme.onSurface`, ENDGAME
`colorScheme.error`. Use that colour for the **phase chip fill** (with
`brand.ink` text on it), not for the countdown text: french on white measures
2.57:1, and the countdown is the one thing a scout reads at a glance in arena
light. Set the `MM:SS` readout in `colorScheme.onSurface`. The chip and the 4dp
progress bar carry the phase colour, which is accent-as-highlight exactly as the
Initiative intends. No timer logic changes.

Remember the glyph trap: the readout is display type and contains a colon, which
Sushi Sans does not draw. Build it with `AppTheme.displayRun(brand, ['02','03'],
separator: ':')`.

## 7. Files that need no edits

* **`frc_rebuilt_form.dart`, `ftc_decode_form.dart`** — the 5-page wizard, the
  page indicator, the field set, the validators and every `gameData` key stay
  as-is. `CounterCard`'s constructor is unchanged and its `brand` argument is
  optional (resolved from `BrandScope`), so the call sites compile untouched.
  The rest of the form is `SegmentedButton`, `SwitchListTile`,
  `CheckboxListTile`, `DropdownButtonFormField`, `Slider`, `Card` and
  `TextFormField`, all of which repaint from `ThemeData`.
* **`trash_screen.dart`, `team_select_screen.dart`, `match_search_delegate.dart`,
  `connection_status.dart`, `team_settings_section.dart`, `auth_wrapper.dart`** —
  theme-only.
* Anything under `data/`, `core/` or `providers/`.

`AppTheme.cardRadius` and `AppTheme.buttonRadius` are now `0`, so every
`BorderRadius.circular(AppTheme.cardRadius)` call site goes square with no edit.
`AppTheme.allianceRed` is now `#C10000` and `allianceBlue` is dodger `#56CBF9`.

## 8. Schema coverage

Every `gameData` key in `MatchReport`, and where match details shows it. Labels
are the ones already in `match_details.dart`.

FRC (`_buildFrcSections`): `auto_fuel` → Fuel Scored, `auto_tower_l1` → Left
Start Line (L1) · `teleop_fuel` → Fuel Scored, `teleop_tower_level` → Climb
Level · `trench_traverse` → Trench Traverse, `bump_traverse` → Bump Traverse ·
`shooting_range_close` / `_mid` / `_far` → Close / Mid / Far Range ·
`defense_rating` → Defense Rating, `driver_skill` → Driver Skill.

FTC (`_buildFtcSections`): `leave` → Leave, `artifacts_auto` → Artifacts,
`indexing_auto` → Indexing · `artifacts_teleop` → Artifacts, `indexing_teleop`
→ Indexing · `base_expansion` → Base Expansion, `driver_quality` → Driver
Quality.

Shared: `robot_died` (the warning block), plus top-level `comments`,
`scouterName`, `alliance`, `matchNumber`, `teamNumber`, `programType`,
`isSynced`.

## 9. Design tokens

Values are the bound **Sushi Squad 7461 Design System** tokens, not
approximations. The HTML mockup loads that system directly — `tokens/*.css` plus
`_ds_bundle.js` — and mounts its `Nori` / `Peepo` / `Sparkie` / `Daimler` and
`WordmarkWash` components rather than redrawing them. Flutter can't consume the
JS bundle, so the Dart mirrors the same token values; the table below is the
mapping, and any change to the design system should be re-checked against it.

Palette "Bubblegum Forest" — black `#000000` and white `#ffffff` are the
primaries and carry the majority of every surface; oyster `#4f4f4f` is the
secondary and the only grey, used for rules, panels and secondary type, never
for large fields; the four accents are arita `#81f4e1`, dodger `#56cbf9`, french
`#ff729f`, lilac `#fcd6f6` and exist **only** to highlight an element or add
brand presence — never as a surface fill. Accents always appear in that order or
its exact reverse; that ordered run *is* the colour bar. Each mascot owns one
accent field: nori→arita, daimler→dodger, sparkie→french, peepo→lilac.

Alliance colours sit outside the brand because red has to read as red in the
stands. Red is `#c10000`, which is `--ss-splash-red` — already in the source, on
the logo splash page — not an invention. Blue is dodger.

| Dart | Token | Value |
| --- | --- | --- |
| `AppTheme.ruleWidth` | `--ss-rule-hairline` | 2.5 |
| `AppTheme.sectionRuleWeight` | `--ss-rule-weight` | 10 |
| `AppTheme.colorBarThickness` | `--ss-colorbar-h` | 10 |
| `AppTheme.skewDegrees` | `--ss-skew` | 15 |
| `AppTheme.cardRadius` / `buttonRadius` | `--ss-radius` | 0 |

**Casing.** Headings and section titles are **lowercase** — the Initiative sets
its own as `about this document`, `color palette`, `logoless`, `clearance`. Body
copy uses sentence capitalisation. Colour names are lowercase. Event codes are
lowercase (`2026casj`), which is how the source writes them and what
`FormValidators.eventCode` already expects.

Two exceptions, both held consistently: the **team name** (`Sushi Squad 7461`,
`SUSHI SQUAD 7461` and `sushi squad 7461` are all sanctioned — pick one and hold
it), and **programme acronyms**, which keep their case. `FRC` and `FTC` are
uppercase everywhere — the guide itself writes `FRC 7461` — so the
`ButtonSegment` labels and the match-details chips both stay caps. Flutter has no
`text-transform`, so this is simply how the literal is written; don't add
`.toUpperCase()` anywhere.

Sign-out stays in the dashboard's `PopupMenuButton`, where the original puts it —
it is deliberately not duplicated into the settings screen.

**Weight and tracking.** Display type is 400. Nothing is bold. Tracking is
default except on the huge washes (`-0.015em`); `--ss-tracking-caption` (0.02em)
is the only small-text tracking value.

**Type.** Sushi Sans (display, bundled) with Poppins as the brand's own declared
secondary; Mohave (body) with IBM Plex Sans Condensed as its secondary. Mohave
Light italic (300) is the document's dominant voice and is what `AppTheme.helper`
returns.

**Geometry.** No rounded corners, no shadows, no cards, no capsules, no blur, no
transparency effects. Flat rectangles separated by solid rules. The only
compositing in the entire source document is `soft-light` on the wordmark wash,
which `MascotPlate` reproduces.

**The 15° cut** is the defining motif: a flat colour field rotated 15° and sized
to bleed past every edge, so the composition reads as a diagonal slice.
`BrandSkewField` implements it. Use it on splash-like surfaces — sign-in, empty
states — and keep it off dense data screens.

**Motion.** The source specifies none. Nothing bounces, fades in, or grows a
shadow. The coherent extension is an instant, hard state change — swap to an
accent fill, invert black/white — with no transition, which is why the theme
sets `NoSplash.splashFactory`. Links are underlined french going to black on
hover, never tint-and-fade.

Team 7461 is deliberately logoless: any of the four mascots may stand in for a
logo, which "supports the team's principles of unity in individualism as opposed
to a stoic, undynamic image". In small form a mascot must be a single colour and
keep a margin of 1/8 its own width; it may be rotated or scaled but never
stretched non-uniformly. `BrandMascot` and `MascotPlate` enforce all of that.
There is no icon system — if you need a UI icon the team hasn't drawn, use a
plain 2.5px-stroke geometric line icon at the weight of the surrounding rules,
and flag the addition rather than drawing a mascot-styled approximation.

## 10. Adding the second team

One `TeamBrand` const and one entry in `TeamBrands.all`. The picker in
`settings_screen.dart` reads that list, so the new team appears with no further
wiring. Nothing hard-codes a Sushi Squad colour — screens read `brand.accents`,
`brand.allianceColor(...)`, `brand.mutedFor(brightness)`.

## 11. Known gaps — read before starting

1. **Sushi Sans is missing punctuation glyphs, and this WILL bite.** Measured on
   canvas at 80px, ink pixels: `a` 1327, `0` 1484 — but `·` `/` `-` `'` `"` `+`
   `:` `;` `,` `?` `<` `>` are all **0**. The face declares an advance width for
   each but carries no outline, and neither the browser nor Flutter falls back
   for a glyph that exists-but-is-empty — they draw nothing and leave a gap. A
   match title set as `Q28 · Team 254` renders `Q28  Team 254`, and a timer set
   as `2:03` renders `203`.

   Never put those characters in the display face. `AppTheme.displayRun(brand,
   parts, separator: ' · ')` builds the line with the words in Sushi Sans and the
   separator in Mohave, which draws all of them. Apply it at every display-face
   call site that mixes words with punctuation — the match card title, the match
   details header, `MatchTimer`'s `MM:SS`, and any `programType · eventCode`
   pairing. `AppTheme.displayMissingGlyphs` holds the measured set.

   Worth asking the team to add the glyphs to the face; that would make this
   whole workaround unnecessary.
2. **`AppTheme.salmonSeed` / `blueSeed` / `greenSeed` / `purpleSeed` /
   `orangeSeed`** are kept as `@Deprecated` constants purely so
   `settings_sheet.dart` still compiles until step 4e deletes it. Remove them
   with that file.
3. **`getSeedColor` / `lightTheme` / `darkTheme`** are kept as `@Deprecated`
   shims for the same reason. `flutter analyze` will emit deprecation infos
   until they're gone.
4. **`secondaryContainer` is lilac, deliberately.** `ConnectionStatusBar` and
   `ConnectionStatusChip` paint themselves from that pair; mapping it to the
   surface colour made the "Uploading N reports…" band invisible white-on-white.
   Don't "fix" it back to a neutral.
5. **Contrast: two rules, both already encoded in `TeamBrand`.**
   * *Muted text follows the surface.* Oyster `#4f4f4f` on white is 8.9:1, but on
     black it is **2.56:1** — below even the 3:1 large-text floor. Always read it
     from `brand.mutedFor(brightness)` / `colorScheme.onSurfaceVariant`, which
     returns oyster on light and `neutralOnInk` `#c4c4c4` (11.0:1 on black) on
     dark. Never hardcode oyster for secondary text.
   * *French is a highlight, not a text colour on light surfaces.* `#ff729f` on
     white is **2.57:1**. It is the system's own `--ss-link` and is fine for
     links and for fills (chips, progress bars, the counter card's top bar,
     focus rings), but anything read at a glance — a timer, a field label, a
     value — goes in `colorScheme.onSurface`.

   Lilac is the same story one step further: fine as a colour-bar segment or a
   plate field, never as text or an icon on a light surface.
6. The counter buttons stay **56dp**. 68dp would suit a 2.5-minute match better,
   but that's a design change to a form and is out of scope here.
7. **Body line-height.** The Initiative sets body copy at line-height **1** in an
   18px column. That is a print measure; at mobile sizes it sets too tight for
   multi-line helper text, so `AppTheme.body`/`helper` use 1.28. Display type is
   at the specified 1. If the team wants literal fidelity here, change the
   `height:` defaults in those two helpers — it's one line each.
8. **The 15° cut is used sparingly** — sign-in and the empty state only. The
   source is a publication where every page can be a composition; a scouting
   form at match pace can't be. If the team wants more of it, section covers
   inside settings are the next place it would fit.

## 12. Verification

```
flutter pub get && dart format lib && flutter analyze && flutter test
```

Then check by hand: dashboard search / export / overflow menu / pull-to-refresh
still work; the connection band is visible when a report is pending; an FRC and
an FTC match report each open in details with every field present; a form saves
and the written `gameData` is byte-identical to before; light and dark both
follow the system setting.
