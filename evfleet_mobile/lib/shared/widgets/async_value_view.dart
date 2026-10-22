import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_handler.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';

/// Renders an [AsyncValue] with explicit loading / error / data states so
/// every list and detail screen behaves consistently.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.empty,
    this.loadingLabel,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  /// When provided and [builder] receives an empty collection, this widget is
  /// shown instead (e.g. an empty state for lists).
  final Widget Function()? empty;
  final String? loadingLabel;

  bool _isEmpty(T data) {
    if (data is Iterable) return data.isEmpty;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (value.isLoading && !value.hasValue) {
      return AppLoading(label: loadingLabel);
    }

    final error = value.error;
    if (error != null && !value.hasValue) {
      return AppErrorView(message: errorMessageOf(error), onRetry: onRetry);
    }

    final data = value.valueOrNull;
    if (data == null) {
      return const AppLoading();
    }

    if (empty != null && _isEmpty(data)) return empty!();
    return builder(data);
  }
}
