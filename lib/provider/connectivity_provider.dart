import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityState {
  final ConnectivityStatus status;
  final bool showReconnectMessage;

  const ConnectivityState({
    required this.status,
    this.showReconnectMessage = false,
  });

  bool get isOnline => status == ConnectivityStatus.online;
  bool get isOffline => status == ConnectivityStatus.offline;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    bool? showReconnectMessage,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      showReconnectMessage: showReconnectMessage ?? this.showReconnectMessage,
    );
  }
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final Connectivity _connectivity;
  StreamSubscription<dynamic>? _subscription;

  ConnectivityNotifier({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(const ConnectivityState(status: ConnectivityStatus.online)) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final initialResult = await _connectivity.checkConnectivity();
      _handleResult(initialResult);
    } catch (_) {
      // If the initial check fails, assume offline until proven otherwise.
      state = state.copyWith(status: ConnectivityStatus.offline);
    }

    _subscription = _connectivity.onConnectivityChanged.listen(_handleResult);
  }

  void _handleResult(dynamic result) {
    final List<ConnectivityResult> results;
    if (result is ConnectivityResult) {
      results = [result];
    } else if (result is List<ConnectivityResult>) {
      results = result;
    } else {
      return;
    }

    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      if (state.status != ConnectivityStatus.offline) {
        state = state.copyWith(
          status: ConnectivityStatus.offline,
          showReconnectMessage: false,
        );
      }
    } else {
      final wasOffline = state.status == ConnectivityStatus.offline;
      state = state.copyWith(
        status: ConnectivityStatus.online,
        showReconnectMessage: wasOffline,
      );
    }
  }

  void acknowledgeReconnectMessage() {
    if (state.showReconnectMessage) {
      state = state.copyWith(showReconnectMessage: false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});
