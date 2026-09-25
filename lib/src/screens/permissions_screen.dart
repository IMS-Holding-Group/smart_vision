import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../prefs/app_prefs.dart';
import '../services/speech_service.dart';
import '../theme/logo_palette.dart';
import '../theme/sv_button.dart';

class PermissionsScreen extends StatefulWidget {
  final LogoPalette palette;
  final SpeechService speech;
  final AppPrefs prefs;
  final VoidCallback onGranted;

  const PermissionsScreen({
    super.key,
    required this.palette,
    required this.speech,
    required this.prefs,
    required this.onGranted,
  });

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  var _asking = false;
  var _reported = false;
  var _cameraGranted = true;
  var _micGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) { unawaited(_ask()); });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { unawaited(_recheck()); }
  }

  bool get _mobile {
    if (kIsWeb) { return false; }
    return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _ask() async {
    if (_asking) { return; }
    _asking = true;
    if (mounted) { setState(() {}); }
    try {
      if (!_mobile) {
        await widget.prefs.setPermissionsDone(true);
        if (mounted) { widget.onGranted(); }
        return;
      }
      await widget.speech.speak('نحتاج إلى الكاميرا لرؤية ما أمامك والكشف عن العوائق');
      final camera = await _request(Permission.camera);
      await widget.speech.speak('نحتاج إلى الميكروفون لسماع أوامرك الصوتية');
      final mic = await _request(Permission.microphone);
      await _apply(camera, mic);
    } finally {
      _asking = false;
      if (mounted) { setState(() {}); }
    }
  }

  Future<void> _retry() async {
    if (_asking) { return; }
    try {
      final camera = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      final stuck = camera.isPermanentlyDenied || mic.isPermanentlyDenied || camera.isRestricted || mic.isRestricted;
      if (stuck) {
        await widget.speech.speak('سيتم فتح إعدادات النظام لمنح الصلاحيات');
        await openAppSettings();
        return;
      }
    } catch (_) {
      await openAppSettings();
      return;
    }
    await _ask();
  }

  Future<void> _recheck() async {
    if (!_mobile || _asking) { return; }
    try {
      final camera = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      await _apply(camera, mic, speakDenial: false);
    } catch (_) {}
  }

  Future<PermissionStatus> _request(Permission permission) async {
    try {
      return await permission.request();
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  Future<void> _apply(PermissionStatus camera, PermissionStatus mic, {bool speakDenial = true}) async {
    final cameraOk = camera.isGranted;
    final micOk = mic.isGranted;
    if (mounted) {
      setState(() {
        _cameraGranted = cameraOk;
        _micGranted = micOk;
        _reported = true;
      });
    }
    if (cameraOk && micOk) {
      await widget.prefs.setPermissionsDone(true);
      if (mounted) { widget.onGranted(); }
      return;
    }
    if (!speakDenial) { return; }
    if (!cameraOk) { await widget.speech.speak('بدون الكاميرا يتعطل الكشف عن الأجسام'); }
    if (!micOk) { await widget.speech.speak('بدون الميكروفون تتعطل الأوامر الصوتية'); }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('صلاحيات التشغيل', style: svText(palette, size: 28, weight: FontWeight.w700, color: palette.navy)),
              const SizedBox(height: 20),
              _row(palette, Icons.photo_camera_outlined, 'الكاميرا', 'لرؤية ما أمامك والكشف عن العوائق القريبة'),
              if (_reported && !_cameraGranted) ...[
                const SizedBox(height: 8),
                Text('بدون الكاميرا يتعطل الكشف عن الأجسام', style: svText(palette, size: 18, weight: FontWeight.w700)),
              ],
              const SizedBox(height: 20),
              _row(palette, Icons.mic_none, 'الميكروفون', 'لسماع الأوامر الصوتية'),
              if (_reported && !_micGranted) ...[
                const SizedBox(height: 8),
                Text('بدون الميكروفون تتعطل الأوامر الصوتية', style: svText(palette, size: 18, weight: FontWeight.w700)),
              ],
              const Spacer(),
              SvButton(
                label: 'متابعة',
                semanticsLabel: 'متابعة طلب الصلاحيات',
                background: palette.navy,
                foreground: Colors.white,
                onPressed: _asking ? null : () { unawaited(_retry()); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(LogoPalette palette, IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, color: palette.navy, size: 40)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: svText(palette, size: 24, weight: FontWeight.w700, color: palette.navy)),
              const SizedBox(height: 4),
              Text(body, style: svText(palette, size: 18)),
            ],
          ),
        ),
      ],
    );
  }
}
