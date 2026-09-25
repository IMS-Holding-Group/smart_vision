import 'dart:async';

import 'package:flutter/material.dart';

import '../prefs/app_prefs.dart';
import '../services/speech_service.dart';
import '../theme/logo_palette.dart';
import '../theme/sv_button.dart';

class SettingsScreen extends StatefulWidget {
  final LogoPalette palette;
  final AppPrefs prefs;
  final SpeechService speech;

  const SettingsScreen({super.key, required this.palette, required this.prefs, required this.speech});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _rate;

  @override
  void initState() {
    super.initState();
    _rate = widget.prefs.speechRate.clamp(0.3, 0.7).toDouble();
  }

  Future<void> _commitRate(double value) async {
    await widget.prefs.setSpeechRate(value);
    await widget.speech.setRate(value);
    await widget.speech.speak('سرعة النطق ${speechRateWords(value)}');
  }

  Future<void> _level(String level) async {
    await widget.prefs.setObstacleLevel(level);
    if (mounted) { setState(() {}); }
    await widget.speech.speak('حساسية التنبيه ${obstacleLevelWords(level)}');
  }

  Future<void> _vibrate(bool value) async {
    await widget.prefs.setVibrate(value);
    if (mounted) { setState(() {}); }
    await widget.speech.speak(value ? 'الاهتزاز يعمل' : 'الاهتزاز متوقف');
  }

  Future<void> _camera(bool value) async {
    await widget.prefs.setShowCamera(value);
    if (mounted) { setState(() {}); }
    await widget.speech.speak(value ? 'معاينة الكاميرا تعمل' : 'معاينة الكاميرا متوقفة');
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final level = widget.prefs.obstacleLevel;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.navy,
        elevation: 0,
        leading: svBack(context, palette.navy),
        title: Text('الإعدادات', style: svText(palette, size: 22, weight: FontWeight.w700, color: palette.navy)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('سرعة النطق', style: svText(palette, size: 22, weight: FontWeight.w700, color: palette.navy)),
          const SizedBox(height: 4),
          Text(speechRateWords(_rate), style: svText(palette, size: 20)),
          Semantics(
            label: 'سرعة النطق',
            value: speechRateWords(_rate),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              ),
              child: Slider(
                value: _rate,
                min: 0.3,
                max: 0.7,
                divisions: 4,
                activeColor: palette.navy,
                onChanged: (value) { setState(() { _rate = value; }); },
                onChangeEnd: (value) { unawaited(_commitRate(value)); },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('حساسية تنبيه العوائق', style: svText(palette, size: 22, weight: FontWeight.w700, color: palette.navy)),
          const SizedBox(height: 8),
          _levelButton(palette, 'low', level),
          const SizedBox(height: 8),
          _levelButton(palette, 'medium', level),
          const SizedBox(height: 8),
          _levelButton(palette, 'high', level),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('الاهتزاز عند التنبيه', style: svText(palette, size: 20)),
            value: widget.prefs.vibrate,
            onChanged: (value) { unawaited(_vibrate(value)); },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('معاينة الكاميرا', style: svText(palette, size: 20)),
            value: widget.prefs.showCamera,
            onChanged: (value) { unawaited(_camera(value)); },
          ),
        ],
      ),
    );
  }

  Widget _levelButton(LogoPalette palette, String id, String selected) {
    final on = id == selected;
    final name = obstacleLevelWords(id);
    final label = on ? '$name، مختارة' : name;
    return SvButton(
      label: label,
      semanticsLabel: 'حساسية التنبيه $label',
      background: on ? palette.navy : Colors.white,
      foreground: on ? Colors.white : palette.navy,
      borderColor: palette.navy,
      onPressed: () { unawaited(_level(id)); },
    );
  }
}
