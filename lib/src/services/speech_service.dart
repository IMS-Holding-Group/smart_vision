import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  SpeechService() : _tts = FlutterTts(), _stt = SpeechToText();

  final FlutterTts _tts;
  final SpeechToText _stt;
  var _paused = false;
  var _speaking = false;
  var _ready = false;
  var _warm = false;
  var _rate = 0.45;
  void Function(String text)? _onText;

  Future<void> warmup({double rate = 0.45}) async {
    _rate = rate;
    await _tts.setLanguage('ar');
    await _tts.setSpeechRate(_rate);
    await _tts.awaitSpeakCompletion(true);
    _warm = true;
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    await _tts.setSpeechRate(rate);
  }

  Future<void> init(void Function(String text) onText) async {
    _onText = onText;
    if (_warm) {
      await _tts.setSpeechRate(_rate);
    } else {
      await warmup(rate: _rate);
    }
    _ready = await _stt.initialize(onStatus: _onStatus, onError: (_) {});
    if (_ready) { await _listen(); }
  }

  Future<void> speak(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) { return; }
    _speaking = true;
    try {
      if (_stt.isListening) { await _stt.stop(); }
      await _tts.speak(cleaned);
    } catch (_) {
      _speaking = false;
      return;
    }
    _speaking = false;
    if (!_paused && _ready) { await _listen(); }
  }

  Future<void> pause() async {
    _paused = true;
    if (_stt.isListening) { await _stt.stop(); }
  }

  Future<void> resume() async {
    _paused = false;
    if (!_speaking && _ready) { await _listen(); }
  }

  Future<void> dispose() async {
    _paused = true;
    if (_stt.isListening) { await _stt.stop(); }
    await _tts.stop();
  }

  void _onStatus(String status) {
    if (_paused || _speaking) { return; }
    if (status == 'done' || status == 'notListening') { unawaited(_listen()); }
  }

  Future<void> _listen() async {
    if (!_ready || _paused || _speaking || _stt.isListening) { return; }
    await _stt.listen(
      onResult: (result) {
        if (!result.finalResult) { return; }
        final words = result.recognizedWords.trim();
        if (words.isEmpty) { return; }
        _onText?.call(words);
      },
      listenOptions: SpeechListenOptions(
        localeId: 'ar_SA',
        partialResults: false,
        listenMode: ListenMode.confirmation,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }
}
