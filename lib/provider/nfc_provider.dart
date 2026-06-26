// nfc_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/rfid_model.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/services/nfc_service.dart';

// NFC Service Provider
final nfcServiceProvider = Provider<NFCService>((ref) {
  return NFCService(
    database: ref.read(firebaseDatabaseProvider),
  );
});

// NFC Availability Provider
final nfcAvailabilityProvider = FutureProvider<bool>((ref) async {
  final nfcService = ref.read(nfcServiceProvider);
  return await nfcService.isNFCAvailable();
});

// RFID Tags Stream Provider
final rfidTagsStreamProvider = StreamProvider<List<RFIDModel>>((ref) {
  final nfcService = ref.read(nfcServiceProvider);
  return nfcService.getRfidTagsStream();
});

// NFC Scanning State
class NFCScanningState {
  final bool isScanning;
  final String? lastScannedUid;
  final String? errorMessage;
  final bool isProcessing;

  NFCScanningState({
    this.isScanning = false,
    this.lastScannedUid,
    this.errorMessage,
    this.isProcessing = false,
  });

  NFCScanningState copyWith({
    bool? isScanning,
    String? lastScannedUid,
    String? errorMessage,
    bool? isProcessing,
    bool clearLastScannedUid = false,
    bool clearErrorMessage = false,
  }) {
    return NFCScanningState(
      isScanning: isScanning ?? this.isScanning,
      lastScannedUid: clearLastScannedUid ? null : lastScannedUid ?? this.lastScannedUid,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

// NFC Scanning State Notifier
class NFCScanningNotifier extends StateNotifier<NFCScanningState> {
  final NFCService _nfcService;

  NFCScanningNotifier(this._nfcService) : super(NFCScanningState());

  Future<void> startScanning() async {
    state = state.copyWith(
      isScanning: true,
      clearErrorMessage: true,
      clearLastScannedUid: true,
    );

    await _nfcService.startNFCScanning(
      onTagDiscovered: (uid) {
        state = state.copyWith(
          lastScannedUid: uid,
          isScanning: false,
        );
      },
      onError: (error) {
        state = state.copyWith(
          errorMessage: error,
          isScanning: false,
        );
      },
    );
  }

  Future<void> stopScanning() async {
    await _nfcService.stopNFCScanning();
    state = state.copyWith(isScanning: false);
  }

  Future<bool> addScannedTag() async {
    if (state.lastScannedUid == null) return false;

    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      await _nfcService.addRfidTag(state.lastScannedUid!);
      state = state.copyWith(
        isProcessing: false,
        clearLastScannedUid: true,
        //errorMessage: null,
      );
      return true;
      
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  void clearLastScanned() {
    state = state.copyWith(clearLastScannedUid: true);
  }
}

// NFC Scanning State Provider
final nfcScanningProvider = StateNotifierProvider<NFCScanningNotifier, NFCScanningState>((ref) {
  final nfcService = ref.read(nfcServiceProvider);
  return NFCScanningNotifier(nfcService);
});