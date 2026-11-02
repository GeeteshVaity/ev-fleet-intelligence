import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(
        onLogin: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication will be connected in Phase 3.'),
            ),
          );
        },
        onForgotPassword: () => context.go('/forgot-password'),
        onCreateAccount: () => context.go('/register'),
      ),
    ),

    GoRoute(
      path: '/register',
      builder: (context, state) => RegisterScreen(
        onRegister: ({
          required String fullName,
          required String email,
          required String mobile,
          required String password,
        }) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration will be connected in Phase 3.'),
            ),
          );
        },
        onLogin: () => context.go('/login'),
      ),
    ),

    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => ForgotPasswordScreen(
        onSendResetCode: (email) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password recovery for $email will be connected in Phase 3.'),
            ),
          );
        },
        onBackToLogin: () => context.go('/login'),
      ),
    ),
  ],
);