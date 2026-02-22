import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              Icon(
                Icons.sports_soccer,
                size: 80,
                color: colorScheme.primary,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                'SushiScout 26',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'FRC & FTC Scouting',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              
              const Spacer(),
              
              if (authState.hasError) ...[
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.spacingSm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error),
                      const SizedBox(width: AppTheme.spacingSm),
                      Expanded(
                        child: Text(
                          authState.errorMessage ?? 'An error occurred',
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
              ],
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: authState.status == AuthStatus.loading
                      ? null
                      : () => ref.read(authProvider.notifier).signInWithGoogle(),
                  icon: authState.status == AuthStatus.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    authState.status == AuthStatus.loading
                        ? 'Signing in...'
                        : 'Sign in with Google',
                  ),
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingLg),
              
              Text(
                'Sign in required for team-based data',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        ),
      ),
    );
  }
}
