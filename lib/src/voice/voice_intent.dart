String normalizeSpeech(String raw) {
  final trimmed = raw.trim();
  final noMarks = trimmed.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
  final alef = noMarks.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
  return alef.replaceAll('ى', 'ي').replaceAll('ة', 'ه');
}

class VoiceTip {
  final String title;
  final String sample;

  const VoiceTip(this.title, this.sample);
}

const voiceTips = <VoiceTip>[
  VoiceTip('وصف المشهد', 'صف ما أمامي'),
  VoiceTip('قراءة النص', 'اقرأ النص'),
  VoiceTip('التعرف على الشيء', 'ما هذا الشيء'),
  VoiceTip('المساعدة', 'ساعدني'),
  VoiceTip('الإعدادات', 'الإعدادات'),
  VoiceTip('عن التطبيق', 'عن التطبيق'),
];

String voiceHelpScript() {
  final parts = <String>[];
  for (final tip in voiceTips) {
    parts.add('${tip.title}. مثال: ${tip.sample}');
  }
  return parts.join('. ');
}

String? matchIntent(String raw) {
  final text = normalizeSpeech(raw);
  if (text.isEmpty || text.length > 200) { return null; }
  if (_containsAny(text, const ['ساعدني', 'المساعده', 'الاوامر'])) { return 'help'; }
  if (text.contains('الاعدادات')) { return 'settings'; }
  if (text.contains('عن التطبيق')) { return 'about'; }
  const readKeys = ['اقرا', 'قراءه', 'النص', 'الحروف', 'المكتوب'];
  const describeKeys = ['وصف', 'المشهد', 'ماذا ارى', 'ما هذا', 'حولي', 'المحيط'];
  if (_containsAny(text, readKeys)) { return 'read'; }
  if (text == 'صف' || text.startsWith('صف ')) { return 'describe'; }
  if (_containsAny(text, describeKeys)) { return 'describe'; }
  return null;
}

bool _containsAny(String text, List<String> keys) {
  for (final key in keys) {
    if (text.contains(key)) { return true; }
  }
  return false;
}
