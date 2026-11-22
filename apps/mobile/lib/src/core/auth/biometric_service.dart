import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Layanan biometrik (sidik jari / wajah) berbasis `local_auth`.
///
/// Catatan Android: `MainActivity` WAJIB extend `FlutterFragmentActivity`
/// agar prompt biometrik OS tampil tanpa crash (sudah diubah di
/// android/app/src/main/kotlin/.../MainActivity.kt).
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Perangkat mendukung biometrik DAN user sudah mendaftarkan biometrik
  /// (sidik jari/wajah) di pengaturan OS.
  Future<bool> isSupported() async {
    try {
      final canCheck = await _auth.isDeviceSupported();
      if (!canCheck) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Tampilkan prompt biometrik OS. `true` bila verifikasi berhasil.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Verifikasi sidik jari untuk masuk ke MTE Data Center',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

final biometricServiceProvider =
    Provider<BiometricService>((ref) => BiometricService());
