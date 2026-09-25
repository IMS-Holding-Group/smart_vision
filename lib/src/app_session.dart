import 'prefs/app_prefs.dart';
import 'services/speech_service.dart';
import 'services/yolo_service.dart';

class AppSession {
  final SpeechService speech;
  final YoloService yolo;
  final AppPrefs prefs;
  final bool firebaseReady;
  final String? uid;

  const AppSession({
    required this.speech,
    required this.yolo,
    required this.prefs,
    required this.firebaseReady,
    required this.uid,
  });
}
