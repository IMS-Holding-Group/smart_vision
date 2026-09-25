import 'package:flutter/material.dart';

import 'logo_palette.dart';

TextStyle svText(LogoPalette palette, {double size = 18, FontWeight weight = FontWeight.w400, Color? color}) {
  return TextStyle(
    fontFamily: 'IBM Plex Sans Arabic',
    fontSize: size,
    fontWeight: weight,
    color: color ?? palette.text,
  );
}

class SvButton extends StatelessWidget {
  final String label;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Color? borderColor;

  const SvButton({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
    required this.background,
    required this.foreground,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!),
          ),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 18, fontWeight: FontWeight.w700, color: foreground),
          ),
        ),
      ),
    );
  }
}

Widget svBack(BuildContext context, Color color) {
  return IconButton(
    tooltip: 'رجوع',
    color: color,
    onPressed: () { Navigator.maybePop(context); },
    icon: const Icon(Icons.arrow_back),
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  );
}
