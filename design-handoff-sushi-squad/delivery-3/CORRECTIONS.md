# Corrections — `design/sushi-squad-brand`

Reviewed at commit range `master...design/sushi-squad-brand`, 22 files.

**The structure is right.** The `SliverAppBar.medium` survived with all four
actions, the Scout Match closure is verbatim, `BrandEventBar` / `BrandActionBar` /
`SyncSquare` / `MascotPlate` are all wired correctly, `_RatingRow` uses squares,
`displayRun` is used on the timer, and no form or schema was touched. Don't redo
any of that.

What drifted is detail-level, and it is the **same four mistakes repeated 20
times**. Every fix below is a deletion or a one-token change. Do them
mechanically; none of them require judgement.

---

## 1. Nothing in this brand is bold — 11 places

The Initiative sets everything at 400: *"Nothing is bold. Hierarchy comes from
size and from the blank line under a heading."* Worse, **Sushi Sans is a
single-weight face**, so `FontWeight.bold` and `w600` don't select a bolder cut —
Flutter *synthesises* one by smearing the outline. Every heading in the app is
currently a slightly blurred, thickened version of the real letterforms. This is
the single biggest visual difference from the reference.

**Delete every one of these lines.** Don't replace them with `w400`; just remove
the argument so the theme's weight applies.

`dashboard.dart`
- `_MatchCard` match-number badge → `fontWeight: FontWeight.bold,`
- `_MatchCard` title → `?.copyWith(fontWeight: FontWeight.w600)` → `?.copyWith()` or drop the `copyWith` entirely
- `_MatchCard` alliance pill → `fontWeight: FontWeight.w600,`

`match_details.dart`
- `FlexibleSpaceBar.title` → `fontWeight: FontWeight.bold,`
- `M${match.matchNumber}` badge → `fontWeight: FontWeight.bold,`
- alliance pill → `fontWeight: FontWeight.w600,`
- robot-died warning → `fontWeight: FontWeight.bold,`
- `_SectionCard` title → `fontWeight: FontWeight.w600,`
- `_DataRow` value → `?.copyWith(fontWeight: FontWeight.w600)`

`match_timer.dart`
- phase label → `fontWeight: FontWeight.bold,`

For `_DataRow`'s value, the label/value distinction should come from **colour**,
which it already does — the label is `onSurfaceVariant`, the value is
`onSurface`. That is sufficient contrast; the weight was redundant even before
the face made it harmful.

## 2. A raw `TextStyle` loses the brand font entirely — `match_details.dart`

```dart
// current — no font family, so this renders in the DEFAULT font, not Sushi Sans
title: Text(
  "Team ${match.teamNumber}",
  style: TextStyle(
    color: AppTheme.onChrome(brand),
    fontWeight: FontWeight.bold,
  ),
),
```

A bare `TextStyle` inherits no family. The collapsing team name — the largest
piece of type on the screen — is currently set in Roboto. Replace with:

```dart
title: Text(
  "Team ${match.teamNumber}",
  style: AppTheme.display(brand, size: 24, color: AppTheme.onChrome(brand)),
),
```

Audit for others: any `style: TextStyle(` that isn't `theme.textTheme.*` or
`AppTheme.*` is suspect. `login_screen.dart` has two legitimate ones
(`TextStyle(color: colorScheme.surface)` on the two `TextFormField`s) — those are
fine, since the field's own text style comes from `inputDecorationTheme`.

## 3. Stray radii — 3 places

`--ss-radius` is `0`; there are no rounded corners anywhere in this brand.

`match_timer.dart`, phase label:
```dart
borderRadius: BorderRadius.circular(AppTheme.spacingSm),   // = 8. spacing, not radius
```
→ delete the `borderRadius:` line.

`dashboard.dart`, `_MatchCard` alliance pill:
```dart
borderRadius: BorderRadius.circular(4),
```
→ delete.

