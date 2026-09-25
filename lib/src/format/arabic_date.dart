String formatArabicDate(DateTime value) {
  final local = value.toLocal();
  final hour24 = local.hour;
  final isEvening = hour24 >= 12;
  var hour12 = hour24 % 12;
  if (hour12 == 0) { hour12 = 12; }
  final minute = local.minute.toString().padLeft(2, '0');
  final period = isEvening ? 'م' : 'ص';
  return '\u2066${local.year}/${local.month}/${local.day}م $hour12:$minute$period\u2069';
}
