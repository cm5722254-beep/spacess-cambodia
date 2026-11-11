import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class RecordedVoiceResult {
  final String dataUrl;
  final int durationSec;

  RecordedVoiceResult({required this.dataUrl, required this.durationSec});
}

class VoiceRecorderHelper {
  static StreamSubscription<html.Event>? _startSub;
  static StreamSubscription<html.Event>? _completeSub;
  static StreamSubscription<html.Event>? _errorSub;

  static Future<bool> startRecording({
    required VoidCallback onStarted,
    required void Function(String error) onError,
  }) async {
    if (!kIsWeb) {
      onError('MIC_UNSUPPORTED');
      return false;
    }

    _startSub?.cancel();
    _errorSub?.cancel();

    final completer = Completer<bool>();

    _startSub = html.window.on['voice-record-started'].listen((_) {
      onStarted();
      if (!completer.isCompleted) completer.complete(true);
    });

    _errorSub = html.window.on['voice-record-error'].listen((event) {
      final detail = (event as html.CustomEvent).detail?.toString() ?? 'ERROR';
      onError(detail);
      if (!completer.isCompleted) completer.complete(false);
    });

    html.window.dispatchEvent(html.CustomEvent('trigger-voice-start'));

    Future.delayed(const Duration(seconds: 10), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    return completer.future;
  }

  static Future<RecordedVoiceResult?> stopAndGetAudio() async {
    if (!kIsWeb) return null;

    _completeSub?.cancel();
    final completer = Completer<RecordedVoiceResult?>();

    _completeSub = html.window.on['voice-record-complete'].listen((event) {
      try {
        final raw = (event as html.CustomEvent).detail?.toString() ?? '';
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        final dataUrl = parsed['dataUrl'] as String? ?? '';
        final durationSec = (parsed['durationSec'] as num?)?.toInt() ?? 1;
        if (!completer.isCompleted) {
          completer.complete(
            dataUrl.isNotEmpty ? RecordedVoiceResult(dataUrl: dataUrl, durationSec: durationSec) : null,
          );
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
      _completeSub?.cancel();
    });

    html.window.dispatchEvent(html.CustomEvent('trigger-voice-stop'));

    Future.delayed(const Duration(seconds: 5), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    return completer.future;
  }

  static void cancelRecording() {
    if (!kIsWeb) return;
    _completeSub?.cancel();
    html.window.dispatchEvent(html.CustomEvent('trigger-voice-cancel'));
  }
}

