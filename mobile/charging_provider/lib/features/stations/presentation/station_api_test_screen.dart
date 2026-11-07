import 'package:ev_fleet_charging_provider/features/stations/providers/station_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class StationApiTestScreen extends ConsumerWidget {
  const StationApiTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(publicStationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Station API Test'),
      ),
      body: stationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('API Error:\n$error'),
          ),
        ),
        data: (stations) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Successfully connected to AWS!\n'
                  'Stations received: ${stations.length}',
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: stations.isEmpty
                    ? const Center(
                        child: Text('No stations available yet.'),
                      )
                    : ListView.builder(
                        itemCount: stations.length,
                        itemBuilder: (context, index) {
                          final station = stations[index];

                          return ListTile(
                            title: Text(station.stationName),
                            subtitle: Text(
                              station.address ?? 'No address',
                            ),
                            trailing: Text(
                              '${station.powerKw ?? 0} kW',
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}