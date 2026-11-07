import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/data/models/provider_profile_model.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../stations/presentation/screens/add_edit_station_screen.dart';
import '../providers/onboarding_providers.dart';
import '../../../provider/data/provider_api_providers.dart';
import 'provider_setup_screen.dart';

class ProviderEntryScreen extends ConsumerStatefulWidget {
  const ProviderEntryScreen({super.key});

  @override
  ConsumerState<ProviderEntryScreen> createState() =>
      _ProviderEntryScreenState();
}

class _ProviderEntryScreenState
    extends ConsumerState<ProviderEntryScreen> {
  bool _saving = false;
  bool _showStationForm = false;

  void _message(String value) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _error(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _saveProfile({
    required String providerType,
    required String legalName,
    required String phone,
    required String address,
  }) async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final user = ref.read(authControllerProvider).asData?.value.user;

      if (user == null) {
        throw Exception('Your login session has expired.');
      }

      final existing = ref.read(providerProfileProvider).asData?.value;

      final profile = ProviderProfileModel(
        id: existing?.id,
        fullName: user.fullName?.trim().isNotEmpty == true
            ? user.fullName!.trim()
            : user.username,
        email: user.email ?? '',
        phone: phone,
        role: 'CHARGER_PROVIDER',
        businessName: legalName,
        providerType: providerType,
        address: address,
        onboardingCompleted: false,
        onboardingStep: 2,
      );

      await ref.read(providerProfileProvider.notifier).saveProfile(
            profile,
            isNew: existing == null,
          );

      await ref
          .read(onboardingControllerProvider.notifier)
          .saveProgress(step: 2);

      if (!mounted) return;

      setState(() {
        _showStationForm = true;
      });
    } catch (error) {
      _message(_error(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _createFirstStation({
    required String stationName,
    required String providerType,
    required String accessType,
    required String address,
    required double latitude,
    required double longitude,
    required String connectorType,
    required double powerKw,
    required double pricePerKwh,
    required bool isActive,
  }) async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final api = ref.read(providerApiProvider);

      await api.createStation({
        'stationName': stationName,
        'providerType': providerType,
        'accessType': accessType,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'connectorType': connectorType,
        'powerKw': powerKw,
        'pricePerKwh': pricePerKwh,
        'active': isActive,
      });

      await ref
          .read(onboardingControllerProvider.notifier)
          .saveProgress(
            step: 3,
            completed: true,
          );

      await ref.read(providerProfileProvider.notifier).refreshProfile();

      ref.invalidate(myProviderStationsProvider);
      ref.invalidate(myProviderBookingsProvider);

      if (!mounted) return;

      context.go('/home/dashboard');
    } catch (error) {
      _message(_error(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final profileState = ref.watch(providerProfileProvider);

    if (auth.isLoading || profileState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = auth.asData?.value.user;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profileState.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Provider Setup')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load your provider profile.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(providerProfileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = profileState.asData?.value;

    if (profile?.onboardingCompleted == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home/dashboard');
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showStationForm) {
      return AddEditStationScreen(
        isSaving: _saving,
        onCancel: () {
          setState(() => _showStationForm = false);
        },
        onSave: ({
          required String stationName,
          required String providerType,
          required String accessType,
          required String address,
          required double latitude,
          required double longitude,
          required String connectorType,
          required double powerKw,
          required double pricePerKwh,
          required bool isActive,
        }) async {
          await _createFirstStation(
            stationName: stationName,
            providerType: providerType,
            accessType: accessType,
            address: address,
            latitude: latitude,
            longitude: longitude,
            connectorType: connectorType,
            powerKw: powerKw,
            pricePerKwh: pricePerKwh,
            isActive: isActive,
          );
        },
      );
    }

    return ProviderSetupScreen(
      isLoading: _saving,
      onBack: () {
        _message('Complete provider setup to continue.');
      },
      onContinue: ({
        required String providerType,
        required String legalName,
        required String phone,
        required String address,
      }) async {
        await _saveProfile(
          providerType: providerType,
          legalName: legalName,
          phone: phone,
          address: address,
        );
      },
    );
  }
}