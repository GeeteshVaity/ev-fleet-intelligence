import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

/// Email verification step shown right after registration. On success the
/// router redirect moves the user into the main app.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  /// Passed as `?email=` query parameter (or from the auth state).
  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String get _email =>
      widget.email ?? ref.read(authProvider).pendingVerificationEmail ?? '';

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_email.isEmpty) {
      context.go(RoutePaths.signIn);
      return;
    }

    await ref
        .read(authProvider.notifier)
        .confirmEmail(email: _email, code: _codeController.text.trim());
  }

  Future<void> _resend() async {
    if (_email.isEmpty) return;
    await ref.read(authProvider.notifier).resendVerificationCode(email: _email);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isMock = ref.watch(authIsMockProvider);

    return AuthScaffold(
      title: 'Verify your email',
      subtitle: _email.isEmpty
          ? 'Enter the code we sent to your inbox.'
          : 'We sent a 6-digit code to $_email.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFeedback(error: auth.errorMessage, info: auth.infoMessage),
            if (isMock)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(
                  'Demo mode: verification code is '
                  '${AppConstants.demoVerificationCode}.',
                  style: AppTextStyles.meta.copyWith(
                    color: AppColors.brandDark,
                  ),
                ),
              ),
            AppTextField(
              label: 'Verification code',
              controller: _codeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.pin_outlined,
              hint: '6-digit code',
              validator: (value) => Validators.verificationCode(value),
              onFieldSubmitted: (_) => _submit(),
              enabled: !auth.isBusy,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Verify and continue',
              loading: auth.isBusy,
              onPressed: auth.isBusy ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Resend code',
              variant: AppButtonVariant.ghost,
              onPressed: auth.isBusy ? null : _resend,
            ),
            TextButton(
              onPressed: auth.isBusy
                  ? null
                  : () => context.go(RoutePaths.signIn),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
