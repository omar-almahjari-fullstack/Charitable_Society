import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================
// NETWORK CONNECTIVITY SERVICE (خدمة مراقبة الاتصال وحالة الشبكة)
// ============================================================

class NetworkConnectivityService {
  static final NetworkConnectivityService _instance = NetworkConnectivityService._internal();
  factory NetworkConnectivityService() => _instance;
  NetworkConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineStreamController = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get isOnlineStream => _onlineStreamController.stream;

  StreamSubscription? _subscription;

  /// تهيئة وبدء الاستماع لتغيرات الشبكة
  void initialize() {
    _subscription?.cancel();
    _checkInitialStatus();
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final hasConnection = await _verifyActualInternet(results);
      if (_isOnline != hasConnection) {
        _isOnline = hasConnection;
        _onlineStreamController.add(_isOnline);
      }
    });
  }

  Future<void> _checkInitialStatus() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = await _verifyActualInternet(results);
    _onlineStreamController.add(_isOnline);
  }

  /// التحقق الفعلي من الوصول للإنترنت عبر فحص DNS حقيقي
  Future<bool> _verifyActualInternet(List<ConnectivityResult> results) async {
    if (results.contains(ConnectivityResult.none)) {
      return false;
    }
    try {
      final lookup = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final fallbackLookup = await InternetAddress.lookup('supabase.com').timeout(
          const Duration(seconds: 3),
        );
        return fallbackLookup.isNotEmpty && fallbackLookup[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  /// فحص مباشر سريع عند الطلب
  Future<bool> checkIsOnline() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = await _verifyActualInternet(results);
    return _isOnline;
  }

  void dispose() {
    _subscription?.cancel();
    _onlineStreamController.close();
  }
}

// ============================================================
// RIVERPOD PROVIDERS FOR NETWORK STATE
// ============================================================

final connectivityServiceProvider = Provider<NetworkConnectivityService>((ref) {
  final service = NetworkConnectivityService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});

final isOnlineStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.isOnlineStream;
});

final isOnlineProvider = StateProvider<bool>((ref) {
  final asyncVal = ref.watch(isOnlineStreamProvider);
  return asyncVal.asData?.value ?? true;
});
