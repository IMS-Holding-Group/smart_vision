import 'package:flutter/material.dart';

import 'src/app_session.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/permissions_screen.dart';
import 'src/screens/splash_screen.dart';
import 'src/theme/logo_palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final palette = await LogoPalette.load();
  runApp(SmartVisionApp(palette: palette));
}

class SmartVisionApp extends StatelessWidget {
  final LogoPalette palette;

  const SmartVisionApp({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الرؤية الذكية',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: _theme(palette),
      builder: (context, child) {
        final page = child ?? const SizedBox.shrink();
        return Directionality(textDirection: TextDirection.rtl, child: page);
      },
      home: AppFlow(palette: palette),
    );
  }
}

ThemeData _theme(LogoPalette palette) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: palette.background,
    fontFamily: 'IBM Plex Sans Arabic',
    colorScheme: ColorScheme.light(
      primary: palette.navy,
      secondary: palette.orange,
      surface: palette.background,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: palette.text,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'IBM Plex Sans Arabic',
      bodyColor: palette.text,
      displayColor: palette.text,
    ),
  );
}

class AppFlow extends StatefulWidget {
  final LogoPalette palette;

  const AppFlow({super.key, required this.palette});

  @override
  State<AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<AppFlow> {
  AppSession? _session;
  var _enterHome = false;

  void _onReady(AppSession session) {
    setState(() {
      _session = session;
      _enterHome = session.prefs.permissionsDone;
    });
  }

  void _onGranted() {
    setState(() { _enterHome = true; });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return SplashScreen(palette: widget.palette, onReady: _onReady);
    }
    if (!_enterHome) {
      return PermissionsScreen(
        palette: widget.palette,
        speech: session.speech,
        prefs: session.prefs,
        onGranted: _onGranted,
      );
    }
    return HomeScreen(
      palette: widget.palette,
      speech: session.speech,
      yolo: session.yolo,
      prefs: session.prefs,
      firebaseReady: session.firebaseReady,
      uid: session.uid,
    );
  }
}
