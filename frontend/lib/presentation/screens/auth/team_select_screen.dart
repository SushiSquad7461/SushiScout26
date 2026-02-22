import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class TeamSelectScreen extends ConsumerStatefulWidget {
  const TeamSelectScreen({super.key});

  @override
  ConsumerState<TeamSelectScreen> createState() => _TeamSelectScreenState();
}

class _TeamSelectScreenState extends ConsumerState<TeamSelectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _inviteCodeController = TextEditingController();
  final _teamNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inviteCodeController.dispose();
    _teamNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join or Create Team'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Join Team'),
            Tab(text: 'Create Team'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJoinTab(authState, colorScheme),
          _buildCreateTab(authState, colorScheme),
        ],
      ),
    );
  }

  Widget _buildJoinTab(AuthState authState, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter an invite code to join a team',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          
          TextField(
            controller: _inviteCodeController,
            decoration: const InputDecoration(
              labelText: 'Invite Code',
              hintText: 'Enter 6-character code',
              prefixIcon: Icon(Icons.group_add),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
          ),
          
          const SizedBox(height: AppTheme.spacingMd),
          
          if (authState.hasError) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.spacingSm),
              ),
              child: Text(
                authState.errorMessage ?? 'Error',
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],
          
          FilledButton.icon(
            onPressed: authState.status == AuthStatus.loading
                ? null
                : () {
                    final code = _inviteCodeController.text.trim();
                    if (code.length >= 6) {
                      ref.read(authProvider.notifier).joinTeam(code);
                    }
                  },
            icon: authState.status == AuthStatus.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Join Team'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTab(AuthState authState, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create a new team',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          
          TextField(
            controller: _teamNameController,
            decoration: const InputDecoration(
              labelText: 'Team Name',
              hintText: 'e.g., Sushi Robotics',
              prefixIcon: Icon(Icons.group),
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingMd),
          
          if (authState.hasError) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.spacingSm),
              ),
              child: Text(
                authState.errorMessage ?? 'Error',
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
          ],
          
          FilledButton.icon(
            onPressed: authState.status == AuthStatus.loading
                ? null
                : () {
                    final name = _teamNameController.text.trim();
                    if (name.isNotEmpty) {
                      ref.read(authProvider.notifier).createTeam(name);
                    }
                  },
            icon: authState.status == AuthStatus.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Create Team'),
          ),
        ],
      ),
    );
  }
}
