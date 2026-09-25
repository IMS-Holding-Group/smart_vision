import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

Future<bool> startFirebase() async {
  if (!DefaultFirebaseOptions.isConfigured) { return false; }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttestWithDeviceCheckFallback,
    );
    return true;
  } catch (_) {
    return false;
  }
}

Future<String?> signInAnonymous() async {
  try {
    if (Firebase.apps.isEmpty) { return null; }
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) { return current.uid; }
    final cred = await FirebaseAuth.instance.signInAnonymously();
    return cred.user?.uid;
  } catch (_) {
    return null;
  }
}
