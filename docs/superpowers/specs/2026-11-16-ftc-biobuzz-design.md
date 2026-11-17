# FTC BIOBUZZ scouting form

Date: 2026-11-16

## Goal

Replace the FTC 2025-26 game (DECODE) with the FTC 2026-27 game (BIOBUZZ).
The change covers the scouting form, the match views, the file exports,
and the Sheets export. The FRC form does not change.

## Game facts

These facts come from the BIOBUZZ Competition Manual, Team Update 09
(2026-11-12).

- A robot launches POLLEN and NECTAR into the HIVE.
- Enough launched elements flip the HIVE. This flip is a HIVE TIP.
- A HIVE TIP scores 20 points in AUTO and 20 points in TELEOP.
- A robot scores a FLOWER through its top opening.
- A robot can remove only POLLEN from a FLOWER, through the bottom
  opening.
- LEAVE scores 3 points in AUTO.
- PARK is binary. The game has no climb and no park levels.
- The POLLINATOR ranking points need 4 tips and 7 tips per alliance.

## Decisions

- The team chose the game metrics to track. The list is in the table
  below.
- "Standard" fields stay as they are. These are the speed ratings, the
  defense rating, the driver rating, the robot-died fields, and the
  comments.
- `leave` stays, because BIOBUZZ has a LEAVE task.
- `park` (bool) replaces `base_expansion` (None / Partial / Full),
  because PARK has no levels.
- The four capability fields are yes/no answers. They do not count
  scored elements.

## `gameData` contract for FTC

| Phase | Key | Type | Label |
|---|---|---|---|
| Auto | `leave` | bool | Leave |
| Auto | `hive_tips_auto` | int | Auto Hive Tips |
| Teleop | `hive_tips_teleop` | int | Teleop Hive Tips |
| Teleop | `flower_score` | bool | Can Score Flowers |
| Teleop | `flower_descore` | bool | Can Descore Flowers |
| Teleop | `pollen_shooter` | bool | Pollen Shooter |
| Teleop | `nectar_shooter` | bool | Nectar Shooter |
| Teleop | `robot_died` | bool | Robot Died |
| Teleop | `died_at_seconds` | int or null | Died At |
| Teleop | `died_reason` | string | Died Reason |
| Endgame | `park` | bool | Park |
| Endgame | `driver_quality` | double | Driver Quality |
| Endgame | `defense_rating` | int | Defense Rating |
| Endgame | `defense_cause` | string or null | Defense Cause |
| Endgame | `drivetrain_speed` | int | Drivetrain Speed |
| Endgame | `intake_speed` | int | Intake Speed |
| Endgame | `shooter_speed` | int | Shooter Speed |

The app no longer writes these DECODE keys:

- `artifacts_auto`
- `indexing_auto`
- `artifacts_teleop`
- `indexing_teleop`
- `base_expansion`

## Export columns for FTC

The Sheets export and the CSV, Excel, and PDF exports use the same game
columns, in this order, after the common columns:

1. Leave
2. Auto Hive Tips
3. Teleop Hive Tips
4. Flower Score
5. Flower Descore
6. Pollen Shooter
7. Nectar Shooter
8. Park
9. Driver Quality (/5)
10. Robot Died
11. Defense Rating (/5)
12. Drivetrain Speed (/5)
13. Intake Speed (/5)
14. Shooter Speed (/5)
15. Defense Cause
16. Died At
17. Died Reason
18. Comments

The Sheets header row has 24 columns in total.

## Old DECODE reports

- Old DECODE reports stay in Firestore. No migration runs.
- The app still classifies a report with the `artifacts_auto` key as FTC.
- The app shows the BIOBUZZ fields for an old DECODE report. Those
  fields show their default values.
- A Sheets tab that an old DECODE event created keeps its DECODE header
  row. Do not export a BIOBUZZ report into such a tab.

## Match timer

The FRC form and the FTC form share the `MatchTimer` widget. The widget
takes a `MatchTiming` value. The FTC form passes `MatchTiming.ftc`.

| Value | FRC | FTC (BIOBUZZ) |
|---|---|---|
| Auto | 15 s | 30 s |
| Transition | 3 s | 8 s |
| Teleop | 2:15 | 2:00 |
| Endgame phase starts at | 0:30 | 0:20 |
| Clock at match start | 2:30 | 2:30 |

- The clock holds at the teleop length during the transition.
- The `died_at_seconds` value is the clock reading. Its range stays 0 to
  150 for both programs.

## Program type on a new match

- The FTC form sets `programType` to `FTC` on each new match report.
- Before this change, a new report had the default value `FRC`.
- The repository copies the report's `programType` into a new event
  document on the first save.
- So the first match of a new FTC event created that event as FRC. The
  edit action then opened the FRC form for an FTC match.
- An event that the schedule fetch creates is not affected. The fetch
  sets `programType` itself.

## Known problems found during the device test

- PDF export fails with a null check error. The file
  `assets/fonts/Roboto-Regular.ttf` holds an HTML page, not a font. This
  problem is older than this change. This spec does not correct it.
- The Sheets export for BIOBUZZ has unit tests only. The test team has no
  sheet, so the device test did not write a sheet row.

## Not in scope

- Step 4 of the simplification roadmap (schema-driven forms) stays
  unstarted.
