import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

/// Step 2 of password recovery: code + new password. On success the user is
/// sent back to sign-in with an informational message.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = (widget.email ?? '').trim();
    if (email.isEmpty) {
      context.go(RoutePaths.forgotPassword);
      return;
    }

    final ok = await ref
        .read(authProvider.notifier)
        .resetPassword(
          email: email,
          code: _codeController.text.trim(),
          newPassword: _passwordController.text,
        );
    if (ok && mounted) context.go(RoutePaths.signIn);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Set a new password',
      subtitle: widget.email == null
          ? 'Enter the code you received and choose a new password.'
          : 'Code sent to ${widget.email}.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFeedback(error: auth.errorMessage, info: auth.infoMessage),
            AppTextField(
              label: 'Reset code',
              controller: _codeController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.pin_outlined,
              validator: (value) => Validators.verificationCode(value),
              enabled: !auth.isBusy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'New password',
              controller: _passwordController,
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
              hint: 'At least 8 characters, with a number',
              validator: Validators.password,
              enabled: !auth.isBusy,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Confirm new password',
              controller: _confirmController,
              obscureText: true,
              prefixIcon: Icons.lock_reset_outlined,
              validator: (value) =>
                  Validators.confirmPassword(value, _passwordController.text),
              enabled: !auth.isBusy,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Reset password',
              loading: auth.isBusy,
              onPressed: auth.isBusy ? null : _submit,
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
