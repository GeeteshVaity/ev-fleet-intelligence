
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.onSendResetCode,
    required this.onBackToLogin,
    this.isLoading = false,
  });

  final ValueChanged<String> onSendResetCode;
  final VoidCallback onBackToLogin;
  final bool isLoading;

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      widget.onSendResetCode(_emailController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBackToLogin,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Back to Login',
          style: theme.textTheme.bodyMedium,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Header icon
                    Center(
                      child: Container(
                        height: 84,
                        width: 84,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: AppColors.secondary,
                          size: 42,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Heading
                    Text(
                      'Forgot Password?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Enter your registered email address. '
                      'We will send you a verification code '
                      'to reset your password.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Email form card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Registered Email Address',
                              style: theme.textTheme.labelLarge,
                            ),

                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [
                                AutofillHints.email,
                              ],
                              onFieldSubmitted: (_) => _handleSubmit(),
                              decoration: const InputDecoration(
                                hintText: 'Enter your email address',
                                prefixIcon: Icon(
                                  Icons.mail_outline_rounded,
                                ),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }

                                if (!RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(value.trim())) {
                                  return 'Enter a valid email address';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 28),

                            // Send reset code
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: widget.isLoading
                                    ? null
                                    : _handleSubmit,
                                child: widget.isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.black,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('Send Reset Code'),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 19,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Login navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Remember your password?',
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: widget.onBackToLogin,
                          child: const Text('Log In'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
