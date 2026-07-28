import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_brand.dart';
import '../../widgets/brand_mascot.dart';
import '../../widgets/color_bar.dart';

/// Login screen — rebranded only.
///
/// Every piece of behaviour is the original: the desktop-vs-mobile branch, the
/// email/password form with its validators, the obscure-password toggle,
/// forgot-password, the Google sign-in path, the `authState.hasError` banner,
/// the loading spinners, and both `_signIn` and `_sendPasswordReset` verbatim.
///
/// What changed is the identity. `Icon(Icons.sports_soccer)` was standing in as
/// the app's logo; Team 7461 is logoless, so a mascot plate does that job now,
/// and the colour bar underneath marks the product as the team's. The plate sits
/// outside the horizontal padding so it can bleed to both edges, which is why
/// the form moved into an `Expanded` — the `Spacer`s inside it still balance the
/// remaining space exactly as before.
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
    final brand = BrandScope.of(context);
    // This is an ink page by design — black ground, white type — so it must
    // stay ink in BOTH brightnesses. Reading it from colorScheme.onSurface /
    // .surface inverted the whole screen to white-on-black in dark mode.
    final ink = AppTheme.chrome(brand);
    final onInk = AppTheme.onChrome(brand);

    return Scaffold(
      backgroundColor: ink,
      body: Column(
        children: [
          // The mascot stands in for a logo. Full-bleed, so it sits outside the
          // form's padding.
          SafeArea(
            bottom: false,
            child: MascotPlate(
              brand: brand,
              name: Mascots.peepo,
              width: double.infinity,
              height: 300,
            ),
          ),
          ColorBar(brand: brand, thickness: 8),

          Expanded(
            child: Material(
              color: ink,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: AppTheme.spacingLg),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'SushiScout 26',
                              style: AppTheme.display(
                                brand,
                                size: 46,
                                letterSpacing: -0.01,
                                height: 0.94,
                                color: onInk,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'FRC & FTC Scouting · ${brand.name}',
                              style: AppTheme.helper(
                                brand,
                                size: 17,
                                color: brand.accents[3],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppTheme.spacingXl),

                          if (authState.hasError) ...[
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingMd),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: colorScheme.error,
                                  width: AppTheme.ruleWidth,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: colorScheme.error,
                                  ),
                                  const SizedBox(width: AppTheme.spacingSm),
                                  Expanded(
                                    child: Text(
                                      authState.errorMessage ??
                                          'An error occurred',
                                      style: AppTheme.body(
                                        brand,
                                        size: 15,
                                        color: colorScheme.error,
                                      ),
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
                              style: TextStyle(color: onInk),
                              decoration: _darkField(
                                brand,
                                colorScheme,
                                label: 'Email',
                                icon: Icons.email,
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
                              style: TextStyle(color: onInk),
                              decoration: _darkField(
                                brand,
                                colorScheme,
                                label: 'Password',
                                icon: Icons.lock,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: brand.neutralOnInk,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                ),
                              ),
                              obscureText: _obscurePassword,
                              onFieldSubmitted: (_) => _signIn(),
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
                                style: TextButton.styleFrom(
                                  foregroundColor: brand.accentHighlight,
                                ),
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingMd),
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: FilledButton.styleFrom(
                                  backgroundColor: onInk,
                                  foregroundColor: ink,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: ink,
                                        ),
                                      )
                                    : const Text('Sign In'),
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: FilledButton(
                                onPressed:
                                    authState.status == AuthStatus.loading
                                    ? null
                                    : () => ref
                                          .read(authProvider.notifier)
                                          .signInWithGoogle(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: onInk,
                                  foregroundColor: ink,
                                ),
                                child: authState.status == AuthStatus.loading
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: ink,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: AppTheme.spacingSm,
                                          ),
                                          const Text('Signing in...'),
                                        ],
                                      )
                                    : const Text('Sign in with Google'),
                              ),
                            ),
                          ],

                          const SizedBox(height: AppTheme.spacingLg),

                          Text(
                            _isDesktop
                                ? 'First time? Sign in on mobile/web with Google first'
                                : 'Sign in required for team-based data',
                            style: AppTheme.helper(
                              brand,
                              color: brand.neutralOnInk,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: AppTheme.spacingLg),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The form sits on ink here rather than on the surface, so the shared
  /// `inputDecorationTheme` (which assumes a light surface) is overridden for
  /// these two fields only.
  InputDecoration _darkField(
    TeamBrand brand,
    ColorScheme colorScheme, {
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: brand.neutral, width: AppTheme.ruleWidth),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: brand.neutralOnInk),
      suffixIcon: suffix,
      labelStyle: AppTheme.label(brand, color: brand.neutralOnInk),
      floatingLabelStyle: AppTheme.label(
        brand,
        color: AppTheme.onChrome(brand),
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: brand.accentHighlight, width: 3),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await ref
        .read(authProvider.notifier)
        .signInWithEmailAndPassword(
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

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).sendPasswordResetEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
