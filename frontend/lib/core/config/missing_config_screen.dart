import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'app_config.dart';

/// Shown at startup when public configuration is incomplete.
///
/// It lists each missing `--dart-define` key with the AWS Console location the
/// value comes from, so a fresh clone fails loudly and usefully instead of
/// appearing to sign in and then erroring on an unauthenticated request.
///
/// The developer can still continue: the screen is a diagnostic, not a hard
/// block, because signed-out browsing of the public station list is allowed by
/// the backend.
class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({
    super.key,
    required this.issues,
    required this.onContinue,
    this.onRetry,
  });

  final List<ConfigIssue> issues;

  /// Dismisses the screen and continues into the app.
  final VoidCallback onContinue;

  /// Re-reads configuration (const values, so this mainly re-renders).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_outlined,
                      color: AppColors.warning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Configuration needed',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This build is missing public configuration values. '
                    'Authentication cannot work until they are provided.',
                    style: TextStyle(color: AppColors.inkSoft, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  ...issues.map(_issueCard),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to fix',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandDark,
                          ),
                        ),
                        SizedBox(height: 6),
                        SelectableText(
                          '1. Copy .env.example to .env\n'
                          '2. Fill in the values listed above\n'
                          '3. flutter run --dart-define-from-file=.env',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            height: 1.5,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Never put AWS secret keys, database passwords or '
                          'Cognito client secrets in the client.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      if (onRetry != null)
                        OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Re-check'),
                        ),
                      if (onRetry != null) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: onContinue,
                          child: const Text('Continue anyway'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _issueCard(ConfigIssue issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 16,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  issue.key,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            issue.problem,
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          Text(
            'Where to get it: ${issue.source}',
            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
