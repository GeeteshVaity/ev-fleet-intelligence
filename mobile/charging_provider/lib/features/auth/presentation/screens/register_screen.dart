
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.onRegister,
    required this.onLogin,
    this.isLoading = false,
  });

  final void Function({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) onRegister;

  final VoidCallback onLogin;
  final bool isLoading;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase =>
      RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasNumber =>
      RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _hasSpecialCharacter =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(_passwordController.text);

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and conditions.'),
        ),
      );
      return;
    }

    widget.onRegister(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      mobile: _mobileController.text.trim(),
      password: _passwordController.text,
    );
  }

  Widget _buildPasswordRule(String label, bool fulfilled) {
    return Row(
      children: [
        Icon(
          fulfilled ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: fulfilled ? AppColors.success : Colors.grey,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fulfilled
                  ? AppColors.success
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App identity
                    Row(
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.ev_station_rounded,
                            color: AppColors.black,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EV Fleet Intelligence',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Charging Provider Network',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Heading
                    Text(
                      'Create Host Account',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Monetize your EV charging infrastructure and '
                      'manage bookings seamlessly.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 28),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Full name
                            Text(
                              'Full Name',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.name,
                              ],
                              decoration: const InputDecoration(
                                hintText: 'Enter your full name',
                                prefixIcon: Icon(
                                  Icons.person_outline_rounded,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your full name';
                                }
                                if (value.trim().length < 2) {
                                  return 'Name is too short';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 18),

                            // Business email
                            Text(
                              'Business Email',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.email,
                              ],
                              decoration: const InputDecoration(
                                hintText: 'name@example.com',
                                prefixIcon: Icon(
                                  Icons.mail_outline_rounded,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
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

                            const SizedBox(height: 18),

                            // Mobile number
                            Text(
                              'Mobile Number',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    border: Border.all(
                                      color: theme.dividerColor,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+91',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _mobileController,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.telephoneNumber,
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: 'Enter mobile number',
                                      prefixIcon: Icon(
                                        Icons.phone_outlined,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Enter mobile number';
                                      }
                                      if (!RegExp(
                                        r'^[6-9]\d{9}$',
                                      ).hasMatch(value.trim())) {
                                        return 'Enter a valid 10-digit number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // Password
                            Text(
                              'Password',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.newPassword,
                              ],
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Create a strong password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please create a password';
                                }
                                if (value.length < 8) {
                                  return 'Password must have at least 8 characters';
                                }
                                if (!_hasUppercase ||
                                    !_hasNumber ||
                                    !_hasSpecialCharacter) {
                                  return 'Password does not meet requirements';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            // Password requirements
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _buildPasswordRule(
                                  '8+ characters',
                                  _hasMinLength,
                                ),
                                _buildPasswordRule(
                                  'Uppercase letter',
                                  _hasUppercase,
                                ),
                                _buildPasswordRule(
                                  'At least one number',
                                  _hasNumber,
                                ),
                                _buildPasswordRule(
                                  'Special character',
                                  _hasSpecialCharacter,
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Confirm password
                            Text(
                              'Confirm Password',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                hintText: 'Re-enter your password',
                                prefixIcon: const Icon(
                                  Icons.lock_reset_rounded,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Terms and conditions
                            CheckboxListTile(
                              value: _acceptedTerms,
                              onChanged: (value) {
                                setState(() {
                                  _acceptedTerms = value ?? false;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              dense: true,
                              title: RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodySmall,
                                  children: const [
                                    TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                      text: 'Terms and Conditions',
                                      style: TextStyle(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Create account
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: widget.isLoading
                                    ? null
                                    : _handleRegister,
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
                                          Text('Create Account'),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Login navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: widget.onLogin,
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
