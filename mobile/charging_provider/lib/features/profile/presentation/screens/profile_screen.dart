
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ProviderProfileData {
  const ProviderProfileData({
    required this.fullName,
    required this.email,
    this.mobileNumber,
    this.businessName,
    this.providerType,
    this.address,
  });

  final String fullName;
  final String email;
  final String? mobileNumber;
  final String? businessName;
  final String? providerType;
  final String? address;
}

class ProviderProfileScreen extends StatelessWidget {
  const ProviderProfileScreen({
    super.key,
    required this.profile,
    required this.onEditProfile,
    required this.onLogout,
    required this.onNavigationChanged,
    this.isLoggingOut = false,
  });

  final ProviderProfileData profile;

  final VoidCallback onEditProfile;
  final VoidCallback onLogout;
  final ValueChanged<int> onNavigationChanged;

  final bool isLoggingOut;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log Out?'),
          content: const Text(
            'Are you sure you want to log out of your provider account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.ev_station_rounded,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EV Fleet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'PROVIDER PROFILE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile identity
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.18),
                        child: Text(
                          _initials(profile.fullName),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        profile.fullName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        profile.email,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),

                      if (profile.mobileNumber != null &&
                          profile.mobileNumber!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          profile.mobileNumber!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'CHARGER PROVIDER',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onEditProfile,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Personal information
              _SectionHeading(title: 'Account Information'),

              const SizedBox(height: 10),

              Card(
                child: Column(
                  children: [
                    _ProfileInfoTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Full Name',
                      value: profile.fullName,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _ProfileInfoTile(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: profile.email,
                    ),
                    if (profile.mobileNumber != null &&
                        profile.mobileNumber!.isNotEmpty) ...[
                      const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      _ProfileInfoTile(
                        icon: Icons.phone_outlined,
                        label: 'Mobile Number',
                        value: profile.mobileNumber!,
                      ),
                    ],
                  ],
                ),
              ),

              // Provider information
              if ((profile.businessName != null &&
                      profile.businessName!.isNotEmpty) ||
                  (profile.providerType != null &&
                      profile.providerType!.isNotEmpty) ||
                  (profile.address != null &&
                      profile.address!.isNotEmpty)) ...[
                const SizedBox(height: 24),

                _SectionHeading(title: 'Provider Information'),

                const SizedBox(height: 10),

                Card(
                  child: Column(
                    children: [
                      if (profile.businessName != null &&
                          profile.businessName!.isNotEmpty)
                        _ProfileInfoTile(
                          icon: Icons.business_outlined,
                          label: 'Business Name',
                          value: profile.businessName!,
                        ),

                      if (profile.businessName != null &&
                          profile.businessName!.isNotEmpty &&
                          profile.providerType != null &&
                          profile.providerType!.isNotEmpty)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),

                      if (profile.providerType != null &&
                          profile.providerType!.isNotEmpty)
                        _ProfileInfoTile(
                          icon: Icons.category_outlined,
                          label: 'Provider Type',
                          value: profile.providerType!,
                        ),

                      if (profile.address != null &&
                          profile.address!.isNotEmpty) ...[
                        if ((profile.businessName != null &&
                                profile.businessName!.isNotEmpty) ||
                            (profile.providerType != null &&
                                profile.providerType!.isNotEmpty))
                          const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                        _ProfileInfoTile(
                          icon: Icons.location_on_outlined,
                          label: 'Business Address',
                          value: profile.address!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Logout
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: isLoggingOut
                      ? null
                      : () => _confirmLogout(context),
                  icon: isLoggingOut
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(
                    isLoggingOut ? 'Logging Out...' : 'Log Out',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom navigation
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        onDestinationSelected: onNavigationChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.ev_station_outlined),
            selectedIcon: Icon(Icons.ev_station_rounded),
            label: 'Stations',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) {
      return 'P';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

// --------------------------------------------------
// Section heading
// --------------------------------------------------

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

// --------------------------------------------------
// Profile information tile
// --------------------------------------------------

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
