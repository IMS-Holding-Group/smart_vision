import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../detect/frame_check.dart';

class CloudService {
  Future<String?> analyze({required Uint8List jpeg, required String mode, required String uid}) async {
    if (mode != 'describe' && mode != 'read') { return null; }
    if (!isJpeg(jpeg)) { return null; }
    final path = 'users/$uid/frames/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await FirebaseStorage.instance.ref(path).putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable(
        'analyze_scene',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 50)),
      );
      final result = await callable.call({'path': path, 'mode': mode});
      final data = result.data;
      if (data is! Map || data['text'] is! String) { return null; }
      final text = (data['text'] as String).trim();
      if (text.isEmpty) { return null; }
      await _log(uid, mode, text);
      return text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _log(String uid, String mode, String text) async {
    final summary = text.length > 180 ? text.substring(0, 180) : text;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('logs').add({
        'mode': mode,
        'summary': summary,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      return;
    }
  }
}
