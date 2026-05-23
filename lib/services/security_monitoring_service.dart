import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class SecurityMonitoringService {
  SecurityMonitoringService._();

  static final SecurityMonitoringService instance = SecurityMonitoringService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Cached device parameters
  String? _cachedModel;
  String? _cachedBrand;
  String? _cachedOsVersion;
  String? _cachedDeviceId;

  /// Retrieves device information securely, caching it for subsequent calls.
  Future<Map<String, String>> getDeviceInfo() async {
    if (_cachedModel != null && _cachedDeviceId != null) {
      return {
        'model': _cachedModel!,
        'brand': _cachedBrand ?? 'Unknown',
        'osVersion': _cachedOsVersion ?? 'Unknown',
        'deviceId': _cachedDeviceId!,
      };
    }

    String model = 'Unknown';
    String brand = 'Unknown';
    String osVersion = 'Unknown';
    String deviceId = 'Unknown';

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        model = webInfo.browserName.toString();
        brand = webInfo.vendor ?? 'Web';
        osVersion = webInfo.userAgent ?? 'WebBrowser';
        // Use userAgent combined with vendor as a fallback fingerprint
        deviceId = 'web_${(webInfo.userAgent ?? "").hashCode}';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        model = androidInfo.model;
        brand = androidInfo.brand;
        osVersion = 'Android ${androidInfo.version.release}';
        deviceId = androidInfo.id; // Unique hardware fingerprint for Android
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        model = iosInfo.name;
        brand = 'Apple';
        osVersion = 'iOS ${iosInfo.systemVersion}';
        deviceId = iosInfo.identifierForVendor ?? 'UnknownIOSId'; // Apple persistent vendor ID
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        model = macInfo.model;
        brand = 'Apple';
        osVersion = 'macOS ${macInfo.osRelease}';
        deviceId = macInfo.systemGUID ?? 'UnknownMacId';
      }
    } catch (e) {
      debugPrint('[SecurityMonitoringService] Failed to extract hardware details: $e');
    }

    _cachedModel = model;
    _cachedBrand = brand;
    _cachedOsVersion = osVersion;
    _cachedDeviceId = deviceId;

    return {
      'model': model,
      'brand': brand,
      'osVersion': osVersion,
      'deviceId': deviceId,
    };
  }

  /// Triggers a secure session log payload to the logSessionActivity Cloud Function.
  /// This runs fully asynchronously in the background so the user is never blocked.
  Future<void> logSessionActivity(String sessionTrigger) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[SecurityMonitoringService] Skip session logging: user is unauthenticated.');
      return;
    }

    try {
      final device = await getDeviceInfo();
      debugPrint('[SecurityMonitoringService] Dispatching security session tracking: trigger=$sessionTrigger');

      final callable = _functions.httpsCallable(
        'logSessionActivity',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

      await callable.call(<String, dynamic>{
        'model': device['model'],
        'brand': device['brand'],
        'osVersion': device['osVersion'],
        'deviceId': device['deviceId'],
        'sessionTrigger': sessionTrigger,
      });

      debugPrint('[SecurityMonitoringService] Session tracking successfully verified on backend.');
    } catch (e) {
      // Capture errors gracefully in production to ensure high resiliency
      debugPrint('[SecurityMonitoringService] Handshake failed or timed out: $e');
    }
  }
}
