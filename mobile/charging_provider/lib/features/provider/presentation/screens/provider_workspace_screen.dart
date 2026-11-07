
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../bookings/presentation/screens/booking_details_screen.dart';
import '../../../bookings/presentation/screens/bookings_screen.dart';
import '../../../dashboard/presentation/screens/provider_dashboard_screen.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../stations/presentation/screens/add_edit_station_screen.dart';
import '../../../stations/presentation/screens/my_stations_screen.dart';
import '../../../stations/presentation/screens/station_details_screen.dart';
import '../../../availability/presentation/screens/station_availability_screen.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../../profile/presentation/screens/edit_provider_profile_screen.dart';
import '../../data/provider_api_providers.dart';

class ProviderWorkspaceScreen extends ConsumerStatefulWidget {
  const ProviderWorkspaceScreen({super.key});

  @override
  ConsumerState<ProviderWorkspaceScreen> createState() =>
      _ProviderWorkspaceScreenState();
}

class _ProviderWorkspaceScreenState
    extends ConsumerState<ProviderWorkspaceScreen> {
  int _selectedTab = 0;
  bool _processing = false;

  Map<String, dynamic>? _selectedBooking;

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _string(dynamic value, [String fallback = '']) {
    return value?.toString() ?? fallback;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(_string(value));
    if (date == null) return 'Date unavailable';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse(_string(value));
    if (date == null) return '--:--';

    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void _refresh() {
    ref.invalidate(myProviderStationsProvider);
    ref.invalidate(myProviderBookingsProvider);
  }

  Future<void> _editProfile() async {
    final profile = ref.read(providerProfileProvider).asData?.value;

    if (profile == null) {
      _message('Provider profile could not be loaded.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProviderProfileScreen(
          profile: profile,
          onSave: (updatedProfile) async {
            await ref
                .read(providerProfileProvider.notifier)
                .saveProfile(updatedProfile, isNew: false);

            if (mounted) {
              _message('Profile updated successfully.');
            }
          },
        ),
      ),
    );
  }

  Future<void> _manageAvailability(
    Map<String, dynamic> station,
  ) async {
    final stationId = _string(station['id']);
    if (stationId.isEmpty) return;

    try {
      final rawWindows = await ref
          .read(providerApiProvider)
          .getAvailability(stationId);
      final windows = rawWindows
          .map((window) {
            final start = DateTime.tryParse(_string(window['startTime']));
            final end = DateTime.tryParse(_string(window['endTime']));
            if (start == null || end == null) return null;
            return AvailabilityWindow(
              id: _string(window['id']),
              startTime: start.toLocal(),
              endTime: end.toLocal(),
            );
          })
          .whereType<AvailabilityWindow>()
          .toList();

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StationAvailabilityScreen(
            stationId: stationId,
            stationName: _string(station['stationName']),
            windows: windows,
            onBack: () => Navigator.of(context).pop(),
            onAddWindow: ({
              required startTime,
              required endTime,
            }) async {
              await ref.read(providerApiProvider).createAvailability(
                    stationId,
                    startTime: startTime,
                    endTime: endTime,
                  );
              if (mounted) Navigator.of(context).pop();
              await _manageAvailability(station);
            },
            onUpdateWindow: ({
              required windowId,
              required startTime,
              required endTime,
            }) async {
              await ref.read(providerApiProvider).updateAvailability(
                    stationId,
                    windowId,
                    startTime: startTime,
                    endTime: endTime,
                  );
              if (mounted) Navigator.of(context).pop();
              await _manageAvailability(station);
            },
            onDeleteWindow: (windowId) async {
              await ref.read(providerApiProvider).deleteAvailability(
                    stationId,
                    windowId,
                  );
              if (mounted) Navigator.of(context).pop();
              await _manageAvailability(station);
            },
          ),
        ),
      );
    } catch (error) {
      _message('Could not load availability: $error');
    }

  }

  Future<void> _openStationDetails(
    Map<String, dynamic> station,
  ) async {
    final stationId = _string(station['id']);
    if (stationId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StationDetailsScreen(
          station: StationDetailsData(
            id: stationId,
            stationName: _string(station['stationName']),
            providerType: _string(station['providerType']),
            accessType: _string(station['accessType'], 'PUBLIC'),
            address: _string(station['address']),
            connectorType: _string(station['connectorType']),
            powerKw: _double(station['powerKw']),
            pricePerKwh: station['pricePerKwh'] == null
                ? null
                : _double(station['pricePerKwh']),
            isActive: station['active'] == true,
          ),
          onBack: () => Navigator.of(context).pop(),
          onEditStation: () {
            Navigator.of(context).pop();
            _openStationForm(station);
          },
          onManageAvailability: () {
            Navigator.of(context).pop();
            _manageAvailability(station);
          },
          onViewBookings: () {
            Navigator.of(context).pop();
            setState(() => _selectedTab = 2);
          },
          onSetActive: (active) async {
            await _toggleStation(stationId, active);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await ref.read(authControllerProvider.notifier).signOut();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      _message('Unable to log out: $error');
    }
  }

  Future<void> _decideBooking(
    String bookingId,
    bool accepted,
  ) async {
    if (_processing) return;

    setState(() => _processing = true);

    try {
      final api = ref.read(providerApiProvider);

      if (accepted) {
        await api.confirmBooking(bookingId);
      } else {
        await api.rejectBooking(bookingId);
      }

      _refresh();

      if (_selectedBooking?['id']?.toString() == bookingId) {
        final updated = Map<String, dynamic>.from(_selectedBooking!);
        updated['status'] = accepted ? 'CONFIRMED' : 'REJECTED';

        setState(() {
          _selectedBooking = updated;
        });
      }

      _message(
        accepted
            ? 'Booking confirmed successfully.'
            : 'Booking rejected successfully.',
      );
    } catch (error) {
      _message('Booking update failed: $error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }


  Future<void> _openBooking(String bookingId) async {
    if (_processing) return;

    try {
      final bookings = await ref.read(myProviderBookingsProvider.future);

      final matches = bookings.where(
        (booking) => booking['id']?.toString() == bookingId,
      );

      if (matches.isEmpty) {
        _message('Booking not found. Refresh and try again.');
        return;
      }

      final booking = Map<String, dynamic>.from(matches.first);

      // Restore session state from the backend.
      final session = await ref
          .read(providerApiProvider)
          .getBookingSession(bookingId);

      if (session != null) {
        booking['_sessionId'] = session['id']?.toString();
        booking['_sessionStatus'] =
            session['status']?.toString().toUpperCase();
        booking['_sessionStarted'] =
            booking['_sessionStatus'] == 'IN_PROGRESS';

        booking['_finalCost'] = session['finalCost'];
        booking['_energyConsumedKwh'] = session['energyConsumedKwh'];
      } else {
        booking['_sessionId'] = null;
        booking['_sessionStatus'] = null;
        booking['_sessionStarted'] = false;
        booking['_finalCost'] = null;
        booking['_energyConsumedKwh'] = null;
      }

    if (!mounted) return;

      setState(() => _selectedBooking = booking);
    } catch (error) {
      _message('Could not load booking session: $error');
    }
  }



  Future<void> _startSession() async {
    final booking = _selectedBooking;
    if (booking == null || _processing) return;

    final status = _string(booking['status']).toUpperCase();

    if (status != 'CONFIRMED') {
      _message('Only confirmed bookings can start a charging session.');
      return;
    }

    setState(() => _processing = true);

    try {
      final api = ref.read(providerApiProvider);

      final session = await api.startSession(
        booking['id'].toString(),
      );

      final sessionId = session['id']?.toString();

      if (sessionId == null || sessionId.isEmpty) {
        throw Exception('The server did not return a session ID.');
      }

      if (!mounted) return;

      setState(() {
        _selectedBooking = {
          ...booking,
          '_sessionId': sessionId,
          '_sessionStarted': true,
          '_sessionStatus': 'IN_PROGRESS',
        };
      });

      _message('Charging session started.');
    } catch (error) {
      _message('Could not start session: $error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }



  Future<void> _completeSession() async {
    final booking = _selectedBooking;
    if (booking == null || _processing) return;

    final sessionId = booking['_sessionId']?.toString();

    if (sessionId == null || sessionId.isEmpty) {
      _message('No active session ID was found.');
      return;
    }

    final energyController = TextEditingController();

    final energy = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete Charging Session'),
          content: TextField(
            controller: energyController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Energy consumed (kWh)',
              hintText: 'e.g. 18.5',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(
                  energyController.text.trim(),
                );

                if (value == null || !value.isFinite || value <= 0) {
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );

    energyController.dispose();

    if (energy == null) return;

    setState(() => _processing = true);

    try {
      final api = ref.read(providerApiProvider);

      final completedSession = await api.completeSession(
        sessionId: sessionId,
        energyConsumedKwh: energy,
      );

      if (!mounted) return;

      setState(() {
        _selectedBooking = {
          ...booking,
          '_sessionId': sessionId,
          '_sessionStarted': false,
          '_sessionStatus':
              completedSession['status']?.toString().toUpperCase(),
          '_finalCost': _double(completedSession['finalCost']),
          '_energyConsumedKwh':
              _double(completedSession['energyConsumedKwh']),
        };
      });

      _refresh();
      _message('Charging session completed.');
    } catch (error) {
      _message('Could not complete session: $error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }


  void _openStationForm([Map<String, dynamic>? station]) {
    final editing = station != null;

    final initial = editing
        ? StationFormData(
            id: _string(station['id']),
            stationName: _string(station['stationName']),
            providerType: _string(station['providerType']),
            accessType: _string(station['accessType'], 'PUBLIC'),
            address: _string(station['address']),
            latitude: _double(station['latitude']),
            longitude: _double(station['longitude']),
            connectorType: _string(station['connectorType']),
            powerKw: _double(station['powerKw']),
            pricePerKwh: _double(station['pricePerKwh']),
            isActive: station['active'] == true,
          )
        : null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditStationScreen(
          initialStation: initial,
          isSaving: _processing,
          onCancel: () => Navigator.of(context).pop(),
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
          }) {
            _saveStation(
              id: initial?.id,
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
        ),
      ),
    );
  }

  Future<void> _saveStation({
    String? id,
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
    if (_processing) return;

    setState(() => _processing = true);

    try {
      final api = ref.read(providerApiProvider);

      final body = {
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
      };

      if (id == null) {
        await api.createStation(body);

        final currentProfile = ref.read(providerProfileProvider).asData?.value;

        if (currentProfile != null &&
            currentProfile.onboardingCompleted != true) {
          // Backend verifies that the provider now has at least one station.
          await ref
              .read(onboardingControllerProvider.notifier)
              .saveProgress(
                step: 3,
                completed: true,
              );

          await ref
              .read(providerProfileProvider.notifier)
              .refreshProfile();
        }
      } else {
        await api.updateStation(id, body);
        await api.updateStationStatus(id, isActive);
      }

      _refresh();

      if (mounted) {
        Navigator.of(context).pop();
        _message(id == null ? 'Station created.' : 'Station updated.');
      }
    } catch (error) {
      _message('Station save failed: $error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _toggleStation(
    String id,
    bool active,
  ) async {
    try {
      await ref.read(providerApiProvider).updateStationStatus(id, active);
      _refresh();
      _message(active ? 'Station activated.' : 'Station deactivated.');
    } catch (error) {
      _message('Could not update station status: $error');
    }
  }

  Future<void> _deactivateStation(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate station?'),
        content: const Text(
          'This station will no longer be available to vehicle owners.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(providerApiProvider).deactivateStation(id);
      _refresh();
      _message('Station deactivated.');
    } catch (error) {
      _message('Could not deactivate station: $error');
    }
  }

  Widget _loading() {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _errorState(Object error, VoidCallback retry) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 12),
              const Text('Unable to load provider data.'),
              const SizedBox(height: 6),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(providerProfileProvider);
    final stationsState = ref.watch(myProviderStationsProvider);
    final bookingsState = ref.watch(myProviderBookingsProvider);

    if (profileState.isLoading ||
        stationsState.isLoading ||
        bookingsState.isLoading) {
      return _loading();
    }

    if (profileState.hasError) {
      return _errorState(
        profileState.error!,
        () => ref.invalidate(providerProfileProvider),
      );
    }

    if (stationsState.hasError) {
      return _errorState(
        stationsState.error!,
        () => ref.invalidate(myProviderStationsProvider),
      );
    }

    if (bookingsState.hasError) {
      return _errorState(
        bookingsState.error!,
        () => ref.invalidate(myProviderBookingsProvider),
      );
    }

    final profile = profileState.asData?.value;
    final stations = stationsState.asData?.value ?? [];
    final bookings = bookingsState.asData?.value ?? [];

    if (profile == null) {
      return _errorState(
        Exception('Provider profile was not found.'),
        () => ref.invalidate(providerProfileProvider),
      );
    }

    if (profile.onboardingCompleted != true && stations.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Complete Provider Setup'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.ev_station_rounded,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Add your first charging station',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your provider profile is saved. '
                  'Add at least one charging station to complete setup.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : () => _openStationForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Charging Station'),
                  ),
                ),
                TextButton(
                  onPressed: _logout,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_selectedBooking != null) {
      final booking = _selectedBooking!;

      final stationId = _string(booking['stationId']);
      final stationMatches = stations.where(
        (station) => station['id']?.toString() == stationId,
      );
      final station = stationMatches.isEmpty
          ? <String, dynamic>{}
          : stationMatches.first;

      final start = DateTime.tryParse(_string(booking['startTime']));
      final end = DateTime.tryParse(_string(booking['endTime']));

      return BookingDetailsScreen(
        booking: BookingDetailsData(
          id: _string(booking['id']),
          status: _string(booking['status']),
          stationName: _string(
            booking['_stationName'],
            'Charging station',
          ),
          stationAddress: _string(booking['_stationAddress']),
          connectorType: _string(
            booking['_connectorType'],
            _string(station['connectorType']),
          ),
          powerKw: _double(
            booking['_powerKw'] ?? station['powerKw'],
          ),
          bookingDate: _formatDate(booking['startTime']),
          startTime: start == null ? '--:--' : _formatTime(start.toIso8601String()),
          endTime: end == null ? '--:--' : _formatTime(end.toIso8601String()),
          estimatedCost: _double(booking['estimatedCost']),
          vehicleId: _string(booking['vehicleId']),
          isSessionStarted: booking['_sessionStarted'] == true,
          sessionStatus: booking['_sessionStatus']?.toString(),
          finalCost: booking['_finalCost'] == null
              ? null
              : _double(booking['_finalCost']),
          energyConsumedKwh: booking['_energyConsumedKwh'] == null
              ? null
              : _double(booking['_energyConsumedKwh']),
        ),
        isProcessing: _processing,
        onBack: () => setState(() => _selectedBooking = null),
        onConfirmBooking: () => _decideBooking(
          _string(booking['id']),
          true,
        ),
        onRejectBooking: () => _decideBooking(
          _string(booking['id']),
          false,
        ),
        onStartSession: () {
          if (booking['_sessionStarted'] == true) {
            _completeSession();
          } else {
            _startSession();
          }
        },
      );
    }

    switch (_selectedTab) {
      case 0:
        final recent = bookings.take(5).map((booking) {
          final start = DateTime.tryParse(
            _string(booking['startTime']),
          );

          final end = DateTime.tryParse(
            _string(booking['endTime']),
          );

          return ProviderBookingSummary(
            id: _string(booking['id']),
            stationName: _string(
              booking['_stationName'],
              'Charging station',
            ),
            date: _formatDate(booking['startTime']),
            time: '${start == null ? '--:--' : _formatTime(start.toIso8601String())}'
                ' - ${end == null ? '--:--' : _formatTime(end.toIso8601String())}',
            status: _string(booking['status']),
            estimatedCost: booking['estimatedCost'] == null
                ? null
                : _double(booking['estimatedCost']),
          );
        }).toList();

        return ProviderDashboardScreen(
          providerName: profile.fullName,
          totalStations: stations.length,
          activeStations: stations.where((s) => s['active'] == true).length,
          pendingBookings: bookings
              .where((b) => _string(b['status']).toUpperCase() == 'PENDING')
              .length,
          recentBookings: recent,
          onAddStation: () => _openStationForm(),

          onOpenBooking: _openBooking,
          onBookingDecision: _decideBooking,
          onNavigationChanged: (index) {
            setState(() => _selectedTab = index);
          },
        );

      case 1:
        final stationItems = stations.map((station) {
          return ProviderStationSummary(
            id: _string(station['id']),
            stationName: _string(station['stationName']),
            providerType: _string(station['providerType']),
            address: _string(station['address']),
            connectorType: _string(station['connectorType']),
            powerKw: _double(station['powerKw']),
            pricePerKwh: _double(station['pricePerKwh']),
            isActive: station['active'] == true,
          );
        }).toList();

        return MyStationsScreen(
          onToggleStation: _toggleStation,
          onDeactivateStation: _deactivateStation,
          stations: stationItems,
          onOpenStation: (id) {
            final matches = stations.where(
              (station) => station['id']?.toString() == id,
            );

            if (matches.isNotEmpty) {
              _openStationDetails(matches.first);
            }
          },
          onManageAvailability: (id) {
            final matches = stations.where(
              (station) => station['id']?.toString() == id,
            );
            if (matches.isNotEmpty) {
              _manageAvailability(matches.first);
            }
          },
          onAddStation: () => _openStationForm(),
          onNavigationChanged: (index) {
            setState(() => _selectedTab = index);
          },
        );

      case 2:
        final bookingItems = bookings.map((booking) {
          final start = DateTime.tryParse(
            _string(booking['startTime']),
          );
          final end = DateTime.tryParse(
            _string(booking['endTime']),
          );

          return ProviderBooking(
            id: _string(booking['id']),
            stationName: _string(
              booking['_stationName'],
              'Charging station',
            ),
            date: _formatDate(booking['startTime']),
            startTime: start == null
                ? '--:--'
                : _formatTime(start.toIso8601String()),
            endTime: end == null
                ? '--:--'
                : _formatTime(end.toIso8601String()),
            estimatedCost: _double(booking['estimatedCost']),
            status: _string(booking['status']),
          );
        }).toList();

        return BookingsScreen(
          bookings: bookingItems,
          onOpenBooking: _openBooking,
          onBookingDecision: _decideBooking,
          onNavigationChanged: (index) {
            setState(() => _selectedTab = index);
          },
        );

      case 3:
        return ProviderProfileScreen(
          profile: ProviderProfileData(
            fullName: profile.fullName,
            email: profile.email,
            mobileNumber: profile.phone,
            businessName: profile.businessName,
            providerType: profile.providerType,
            address: profile.address,
          ),
          onEditProfile: _editProfile,
          onLogout: _logout,
          onNavigationChanged: (index) {
            setState(() => _selectedTab = index);
          },
        );

      default:
        return _loading();
    }
  }
}
