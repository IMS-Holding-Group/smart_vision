import 'dart:async';

import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../detect/yolo_decoder.dart';
import '../prefs/app_prefs.dart';
import '../services/cloud_service.dart';
import '../services/firebase_boot.dart';
import '../services/speech_service.dart';
import '../services/yolo_service.dart';
import '../theme/logo_palette.dart';
import '../theme/sv_button.dart';
import '../voice/voice_intent.dart';
import 'about_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

const _phaseReady = 'جاهز للاستماع';
const _phaseListen = 'جار الاستماع لأمر';
const _phaseCloud = 'جار التحليل السحابي';
const _phaseSpeak = 'جار النطق';

class HomeScreen extends StatefulWidget {
  final LogoPalette palette;
  final SpeechService speech;
  final YoloService yolo;
  final AppPrefs prefs;
  final bool firebaseReady;
  final String? uid;

  const HomeScreen({
    super.key,
    required this.palette,
    required this.speech,
    required this.yolo,
    required this.prefs,
    required this.firebaseReady,
    required this.uid,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _cloud = CloudService();
  final _spokenAt = <String, DateTime>{};
  CameraController? _camera;
  Timer? _boot;
  Timer? _alertTimer;
  var _alive = true;
  var _busy = false;
  var _inferring = false;
  var _listening = false;
  var _opening = false;
  String? _uid;
  String _phase = 'جار تجهيز الكاميرا';
  String? _note;
  String? _alert;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    widget.prefs.addListener(_onPrefs);
    _boot = Timer(Duration.zero, () { unawaited(_start()); });
  }

  void _onPrefs() {
    if (!mounted) { return; }
    setState(() {});
  }

  Future<void> _start() async {
    var voice = false;
    try {
      await _ensureUser();
      await widget.speech.init(_onSpeech);
      if (!_alive) { return; }
      voice = true;
      setState(() { _listening = true; });
      _setPhase(_phaseListen);
    } catch (_) {
      _setPhase('تعذر تشغيل الصوت');
    }
    final cameraOk = await _openCamera();
    if (!_alive || !voice) { return; }
    if (!cameraOk) {
      _setNote('تعذر تشغيل الكاميرا');
      await _say('تعذر تشغيل الكاميرا. الأوامر الصوتية ما زالت متاحة');
      return;
    }
    await _say('قل وصف المشهد أو اقرأ النص أو ساعدني');
  }

  Future<void> _ensureUser() async {
    if (_uid != null) { return; }
    if (!widget.firebaseReady && Firebase.apps.isEmpty) { return; }
    _uid = await signInAnonymous();
  }

  Future<bool> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { return false; }
      final camera = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
      await camera.initialize();
      await camera.startImageStream(_onFrame);
      if (!_alive) {
        await camera.dispose();
        return false;
      }
      setState(() { _camera = camera; });
      _setPhase(_listening ? _phaseListen : _phaseReady);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (!_alive || _busy || _inferring || now.difference(_lastFrame).inMilliseconds < 700) { return; }
    _lastFrame = now;
    _inferring = true;
    try {
      _announce(widget.yolo.detect(image));
    } catch (_) {}
    _inferring = false;
  }

  void _announce(List<Detection> found) {
    if (found.isEmpty) { return; }
    final limit = obstacleAreaLimit(widget.prefs.obstacleLevel);
    Detection? closest;
    for (final item in found) {
      if (item.area < limit) { continue; }
      if (closest == null || item.area > closest.area) { closest = item; }
    }
    if (closest == null) { return; }
    final previous = _spokenAt[closest.label];
    final now = DateTime.now();
    if (previous != null && now.difference(previous).inSeconds < 6) { return; }
    _spokenAt[closest.label] = now;
    final line = 'تحذير. ${closest.label} أمامك';
    _showAlert(line);
    if (widget.prefs.vibrate) { HapticFeedback.vibrate(); }
    unawaited(_say(line));
  }

  void _showAlert(String line) {
    if (!_alive) { return; }
    _alertTimer?.cancel();
    setState(() { _alert = line; });
    _alertTimer = Timer(const Duration(seconds: 4), () {
      if (!_alive) { return; }
      setState(() { _alert = null; });
    });
  }

  Future<void> _onSpeech(String words) async {
    if (!mounted || _busy || _opening || !(ModalRoute.of(context)?.isCurrent ?? false)) { return; }
    final mode = matchIntent(words);
    if (mode == null) { return; }
    if (mode == 'help') {
      await _open(HelpScreen(palette: widget.palette, onSpeak: widget.speech.speak));
      return;
    }
    if (mode == 'settings') {
      await _open(SettingsScreen(palette: widget.palette, prefs: widget.prefs, speech: widget.speech));
      return;
    }
    if (mode == 'about') {
      await _open(AboutScreen(palette: widget.palette));
      return;
    }
    await _runCloud(mode);
  }

