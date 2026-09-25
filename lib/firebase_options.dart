import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static const androidApiKey = 'AIzaSyCfKRuPGw-JfFfHldmNQDJoX3gmcYb0hgo';
  static const androidAppId = '1:1067394691460:android:9fcc1f44c6b9dc56066dd1';
  static const iosApiKey = 'AIzaSyAUH7AHFUAr2fPW3EhrTkWy4t_0cSHUA1o';
  static const iosAppId = '1:1067394691460:ios:7ea98cf116509a85066dd1';
  static const messagingSenderId = '1067394691460';
  static const projectId = 'sv-assist-ff9493';
  static const storageBucket = 'sv-assist-ff9493.firebasestorage.app';
  static const iosBundleId = 'com.example.smartVision';

  static bool get isConfigured {
    return projectId != 'REPLACE_ME' && androidApiKey != 'REPLACE_ME' && iosApiKey != 'REPLACE_ME';
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('المنصة غير مدعومة');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('المنصة غير مدعومة');
    }
  }

  static const android = FirebaseOptions(
    apiKey: androidApiKey,
    appId: androidAppId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
  );

  static const ios = FirebaseOptions(
    apiKey: iosApiKey,
    appId: iosAppId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
    iosBundleId: iosBundleId,
  );
}
