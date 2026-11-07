
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/stations/presentation/station_api_test_screen.dart';
import '../features/onboarding/presentation/screens/provider_entry_screen.dart';
import '../features/provider/presentation/screens/provider_workspace_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const _LoginRoute(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const _RegisterRoute(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) => const _VerifyEmailRoute(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const _ForgotPasswordRoute(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const _ResetPasswordRoute(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const _ProtectedProviderRoute(
        child: ProviderEntryScreen(),
      ),
    ),
    GoRoute(
      path: '/station-api-test',
      builder: (context, state) => const _ProtectedProviderRoute(
        child: StationApiTestScreen(),
      ),
    ),
    GoRoute(
      path: '/provider-setup',
      builder: (context, state) => const _ProtectedProviderRoute(
        child: ProviderEntryScreen(),
      ),
    ),
    GoRoute(
      path: '/home/dashboard',
      builder: (context, state) => const _ProtectedProviderRoute(
        child: ProviderWorkspaceScreen(),
      ),
    ),
  ],
);

class _ProtectedProviderRoute extends ConsumerWidget {
  const _ProtectedProviderRoute({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.asData?.value.user;

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return child;
  }
}

void _showMessage(
  BuildContext context,
  String message,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message)),
    );
}

class _LoginRoute extends ConsumerWidget {
  const _LoginRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (previous, next) {
      final user = next.asData?.value.user;

      if (user != null && context.mounted) {
        context.go('/home');
      }
    });

    final auth = ref.watch(authControllerProvider).asData?.value;

    return LoginScreen(
      isLoading: auth?.isLoading ?? false,
      onLogin: ({
        required String email,
        required String password,
      }) async {
        final success = await ref
            .read(authControllerProvider.notifier)
            .signIn(email: email, password: password);

        if (!success && context.mounted) {
          final message = ref
                  .read(authControllerProvider)
                  .asData
                  ?.value
                  .error ??
              'Unable to sign in. Please try again.';

          _showMessage(context, message);
        }
      },
      onForgotPassword: () => context.go('/forgot-password'),
      onCreateAccount: () => context.go('/register'),
    );
  }
}

class _RegisterRoute extends ConsumerWidget {
  const _RegisterRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).asData?.value;

    return RegisterScreen(
      isLoading: auth?.isLoading ?? false,
      onRegister: ({
        required String fullName,
        required String email,
        required String mobile,
        required String password,
      }) async {
        final success = await ref
            .read(authControllerProvider.notifier)
            .signUp(
              fullName: fullName,
              email: email,
              mobile: mobile,
              password: password,
            );

        if (!context.mounted) return;

        if (success) {
          context.go('/verify-email');
        } else {
          final message = ref
                  .read(authControllerProvider)
                  .asData
                  ?.value
                  .error ??
              'Registration failed. Please try again.';

          _showMessage(context, message);
        }
      },
      onLogin: () => context.go('/login'),
    );
  }
}

class _VerifyEmailRoute extends ConsumerWidget {
  const _VerifyEmailRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).asData?.value;
    final email = auth?.pendingVerificationEmail;

    if (email == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No pending email verification found.'),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Register again'),
              ),
            ],
          ),
        ),
      );
    }

    return VerifyEmailScreen(
      email: email,
      isLoading: auth?.isLoading ?? false,
      onVerify: (code) async {
        final success = await ref
            .read(authControllerProvider.notifier)
            .confirmSignUp(
              email: email,
              confirmationCode: code,
            );

        if (!context.mounted) return;

        if (success) {
          context.go('/login');
          _showMessage(context, 'Email verified. Please sign in.');
        } else {
          final message = ref
                  .read(authControllerProvider)
                  .asData
                  ?.value
                  .error ??
              'Email verification failed.';

          _showMessage(context, message);
        }
      },
      onResendCode: () async {
        final success = await ref
            .read(authControllerProvider.notifier)
            .resendSignUpCode(email: email);

        if (!context.mounted) return;

        _showMessage(
          context,
          success
              ? 'A new verification code has been sent.'
              : ref.read(authControllerProvider).asData?.value.error ??
                  'Could not resend verification code.',
        );
      },
      onEditEmail: () => context.go('/register'),
    );
  }
}

class _ForgotPasswordRoute extends ConsumerWidget {
  const _ForgotPasswordRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).asData?.value;

    return ForgotPasswordScreen(
      isLoading: auth?.isLoading ?? false,
      onSendResetCode: (email) async {
        final success = await ref
            .read(authControllerProvider.notifier)
            .resetPassword(email: email);

        if (!context.mounted) return;

        if (success) {
          context.go('/reset-password');
        } else {
          _showMessage(
            context,
            ref.read(authControllerProvider).asData?.value.error ??
                'Could not send password reset code.',
          );
        }
      },
      onBackToLogin: () => context.go('/login'),
    );
  }
}

class _ResetPasswordRoute extends ConsumerWidget {
  const _ResetPasswordRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).asData?.value;
    final email = auth?.pendingPasswordResetEmail;

    if (email == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/forgot-password'),
            child: const Text('Request a password reset code'),
          ),
        ),
      );
    }

    return ResetPasswordScreen(
      isLoading: auth?.isLoading ?? false,
      onResetPassword: ({
        required String code,
        required String newPassword,
      }) async {
        final success = await ref
            .read(authControllerProvider.notifier)
            .confirmResetPassword(
              email: email,
              newPassword: newPassword,
              confirmationCode: code,
            );

        if (!context.mounted) return;

        if (success) {
          context.go('/login');
          _showMessage(context, 'Password updated. Please sign in.');
        } else {
          _showMessage(
            context,
            ref.read(authControllerProvider).asData?.value.error ??
                'Password reset failed.',
          );
        }
      },
      onResendCode: () async {
        final success = await ref
            .read(authControllerProvider.notifier)
            .resetPassword(email: email);

        if (!context.mounted) return;

        _showMessage(
          context,
          success
              ? 'A new password reset code has been sent.'
              : ref.read(authControllerProvider).asData?.value.error ??
                  'Could not resend reset code.',
        );
      },
      onBack: () => context.go('/forgot-password'),
    );
  }
}
