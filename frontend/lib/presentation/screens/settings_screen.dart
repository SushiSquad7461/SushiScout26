import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/validation/form_validators.dart';
import '../../data/local/preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/event_providers.dart';
import '../theme/app_theme.dart';
import '../theme/team_brand.dart';
import '../widgets/color_bar.dart';
import '../widgets/team_settings_section.dart';

/// Settings — the same screen's worth of content that used to live in
/// `SettingsSheet`, now pushed as a route.
///
/// Section order is unchanged: Profile (name, event code, program type),
/// Appearance (theme mode, then the brand picker where the colour-seed chips
/// were), Team, Sheets export behind `isTeamAdminProvider`, Done. Every
/// controller, provider call, `initState`, `_loadTeamSheet`, `_saveSheet`,
/// `_backfillEvent` and `dispose` is the original verbatim — including the two
/// `SelectableText`s and the comments explaining why the sheet error is rendered
/// outside the field's `InputDecoration`.
///
/// The only behavioural difference is the container: a `Scaffold` instead of a
/// `DraggableScrollableSheet`, so the content scrolls the whole screen instead
/// of a 0.5–0.95 draggable panel. `Navigator.pop(context)` on Done still
/// dismisses it, so callers are unaffected.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scouterNameCtrl = TextEditingController();
  final _eventCodeCtrl = TextEditingController();
  final _sheetCtrl = TextEditingController();
  String? _sheetId;
  String? _sheetError;
  bool _saving = false;
  bool _backfilling = false;
  bool _sheetLoadFailed = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _scouterNameCtrl.text = settings[PrefKeys.scouterName] ?? '';
    _eventCodeCtrl.text = settings[PrefKeys.eventCode] ?? '';
    _loadTeamSheet();
  }

  void _loadTeamSheet() {
    final String teamId;
    try {
      final id = ref.read(currentTeamIdProvider);
      if (id == null) return;
      teamId = id;
    } catch (_) {
      // Auth/team providers may not be ready yet (e.g. no signed-in user) —
      // leave the export section in its "not configured" state.
      return;
    }

    ref
        .read(teamRepositoryProvider)
        .getTeamSettings(teamId)
        .then((settings) {
          if (!mounted) return;
          setState(() {
            _sheetId = settings?.googleSheetId;
            _sheetCtrl.text = _sheetId ?? '';
          });
        })
        .catchError((Object _) {
          // A genuine load failure (permission-denied, network) must not look
          // like "not configured" — that would tell an admin whose sheet IS
          // connected that exports are off.
          if (!mounted) return;
          setState(() => _sheetLoadFailed = true);
        });
  }

  Future<void> _saveSheet() async {
    final teamId = ref.read(currentTeamIdProvider);
    if (teamId == null) return;

    setState(() {
      _saving = true;
      _sheetError = null;
    });

    try {
      final stored = await ref
          .read(teamRepositoryProvider)
          .setTeamSheet(teamId: teamId, sheetId: _sheetCtrl.text);
      if (!mounted) return;
      setState(() => _sheetId = stored);
    } catch (e) {
      // The callable's failed-precondition message names the service
      // account to share the sheet with — surface it verbatim, without the
      // technical "[firebase_functions/<code>]" prefix FirebaseFunctionsException
      // adds to toString().
      if (!mounted) return;
      final message = e is FirebaseFunctionsException
          ? (e.message ?? e.toString())
          : e.toString();
      setState(() => _sheetError = message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _backfillEvent() async {
    final eventId = ref.read(currentEventIdProvider);

    setState(() => _backfilling = true);
    try {
      await ref
          .read(teamRepositoryProvider)
          .backfillEventToSheets(eventId: eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Backfill complete")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Backfill failed: $e")));
    } finally {
      if (mounted) setState(() => _backfilling = false);
    }
  }

  @override
  void dispose() {
    _scouterNameCtrl.dispose();
    _eventCodeCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brand = BrandScope.of(context);

    return Scaffold(
      appBar: BrandAppBar(
        brand: brand,
        title: 'Settings',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      bottomNavigationBar: BrandActionBar(
        brand: brand,
        label: 'Done',
        onPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppTheme.spacingLg,
          right: AppTheme.spacingLg,
          top: AppTheme.spacingLg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile section
            BrandSectionLabel(brand: brand, text: "Profile"),
            const SizedBox(height: AppTheme.spacingMd),

            TextField(
              controller: _scouterNameCtrl,
              decoration: const InputDecoration(
                labelText: "Your Name",
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (val) =>
                  ref.read(settingsProvider.notifier).setScouterName(val),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            TextFormField(
              controller: _eventCodeCtrl,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: FormValidators.eventCode,
              decoration: const InputDecoration(
                labelText: "Event Code",
                prefixIcon: Icon(Icons.event_outlined),
                helperText: "e.g., 2026casj",
              ),
              onChanged: (val) =>
                  ref.read(settingsProvider.notifier).setEventCode(val),
            ),

            const SizedBox(height: AppTheme.spacingMd),

            _buildProgramTypeSelector(context),

            const SizedBox(height: AppTheme.spacingLg),

            // Appearance section
            BrandSectionLabel(brand: brand, text: "Appearance"),
            const SizedBox(height: AppTheme.spacingMd),

            _buildThemeSelector(context),

            const SizedBox(height: AppTheme.spacingMd),

            Text(
              "Team Brand",
              style: AppTheme.label(
                brand,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            _buildBrandSelector(context),

            const SizedBox(height: AppTheme.spacingXl),

            // Team section (current team, invite code, switch/join/create).
            const TeamSettingsSection(),

            if (ref.watch(isTeamAdminProvider)) ...[
              const SizedBox(height: AppTheme.spacingXl),
              BrandSectionLabel(brand: brand, text: "Sheets export"),
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                children: [
                  if (!_sheetLoadFailed &&
                      _sheetId != null &&
                      _sheetId!.isNotEmpty) ...[
                    SyncSquare(brand: brand, synced: true),
                    const SizedBox(width: AppTheme.spacingSm),
                  ],
                  Expanded(
                    child: Text(
                      _sheetLoadFailed
                          ? "Couldn't check export status"
                          : (_sheetId == null || _sheetId!.isEmpty)
                          ? "Not configured — matches aren't being exported."
                          : "Connected",
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (!_sheetLoadFailed &&
                  _sheetId != null &&
                  _sheetId!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingXs),
                // Selectable so an admin can copy the link straight to a
                // new tab — this is the only place that spreadsheet id is
                // surfaced in the UI.
                SelectableText(
                  'https://docs.google.com/spreadsheets/d/${_sheetId!}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: brand.accentHighlight,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacingSm),
              TextField(
                controller: _sheetCtrl,
                decoration: const InputDecoration(
                  labelText: "Google Sheet link or id",
                ),
              ),
              // Rendered outside the field's InputDecoration on purpose:
              // InputDecorator's errorText ellipsizes past a couple of
              // lines by default, but this message's entire point is the
              // ~110-char service-account address the admin must copy —
              // truncating it defeats the message. SelectableText here
              // also lets them copy it directly instead of retyping.
              if (_sheetError != null) ...[
                const SizedBox(height: AppTheme.spacingXs),
                SelectableText(
                  _sheetError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacingSm),
              // Wrap, not Row: "Save" + "Backfill this event" side by side
              // overflowed a phone width by ~139px, which is what made this
              // section render garbled. They now reflow onto a second line.
              Wrap(
                spacing: AppTheme.spacingSm,
                runSpacing: AppTheme.spacingSm,
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _saveSheet,
                    child: Text(_saving ? "Saving…" : "Save"),
                  ),
                  OutlinedButton(
                    onPressed:
                        (_sheetId == null || _sheetId!.isEmpty || _backfilling)
                        ? null
                        : _backfillEvent,
                    child: Text(
                      _backfilling ? "Backfilling…" : "Backfill this event",
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppTheme.spacingLg),
          ],
        ),
      ),
    );
  }

  /// Program type: editable only while the event document doesn't exist yet.
  ///
  /// `dashboard.dart` lets the event document win over this preference, so an
  /// always-editable control lies to the scout — pick FTC against an FRC event
  /// and it reverts on the next Scout Match tap, with no feedback. That is the
  /// actual bug behind "FTC support doesn't work".
  ///
  /// While no document exists, the choice is real: the first saved match creates
  /// the event from this value (`FirestoreRepository._getOrCreateEvent`, which
  /// takes the match's `programType` as its fallback). Once the document exists,
  /// this becomes a read-only statement of what the event *is*.
  Widget _buildProgramTypeSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brand = BrandScope.of(context);

    final scoutValue =
        ref.watch(settingsProvider)[PrefKeys.programType] ?? 'FRC';
    final eventCode = ref.watch(currentEventCodeProvider);

    // valueOrNull, not `.when`: a spinner here would flash on every open, and
    // "still loading" and "no document" want the same treatment — editable.
    final event = ref.watch(currentEventProvider).asData?.value;
    final locked = event != null;
    final value = event?.programType ?? scoutValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Program Type",
          style: AppTheme.label(
            brand,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),

        if (locked)
          // A solid block, per the brand's geometry — this is a value, not a
          // control, and it should not look tappable.
          Row(
            children: [
              ColoredBox(
                color: colorScheme.onSurface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingSm + 2,
                  ),
                  child: Text(
                    value,
                    style: AppTheme.display(
                      brand,
                      size: 17,
                      letterSpacing: 0.1,
                      color: colorScheme.surface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  'set by event $eventCode',
                  style: AppTheme.helper(
                    brand,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          )
        else
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'FRC', label: Text('FRC')),
              ButtonSegment(value: 'FTC', label: Text('FTC')),
            ],
            selected: {value},
            onSelectionChanged: (selection) {
              ref
                  .read(settingsProvider.notifier)
                  .setProgramType(selection.first);
            },
          ),

        const SizedBox(height: AppTheme.spacingXs),
        Text(
          locked
              ? 'An event is one program. To scout the other, enter a new event code above.'
              : "No matches yet for $eventCode — the first one you save creates it as $value.",
          style: AppTheme.helper(brand, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final currentTheme =
        ref.watch(settingsProvider)[PrefKeys.themeMode] ?? 'system';

    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'system',
          icon: Icon(Icons.brightness_auto),
          label: Text('Auto'),
        ),
        ButtonSegment(
          value: 'light',
          icon: Icon(Icons.light_mode_outlined),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: 'dark',
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('Dark'),
        ),
      ],
      selected: {currentTheme},
      onSelectionChanged: (selection) {
        ref.read(settingsProvider.notifier).setThemeMode(selection.first);
      },
    );
  }

  /// Replaces `_buildColorSelector`. Same preference key (`PrefKeys.colorSeed`)
  /// and the same `setColorSeed` call — the values are brand ids now rather
  /// than colour names, and `TeamBrands.byId` falls back to Sushi Squad for any
  /// legacy value already on a scout's device ('salmon', 'blue', …).
  Widget _buildBrandSelector(BuildContext context) {
    final currentId =
        ref.watch(settingsProvider)[PrefKeys.colorSeed] ??
        TeamBrands.fallback.id;

    // IntrinsicHeight is required, not decorative: CrossAxisAlignment.stretch
    // inside a SingleChildScrollView forces an infinite height, which threw
    // during layout and left every widget after this Row unlaid-out — they
    // then painted stacked at the top of the screen. IntrinsicHeight bounds
    // the row to its tallest child so the tiles can still stretch to match.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gap between tiles rather than after each, so the row leaves no
          // trailing space now that the placeholder is gone.
          for (var i = 0; i < TeamBrands.all.length; i++) ...[
            if (i > 0) const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: _BrandTile(
                brand: TeamBrands.all[i],
                selected: TeamBrands.byId(currentId).id == TeamBrands.all[i].id,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .setColorSeed(TeamBrands.all[i].id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One selectable team identity: its colour bar, its name, and whether it's
/// active. Replaces `_ColorSeedChip`.
class _BrandTile extends StatelessWidget {
  final TeamBrand brand;
  final bool selected;
  final VoidCallback onTap;

  const _BrandTile({
    required this.brand,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingSm + 3),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? cs.onSurface : cs.outlineVariant,
            width: selected ? 3 : AppTheme.ruleWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorBar(brand: brand, thickness: 8),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              brand.name,
              style: AppTheme.display(
                brand,
                size: 15,
                letterSpacing: 0.04,
                height: 1.1,
                color: cs.onSurface,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: AppTheme.spacingSm),
              ColoredBox(
                color: cs.onSurface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: AppTheme.spacingXs,
                  ),
                  child: Text(
                    'active',
                    style: AppTheme.label(brand, size: 12, color: cs.surface),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
