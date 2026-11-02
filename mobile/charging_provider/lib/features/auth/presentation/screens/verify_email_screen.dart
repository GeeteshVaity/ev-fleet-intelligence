
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.onVerify,
    required this.onResendCode,
    required this.onEditEmail,
    this.isLoading = false,
  });

  final String email;
  final ValueChanged<String> onVerify;
  final VoidCallback onResendCode;
  final VoidCallback onEditEmail;
  final bool isLoading;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const int _resendDuration = 30;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  Timer? _timer;
  int _remainingSeconds = _resendDuration;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      6,
      (_) => TextEditingController(),
    );

    _focusNodes = List.generate(
      6,
      (_) => FocusNode(),
    );

    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();

    for (final controller in _controllers) {
      controller.dispose();
    }

    for (final node in _focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_remainingSeconds <= 0) {
          timer.cancel();
          return;
        }

        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      },
    );
  }

  String get _otp =>
      _controllers.map((controller) => controller.text).join();

  void _handleVerify() {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete 6-digit code.'),
        ),
      );
      return;
    }

    widget.onVerify(_otp);
  }

  void _handleResend() {
    if (_remainingSeconds > 0) return;

    for (final controller in _controllers) {
      controller.clear();
    }

    setState(() {
      _remainingSeconds = _resendDuration;
    });

    _startTimer();
    _focusNodes.first.requestFocus();

    widget.onResendCode();
  }

  String get _formattedTime {
    final seconds = _remainingSeconds.toString().padLeft(2, '0');
    return '00:$seconds';
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
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Verification icon
                  Center(
                    child: Container(
                      height: 84,
                      width: 84,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          height: 64,
                          width: 64,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_email_read_rounded,
                            color: AppColors.black,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Heading
                  Text(
                    'Verify Your Email',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'We sent a 6-digit verification code to your email address.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Email information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 42,
                            width: 42,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(
                                alpha: 0.15,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.email_outlined,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'REGISTERED EMAIL',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.email,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onEditEmail,
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // OTP heading
                  Text(
                    'Enter Verification Code',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Six-digit OTP input
                  Row(
                    children: List.generate(6, (index) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == 5 ? 0 : 8,
                          ),
                          child: SizedBox(
                            height: 58,
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(1),
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                filled: true,
                                fillColor: colors.surface,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.dividerColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: colors.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty && index < 5) {
                                  _focusNodes[index + 1].requestFocus();
                                } else if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }

                                if (index == 5 && value.isNotEmpty) {
                                  _focusNodes[index].unfocus();
                                }

                                setState(() {});
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 28),

                  // Resend countdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Resend code in ',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        _formattedTime,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Resend button
                  Center(
                    child: TextButton(
                      onPressed:
                          _remainingSeconds == 0 ? _handleResend : null,
                      child: const Text('Resend Verification Code'),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Verify button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: widget.isLoading ? null : _handleVerify,
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Verify Email'),
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
        ),
      ),
    );
  }
}
