import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

double obstacleAreaLimit(String level) {
  if (level == 'low') { return 0.22; }
  if (level == 'high') { return 0.06; }
  return 0.12;
}

String obstacleLevelWords(String level) {
  if (level == 'low') { return 'منخفضة'; }
  if (level == 'high') { return 'عالية'; }
  return 'متوسطة';
}

String speechRateWords(double rate) {
  if (rate <= 0.38) { return 'بطيئة'; }
  if (rate >= 0.58) { return 'سريعة'; }
  return 'متوسطة';
}

class AppPrefs extends ChangeNotifier {
  AppPrefs._(this._store, this.speechRate, this.obstacleLevel, this.vibrate, this.showCamera, this.permissionsDone);

  final SharedPreferences? _store;
  double speechRate;
  String obstacleLevel;
  bool vibrate;
  bool showCamera;
  bool permissionsDone;

  static Future<AppPrefs> load() async {
    try {
      final store = await SharedPreferences.getInstance();
      final storedRate = store.getDouble('speech_rate') ?? 0.45;
      final storedLevel = store.getString('obstacle_level');
      return AppPrefs._(
        store,
        storedRate.clamp(0.3, 0.7).toDouble(),
        _level(storedLevel),
        store.getBool('vibrate') ?? true,
        store.getBool('show_camera') ?? true,
        store.getBool('permissions_done') ?? false,
      );
    } catch (_) {
      return AppPrefs._(null, 0.45, 'medium', true, true, false);
    }
  }

  Future<void> setSpeechRate(double value) async {
    speechRate = value.clamp(0.3, 0.7).toDouble();
    await _store?.setDouble('speech_rate', speechRate);
    notifyListeners();
  }

  Future<void> setObstacleLevel(String value) async {
    obstacleLevel = _level(value);
    await _store?.setString('obstacle_level', obstacleLevel);
    notifyListeners();
  }

  Future<void> setVibrate(bool value) async {
    vibrate = value;
    await _store?.setBool('vibrate', value);
    notifyListeners();
  }

  Future<void> setShowCamera(bool value) async {
    showCamera = value;
    await _store?.setBool('show_camera', value);
    notifyListeners();
  }

  Future<void> setPermissionsDone(bool value) async {
    permissionsDone = value;
    await _store?.setBool('permissions_done', value);
    notifyListeners();
  }
}

String _level(String? raw) {
  if (raw == 'low' || raw == 'medium' || raw == 'high') { return raw!; }
  return 'medium';
}
