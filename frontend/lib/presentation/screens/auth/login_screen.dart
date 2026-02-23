import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Form(
            key: _formKey,
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

                if (_isDesktop) ...[
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => _sendPasswordReset(context),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign In'),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: authState.status == AuthStatus.loading
                          ? null
                          : () =>
                              ref.read(authProvider.notifier).signInWithGoogle(),
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
                ],

                const SizedBox(height: AppTheme.spacingLg),

                Text(
                  _isDesktop
                      ? 'First time? Sign in on mobile/web with Google first'
                      : 'Sign in required for team-based data',
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
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await ref.read(authProvider.notifier).signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    await ref.read(authProvider.notifier).sendPasswordResetEmail(email);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    }
  }
}
