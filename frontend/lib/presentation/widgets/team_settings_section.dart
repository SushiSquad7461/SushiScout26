import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/team.dart';
import '../../core/validation/form_validators.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// "Team" section of the settings sheet: shows the active team + invite code,
/// lists all teams the user belongs to (tap to switch), and lets the user join
/// or create another team inline. Join/create keep their loading + error state
/// local so the surrounding modal is never torn down (see joinTeamInApp).
class TeamSettingsSection extends ConsumerStatefulWidget {
  const TeamSettingsSection({super.key});

  @override
  ConsumerState<TeamSettingsSection> createState() =>
      _TeamSettingsSectionState();
}

class _TeamSettingsSectionState extends ConsumerState<TeamSettingsSection> {
  final _joinCtrl = TextEditingController();
  final _createCtrl = TextEditingController();
  bool _joining = false;
  bool _creating = false;
  bool _regenerating = false;
  String? _error;

  @override
  void dispose() {
    _joinCtrl.dispose();
    _createCtrl.dispose();
    super.dispose();
  }

  Future<void> _switch(String teamId) async {
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).switchTeam(teamId);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _join() async {
    final code = _joinCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).joinTeamInApp(code);
      if (!mounted) return;
      _joinCtrl.clear();
      ref.invalidate(userTeamsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _create() async {
    final name = _createCtrl.text.trim();
    if (name.isEmpty) return;
    final validationError = FormValidators.teamName(name);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).createTeamInApp(name);
      if (!mounted) return;
      _createCtrl.clear();
      ref.invalidate(userTeamsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _regenerate(String teamId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate invite code?'),
        content: const Text(
            'The current code stops working immediately. Anyone with the old '
            'code will no longer be able to join.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Regenerate')),
        ],
      ),
    );
    if (confirmed != true) return;

    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    setState(() {
      _regenerating = true;
      _error = null;
    });
    try {
      await ref.read(teamRepositoryProvider).regenerateInviteCode(
            teamId: teamId,
            requestingUserId: userId,
          );
      if (!mounted) return;
      ref.invalidate(userTeamsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final teamsAsync = ref.watch(userTeamsProvider);
    final currentTeamId = ref.watch(currentTeamIdProvider);
    final isAdmin = ref.watch(isTeamAdminProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        teamsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppTheme.spacingMd),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            "Couldn't load your teams",
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.error),
          ),
          data: (teams) => _buildBody(
              context, teams, currentTeamId, isAdmin, theme, colorScheme),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<Team> teams,
    String? currentTeamId,
    bool isAdmin,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    Team? current;
    for (final t in teams) {
      if (t.id == currentTeamId) current = t;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current team + invite code.
        if (current != null) ...[
          Text(current.name, style: theme.textTheme.titleMedium),
          Text(
            '${isAdmin ? 'Admin' : 'Member'} · ${current.memberCount} members',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Row(
            children: [
              Text('Invite code: ',
                  style: theme.textTheme.bodyMedium),
              SelectableText(
                current.inviteCode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              IconButton(
                tooltip: 'Copy invite code',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: current!.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied')),
                  );
                },
              ),
            ],
          ),
          if (isAdmin)
            TextButton(
              onPressed:
                  _regenerating ? null : () => _regenerate(current!.id),
              child: Text(_regenerating ? 'Regenerating…' : 'Regenerate'),
            ),
          const SizedBox(height: AppTheme.spacingMd),
        ],

        // Team list.
        Text('Your teams',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppTheme.spacingXs),
        ...teams.map((t) {
          final active = t.id == currentTeamId;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(active
                ? Icons.check_circle
                : Icons.circle_outlined),
            title: Text(t.name),
            subtitle: Text('${t.memberCount} members'),
            enabled: !active,
            onTap: active ? null : () => _switch(t.id),
          );
        }),

        const SizedBox(height: AppTheme.spacingMd),

        // Add a team (join / create).
        Text('Add a team',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: AppTheme.spacingXs),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _joinCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            FilledButton(
              onPressed: _joining ? null : _join,
              child: _joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Join'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _createCtrl,
                decoration: const InputDecoration(
                  labelText: 'New team name',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            OutlinedButton(
              onPressed: _creating ? null : _create,
              child: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ],
    );
  }
}
