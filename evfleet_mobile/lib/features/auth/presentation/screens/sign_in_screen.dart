import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

/// Sign-in form with validation, password visibility toggle, loading and
/// error states. Success is signalled by the router redirect (the auth state
/// changed), never by faking navigation.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(authProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    // On success the router redirect moves to /home; on failure the provider
    // exposes errorMessage, rendered below.
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to find chargers and manage your bookings.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFeedback(error: auth.errorMessage, info: auth.infoMessage),
            AppTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.mail_outline_rounded,
              hint: 'you@example.com',
              validator: Validators.email,
              enabled: !auth.isBusy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Password',
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Password is required'
                  : null,
              onFieldSubmitted: (_) => _submit(),
              enabled: !auth.isBusy,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: auth.isBusy
                    ? null
                    : () => context.push(RoutePaths.forgotPassword),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (ref.watch(authIsMockProvider))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Demo mode: any valid email with an 8+ character password '
                  'signs in. No real account is created.',
                  style: AppTextStyles.meta,
                  textAlign: TextAlign.center,
                ),
              ),
            AppButton(
              label: 'Sign in',
              loading: auth.isBusy,
              onPressed: auth.isBusy ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('New to EV Fleet?', style: AppTextStyles.bodySoft),
                TextButton(
                  onPressed: auth.isBusy
                      ? null
                      : () => context.push(RoutePaths.signUp),
                  child: const Text('Create account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
