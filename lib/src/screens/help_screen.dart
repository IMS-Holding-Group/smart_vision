import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/logo_palette.dart';
import '../theme/sv_button.dart';
import '../voice/voice_intent.dart';

class HelpScreen extends StatelessWidget {
  final LogoPalette palette;
  final Future<void> Function(String text) onSpeak;

  const HelpScreen({super.key, required this.palette, required this.onSpeak});

  @override
  Widget build(BuildContext context) {
    final palette = this.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.navy,
        elevation: 0,
        leading: svBack(context, palette.navy),
        title: Text('الأوامر والمساعدة', style: svText(palette, size: 22, weight: FontWeight.w700, color: palette.navy)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: voiceTips.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final tip = voiceTips[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tip.title, style: svText(palette, size: 24, weight: FontWeight.w700, color: palette.navy)),
                      const SizedBox(height: 4),
                      Text('مثال: ${tip.sample}', style: svText(palette, size: 20)),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SvButton(
              label: 'استمع للمساعدة',
              semanticsLabel: 'استمع لقائمة الأوامر صوتيا',
              background: palette.navy,
              foreground: Colors.white,
              onPressed: () { unawaited(onSpeak(voiceHelpScript())); },
            ),
          ),
        ],
      ),
    );
  }
}
