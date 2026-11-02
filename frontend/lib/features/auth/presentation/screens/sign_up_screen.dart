import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

/// Registration form: full name, email, password, confirm password and
/// terms acceptance — all validated before the request is made.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _termsAccepted = false;
  bool _termsError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final validForm = _formKey.currentState?.validate() ?? false;
    if (!_termsAccepted) {
      setState(() => _termsError = true);
      return;
    }
    if (!validForm) return;

    final notifier = ref.read(authProvider.notifier);
    final ok = await notifier.signUp(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!ok || !mounted) return;
    final email =
        ref.read(authProvider).pendingVerificationEmail ??
        _emailController.text.trim();
    context.push(
      '${RoutePaths.verifyEmail}?email=${Uri.encodeComponent(email)}',
    );
  }

  Future<void> _showTerms() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & privacy'),
        content: const SingleChildScrollView(
          child: Text(
            'This is placeholder copy for the demo build.\n\n'
            '• Your account data is used to provide bookings and charging '
            'history.\n'
            '• In production, accounts are handled by Amazon Cognito and data '
            'is stored by the Spring Boot backend.\n'
            '• No payment is collected inside the app in this phase.\n\n'
            'Replace this text with the real terms before release.',
            style: AppTextStyles.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'One account for charging, bookings and your vehicles.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFeedback(error: auth.errorMessage, info: auth.infoMessage),
            AppTextField(
              label: 'Full name',
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icons.person_outline_rounded,
              hint: 'Alex Driver',
              validator: Validators.fullName,
              enabled: !auth.isBusy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              validator: Validators.email,
              enabled: !auth.isBusy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Password',
              controller: _passwordController,
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              hint: 'At least 8 characters, with a number',
              validator: Validators.password,
              enabled: !auth.isBusy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Confirm password',
              controller: _confirmController,
              obscureText: true,
              prefixIcon: Icons.lock_reset_outlined,
              validator: (value) =>
                  Validators.confirmPassword(value, _passwordController.text),
              enabled: !auth.isBusy,
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: auth.isBusy
                  ? null
                  : () => setState(() {
                      _termsAccepted = !_termsAccepted;
                      if (_termsAccepted) _termsError = false;
                    }),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: AppSpacing.touchTarget,
                      height: AppSpacing.touchTarget,
                      child: Checkbox(
                        value: _termsAccepted,
                        onChanged: auth.isBusy
                            ? null
                            : (value) => setState(() {
                                _termsAccepted = value ?? false;
                                if (_termsAccepted) _termsError = false;
                              }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text.rich(
                          TextSpan(
                            text: 'I accept the ',
                            style: AppTextStyles.bodySoft,
                            children: [
                              TextSpan(
                                text: 'terms of service',
                                style: AppTextStyles.bodySoft.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: ' and privacy policy.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_termsError)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  'You must accept the terms to continue',
                  style: AppTextStyles.meta.copyWith(color: AppColors.danger),
                ),
              ),
            TextButton(
              onPressed: auth.isBusy ? null : _showTerms,
              child: const Text('Read terms'),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Create account',
              loading: auth.isBusy,
              onPressed: auth.isBusy ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account?', style: AppTextStyles.bodySoft),
                TextButton(
                  onPressed: auth.isBusy
                      ? null
                      : () => context.go(RoutePaths.signIn),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
