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

/// Step 1 of password recovery: request a reset code for an email address.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _requested = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref
        .read(authProvider.notifier)
        .requestPasswordReset(email: _emailController.text.trim());
    if (ok && mounted) setState(() => _requested = true);
  }

  void _continueToReset() {
    final email = _emailController.text.trim();
    context.push(
      '${RoutePaths.resetPassword}?email=${Uri.encodeComponent(email)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AuthScaffold(
      title: 'Forgot password',
      subtitle: 'Enter your account email and we will send a reset code.',
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
              prefixIcon: Icons.mail_outline_rounded,
              validator: Validators.email,
              enabled: !auth.isBusy,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Send reset code',
              loading: auth.isBusy,
              onPressed: auth.isBusy ? null : _submit,
            ),
            if (_requested) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'I have the code',
                variant: AppButtonVariant.secondary,
                onPressed: _continueToReset,
              ),
            ],
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