`match_timer.dart`, timer display `BoxDecoration` — the whole decoration is now
`borderRadius: BorderRadius.circular(AppTheme.cardRadius)` on a container with no
fill and no border, i.e. it does nothing. Delete the `decoration:` argument.

Note `AppTheme.spacingSm` was used *as a radius*. `AppTheme.cardRadius` and
`buttonRadius` are the radius tokens and both are `0` — never pass a spacing
token to `BorderRadius`.

## 4. The alpha wash is back — `match_timer.dart`

```dart
color: containerColor.withValues(alpha: 0.5),
```

This is exactly the pattern the Initiative rules out: an accent tinted down over
a surface. `_getPhaseContainerColor` returns `tertiaryContainer` (lilac) and
`primaryContainer` (ink), so at 50% the bar is a washed pink or a mid-grey — a
mid-tone ground, which the brand never uses (*"Pages are either white-on-black or
black-on-white — never a mid-tone ground"*).

Replace the whole `Container` decoration with a plain surface and the rule:

```dart
decoration: BoxDecoration(
  color: colorScheme.surface,
  border: Border(
    bottom: BorderSide(color: colorScheme.outline, width: AppTheme.ruleWidth),
  ),
),
```

Then delete `_getPhaseContainerColor` entirely — it has no other caller. The
phase colour already reads from the chip fill and the progress bar, which is
accent-as-highlight, correctly.

Same file: the border is `width: 1`. Use `AppTheme.ruleWidth`.

## 5. Hardcoded `Colors.white` — 2 places

`dashboard.dart` alliance pill and `match_details.dart` match badge both use
`color: Colors.white` for text on an alliance fill. Both alliance colours are
brand-adjacent but the token is what should be read:

```dart
color: brand.paper,
```

Both files already have `brand` in scope.

## 6. `?` has no glyph — dialog titles lose it

Measured against the shipped TTF, `?` draws **0 ink pixels** (control: `a` =
1327). `dialogTheme.titleTextStyle` is the display face, so:

```dart
title: const Text('Sign Out?'),   // renders "Sign Out" + a blank
```

in `dashboard.dart`'s sign-out confirmation. Two options — either is fine:

```dart
title: const Text('Sign out'),                                    // simplest
// or
title: Text.rich(AppTheme.displayRun(brand, ['Sign out'], separator: '')),
```

Prefer the first. A dialog title doesn't need the question mark, and the brand's
voice is declarative anyway.

**Good news on the middot:** `•` (U+2022) *does* draw (340px). Using `\u2022`
instead of `·` (U+00B7, 0px) in `_MatchCard`'s title was the right call — keep it.
The `|` in the summary string is also 0px, but that string is `bodyMedium` →
Mohave, so it renders. Don't move either into the display face.

The full missing set, measured: `· / - ' " + : ; , ? < >` — none of these were
ever drawn (confirmed against `SushiSquad7461/sushi-sans`, whose `symbols/`
folder contains only `! # $ % & ( ) @ ^ *`). Worth opening an issue on that repo
for the twelve; drawing them deletes this whole class of workaround.

## 7. Lower-priority, verify visually

- `match_details.dart` `_SectionCard` uses `Divider(height: AppTheme.spacingLg)`.
  `height` is the *space* the divider occupies, not its thickness — the thickness
  comes from `dividerTheme` (2px). That's correct, just non-obvious; leave it.
- `_SectionCard` icons use `colorScheme.primary`, which maps to `onSurface`. Fine.
- Casing: section titles are `"Autonomous"`, `"Teleop"`, `"Shooting Range"`. The
  Initiative sets headings lowercase. This is cosmetic and consistent, so it's
  your call — but if you change it, change all of them, and leave `FRC`/`FTC`
  uppercase.

---

## Verify after

```
flutter analyze && flutter test
```

Then look at three things on device: a match card's title should be crisp rather
than slightly thickened; the match-details header team name should be in Sushi
Sans, not Roboto; and the timer bar should be white (or black in dark mode) with
a hard rule, not a pink wash.
