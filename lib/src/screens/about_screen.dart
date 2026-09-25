import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/logo_palette.dart';
import '../theme/sv_button.dart';

class AboutScreen extends StatefulWidget {
  final LogoPalette palette;

  const AboutScreen({super.key, required this.palette});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) { return; }
      setState(() { _version = info.version; });
    } catch (_) {
      if (!mounted) { return; }
      setState(() { _version = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.navy,
        elevation: 0,
        leading: svBack(context, palette.navy),
        title: Text('عن التطبيق', style: svText(palette, size: 22, weight: FontWeight.w700, color: palette.navy)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (palette.hasLogo)
                Image.asset('assets/images/logo.png', width: 120, height: 120, semanticLabel: 'شعار الرؤية الذكية'),
              if (palette.hasLogo) const SizedBox(height: 16),
              Text('الرؤية الذكية', style: svText(palette, size: 28, weight: FontWeight.w700, color: palette.navy)),
              if (_version.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('الإصدار $_version', style: svText(palette, size: 20)),
              ],
              const SizedBox(height: 16),
              Text(
                'مساعد صوتي يصف ما أمامك، ويقرأ النص، وينبهك إلى العوائق القريبة.',
                textAlign: TextAlign.center,
                style: svText(palette, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
