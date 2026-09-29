import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service responsible for monitoring network connectivity status.
/// Supports mock overrides for deterministic unit & integration testing.
class ConnectivityService {
  static ConnectivityService? _instance;
  final Connectivity _connectivity;
  
  // Test mock override
  bool? _mockIsConnected;
  StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService._internal({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  void _initSubscription() {
    if (_mockIsConnected != null) return;
    try {
      _subscription?.cancel();
    } catch (_) {}
    try {
      _subscription = _connectivity.onConnectivityChanged.listen(
        (results) {
          if (_mockIsConnected != null) return;
          final isOnline = _isResultsOnline(results);
          if (!_connectivityController.isClosed) {
            _connectivityController.add(isOnline);
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  factory ConnectivityService({Connectivity? connectivity}) {
    _instance ??= ConnectivityService._internal(connectivity: connectivity);
    return _instance!;
  }

  static ConnectivityService get instance => ConnectivityService();

  /// Stream of boolean connectivity states (true = online, false = offline)
  Stream<bool> get onConnectivityChanged {
    if (_connectivityController.isClosed) {
      _connectivityController = StreamController<bool>.broadcast();
    }
    if (_subscription == null && _mockIsConnected == null) {
      _initSubscription();
    }
    return _connectivityController.stream;
  }

  /// Check current connectivity status
  Future<bool> isConnected() async {
    if (_mockIsConnected != null) {
      return _mockIsConnected!;
    }
    try {
      final results = await _connectivity.checkConnectivity().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => [ConnectivityResult.none],
      );
      return _isResultsOnline(results);
    } catch (_) {
      return false;
    }
  }

  /// Sets a mock connectivity override for offline/online lifecycle testing
  void setMockIsConnected(bool? isConnected) {
    _mockIsConnected = isConnected;
    if (isConnected != null) {
      try {
        _subscription?.cancel();
      } catch (_) {}
      _subscription = null;
      if (_connectivityController.isClosed) {
        _connectivityController = StreamController<bool>.broadcast();
      }
      _connectivityController.add(isConnected);
    }
  }

  bool _isResultsOnline(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  }

  void resetForTesting() {
    _mockIsConnected = null;
    if (_connectivityController.isClosed) {
      _connectivityController = StreamController<bool>.broadcast();
      _initSubscription();
    }
  }

  void dispose() {
    _mockIsConnected = null;
    try {
      _subscription?.cancel();
    } catch (_) {}
    _subscription = null;
    if (!_connectivityController.isClosed) {
      _connectivityController.close();
    }
  }
}
