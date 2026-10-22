import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Loading/splash screen: waits for the minimum display time **and** for the
/// session restore, then routes to onboarding, welcome or the main app.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _minTimeElapsed = false;
  bool _onboardingSeen = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _onboardingSeen = prefs.getBool(AppConstants.onboardingSeenKey) ?? false;
    } catch (_) {
      // Preferences unavailable → treat as "not seen" (safe default).
    }

    await Future<void>.delayed(AppConstants.splashMinimum);
    if (mounted) setState(() => _minTimeElapsed = true);
    _resolve();
  }

  void _resolve() {
    if (_navigated || !mounted || !_minTimeElapsed) return;

    final status = ref.read(authProvider).status;
    if (status == AuthStatus.restoring) return;

    _navigated = true;
    if (status == AuthStatus.authenticated) {
      context.go(RoutePaths.home);
    } else {
      context.go(_onboardingSeen ? RoutePaths.welcome : RoutePaths.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) => _resolve());

    return Scaffold(
      backgroundColor: AppColors.brand,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: AppColors.lime,
                size: 46,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'EV Fleet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppConstants.appTagline,
              style: AppTextStyles.bodySoft.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: AppColors.lime,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
