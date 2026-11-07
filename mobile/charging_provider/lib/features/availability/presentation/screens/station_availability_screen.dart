
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AvailabilityWindow {
  const AvailabilityWindow({
    required this.id,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final DateTime startTime;
  final DateTime endTime;
}

class _WindowDraft {
  const _WindowDraft({
    required this.startTime,
    required this.endTime,
  });

  final DateTime startTime;
  final DateTime endTime;
}

class StationAvailabilityScreen extends StatefulWidget {
  const StationAvailabilityScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.windows,
    required this.onAddWindow,
    required this.onUpdateWindow,
    required this.onDeleteWindow,
    required this.onBack,
    this.isSaving = false,
  });

  final String stationId;
  final String stationName;
  final List<AvailabilityWindow> windows;

  final void Function({
    required String startTime,
    required String endTime,
  }) onAddWindow;

  final void Function({
    required String windowId,
    required String startTime,
    required String endTime,
  }) onUpdateWindow;

  final ValueChanged<String> onDeleteWindow;
  final VoidCallback onBack;
  final bool isSaving;

  @override
  State<StationAvailabilityScreen> createState() =>
      _StationAvailabilityScreenState();
}

class _StationAvailabilityScreenState
    extends State<StationAvailabilityScreen> {
  String _displayDateTime(BuildContext context, DateTime value) {
    final date = MaterialLocalizations.of(context).formatMediumDate(value);
    final time = TimeOfDay.fromDateTime(value).format(context);
    return '$date, $time';
  }

  Future<_WindowDraft?> _showWindowDialog({
    AvailabilityWindow? existingWindow,
  }) async {
    final now = DateTime.now();
    DateTime startTime = existingWindow?.startTime ??
        DateTime(now.year, now.month, now.day + 1, 9);
    DateTime endTime = existingWindow?.endTime ??
        DateTime(now.year, now.month, now.day + 1, 18);

    return showDialog<_WindowDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final theme = Theme.of(context);

            return AlertDialog(
              title: Text(
                existingWindow == null
                    ? 'Add Availability'
                    : 'Edit Availability',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Start date and time',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                        initialDate: startTime,
                      );
                      if (date != null) {
                        dialogSetState(() {
                          startTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            startTime.hour,
                            startTime.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_displayDateTime(context, startTime)),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Start Time',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showTimePicker(
                        context: dialogContext,
                        initialTime: TimeOfDay.fromDateTime(startTime),
                      );

                      if (selected != null) {
                        dialogSetState(() {
                          startTime = DateTime(
                            startTime.year,
                            startTime.month,
                            startTime.day,
                            selected.hour,
                            selected.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(TimeOfDay.fromDateTime(startTime).format(context)),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'End date and time',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        firstDate: startTime,
                        lastDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                        initialDate: endTime,
                      );
                      if (date != null) {
                        dialogSetState(() {
                          endTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            endTime.hour,
                            endTime.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_displayDateTime(context, endTime)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showTimePicker(
                        context: dialogContext,
                        initialTime: TimeOfDay.fromDateTime(endTime),
                      );

                      if (selected != null) {
                        dialogSetState(() {
                          endTime = DateTime(
                            endTime.year,
                            endTime.month,
                            endTime.day,
                            selected.hour,
                            selected.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text(TimeOfDay.fromDateTime(endTime).format(context)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!endTime.isAfter(startTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'End time must be later than start time.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      _WindowDraft(
                        startTime: startTime,
                        endTime: endTime,
                      ),
                    );
                  },
                  child: Text(
                    existingWindow == null ? 'Add' : 'Save',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addWindow() async {
    final draft = await _showWindowDialog();

    if (draft == null || !mounted) return;

    widget.onAddWindow(
      startTime: draft.startTime.toUtc().toIso8601String(),
      endTime: draft.endTime.toUtc().toIso8601String(),
    );
  }

  Future<void> _editWindow(AvailabilityWindow window) async {
    final draft = await _showWindowDialog(
      existingWindow: window,
    );

    if (draft == null || !mounted) return;

    widget.onUpdateWindow(
      windowId: window.id,
      startTime: draft.startTime.toUtc().toIso8601String(),
      endTime: draft.endTime.toUtc().toIso8601String(),
    );
  }

  Future<void> _deleteWindow(AvailabilityWindow window) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Availability?'),
          content: Text(
            'Delete the availability window from '
            '${_displayDateTime(context, window.startTime)} to '
            '${_displayDateTime(context, window.endTime)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      widget.onDeleteWindow(window.id);
    }
  }

  Map<String, List<AvailabilityWindow>> _groupedWindows(
    BuildContext context,
  ) {
    final result = <String, List<AvailabilityWindow>>{};
    for (final window in widget.windows) {
      final day = MaterialLocalizations.of(context)
          .formatMediumDate(window.startTime);
      result.putIfAbsent(day, () => []).add(window);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final groupedWindows = _groupedWindows(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Station Availability'),
      ),

      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Station identity
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          height: 46,
                          width: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.ev_station_rounded,
                            color: AppColors.secondary,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Managing Availability',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.stationName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Summary
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Availability Windows',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.windows.length} configured',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Availability list
            if (groupedWindows.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyAvailability(
                  onAdd: widget.isSaving ? null : _addWindow,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final day = groupedWindows.keys.elementAt(index);
                      final windows = groupedWindows[day]!;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  height: 34,
                                  width: 34,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today_rounded,
                                    color: AppColors.secondary,
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  day,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${windows.length} '
                                  '${windows.length == 1 ? 'window' : 'windows'}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            ...windows.map(
                              (window) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AvailabilityCard(
                                  window: window,
                                  startLabel: _displayDateTime(
                                    context,
                                    window.startTime,
                                  ),
                                  endLabel: _displayDateTime(
                                    context,
                                    window.endTime,
                                  ),
                                  onEdit: widget.isSaving
                                      ? null
                                      : () => _editWindow(window),
                                  onDelete: widget.isSaving
                                      ? null
                                      : () => _deleteWindow(window),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: groupedWindows.length,
                  ),
                ),
              ),
          ],
        ),
      ),

      // Add availability
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.isSaving ? null : _addWindow,
        icon: widget.isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: Text(
          widget.isSaving ? 'Saving...' : 'Add Availability',
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Availability card
// --------------------------------------------------

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.window,
    required this.startLabel,
    required this.endLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final AvailabilityWindow window;
  final String startLabel;
  final String endLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$startLabel – $endLabel',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Edit availability',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 19,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete availability',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: colors.error,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Text(
                  'Availability uses the server calendar timestamps',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// Empty state
// --------------------------------------------------

class _EmptyAvailability extends StatelessWidget {
  const _EmptyAvailability({
    required this.onAdd,
  });

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 54,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No availability configured',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add time windows when your charging station '
              'is available for bookings.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Availability'),
            ),
          ],
        ),
      ),
    );
  }
}