  Future<void> _open(Widget screen) async {
    if (_opening || !mounted) { return; }
    _opening = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    } finally {
      _opening = false;
    }
  }

  Future<void> _toggleListen() async {
    if (_busy) { return; }
    final next = !_listening;
    setState(() { _listening = next; });
    if (next) {
      await widget.speech.resume();
      _setPhase(_phaseListen);
      return;
    }
    await widget.speech.pause();
    _setPhase(_phaseReady);
  }

  Future<void> _runCloud(String mode) async {
    if (_busy) { return; }
    setState(() { _busy = true; });
    _setPhase(_phaseCloud);
    await widget.speech.pause();
    final text = await _captureAndAsk(mode);
    if (text == null) {
      _setNote('تعذر إتمام الطلب');
      await _say('تعذر إتمام الطلب. حاول مرة أخرى');
    } else {
      _setNote(text);
      await _say(text);
    }
    if (_alive) {
      setState(() { _busy = false; });
      if (_listening) {
        await widget.speech.resume();
        _setPhase(_phaseListen);
      } else {
        _setPhase(_phaseReady);
      }
    }
  }

  Future<String?> _captureAndAsk(String mode) async {
    await _ensureUser();
    final camera = _camera;
    final uid = _uid;
    if (camera == null || uid == null || !camera.value.isInitialized) { return null; }
    try {
      if (camera.value.isStreamingImages) { await camera.stopImageStream(); }
      final shot = await camera.takePicture();
      final bytes = await shot.readAsBytes();
      if (_alive) { await camera.startImageStream(_onFrame); }
      return _cloud.analyze(jpeg: bytes, mode: mode, uid: uid);
    } catch (_) {
      if (_alive && camera.value.isInitialized && !camera.value.isStreamingImages) {
        await camera.startImageStream(_onFrame);
      }
      return null;
    }
  }

  Future<void> _say(String text) async {
    _setPhase(_phaseSpeak);
    await widget.speech.speak(text);
    if (!_alive || _busy) { return; }
    _setPhase(_listening ? _phaseListen : _phaseReady);
  }

  void _setPhase(String value) {
    if (!_alive || _phase == value) { return; }
    setState(() { _phase = value; });
  }

  void _setNote(String value) {
    if (!_alive) { return; }
    setState(() { _note = value; });
  }

  @override
  void dispose() {
    _alive = false;
    _boot?.cancel();
    _alertTimer?.cancel();
    widget.prefs.removeListener(_onPrefs);
    unawaited(widget.speech.dispose());
    unawaited(_camera?.dispose());
    widget.yolo.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(palette),
              if (widget.prefs.showCamera) ...[
                const SizedBox(height: 8),
                _preview(palette),
              ],
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(_phase, style: svText(palette, size: 26, weight: FontWeight.w700, color: palette.navy)),
              ),
              if (_busy) ...[
                const SizedBox(height: 8),
                ExcludeSemantics(
                  child: LinearProgressIndicator(color: palette.orange, backgroundColor: palette.sky.withValues(alpha: 0.25)),
                ),
              ],
              if (_alert != null) ...[
                const SizedBox(height: 8),
                _alertBanner(palette),
              ],
              if (_note != null) ...[
                const SizedBox(height: 8),
                Text(_note!, style: svText(palette, size: 20, weight: FontWeight.w700)),
              ],
              const Spacer(),
              Center(child: _listenButton(palette)),
              const Spacer(),
              _links(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(LogoPalette palette) {
    return Row(
      children: [
        if (palette.hasLogo)
          Image.asset('assets/images/logo.png', width: 48, height: 48, semanticLabel: 'شعار الرؤية الذكية'),
        if (palette.hasLogo) const SizedBox(width: 12),
        Expanded(child: Text('الرؤية الذكية', style: svText(palette, size: 24, weight: FontWeight.w700, color: palette.navy))),
      ],
    );
  }

  Widget _preview(LogoPalette palette) {
    final camera = _camera;
    final ready = camera != null && camera.value.isInitialized;
    return Semantics(
      label: 'معاينة الكاميرا',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 140,
            width: double.infinity,
            child: ColoredBox(
              color: palette.navy.withValues(alpha: 0.08),
              child: ready ? _fittedPreview(camera) : Center(child: Text('بانتظار الكاميرا', style: svText(palette, size: 18))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fittedPreview(CameraController camera) {
    final ratio = camera.value.aspectRatio == 0 ? 1.0 : camera.value.aspectRatio;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: 100 * ratio,
        height: 100,
        child: CameraPreview(camera),
      ),
    );
  }

  Widget _alertBanner(LogoPalette palette) {
    return Semantics(
      liveRegion: true,
      label: _alert,
      child: DecoratedBox(
        decoration: BoxDecoration(color: palette.navy, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const ExcludeSemantics(child: Icon(Icons.warning_amber, color: Colors.white, size: 32)),
              const SizedBox(width: 8),
              Expanded(child: Text(_alert ?? '', style: svText(palette, size: 22, weight: FontWeight.w700, color: Colors.white))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listenButton(LogoPalette palette) {
    final label = _listening ? 'إيقاف الاستماع مؤقتا' : 'بدء الاستماع';
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: palette.navy,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _busy ? null : () { unawaited(_toggleListen()); },
          child: SizedBox(
            width: 168,
            height: 168,
            child: Icon(_listening ? Icons.mic : Icons.mic_off, color: Colors.white, size: 72),
          ),
        ),
      ),
    );
  }

  Widget _links(LogoPalette palette) {
    return Row(
      children: [
        Expanded(child: _link(palette, 'المساعدة', 'فتح شاشة الأوامر والمساعدة', () {
          unawaited(_open(HelpScreen(palette: palette, onSpeak: widget.speech.speak)));
        })),
        const SizedBox(width: 8),
        Expanded(child: _link(palette, 'الإعدادات', 'فتح الإعدادات', () {
          unawaited(_open(SettingsScreen(palette: palette, prefs: widget.prefs, speech: widget.speech)));
        })),
        const SizedBox(width: 8),
        Expanded(child: _link(palette, 'عن التطبيق', 'فتح شاشة عن التطبيق', () {
          unawaited(_open(AboutScreen(palette: palette)));
        })),
      ],
    );
  }

  Widget _link(LogoPalette palette, String label, String semantics, VoidCallback onPressed) {
    return SvButton(
      label: label,
      semanticsLabel: semantics,
      background: Colors.white,
      foreground: palette.navy,
      borderColor: palette.navy,
      onPressed: _opening ? null : onPressed,
    );
  }
}
