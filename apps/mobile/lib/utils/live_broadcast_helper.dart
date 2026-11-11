import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;

class LiveBroadcastHelper {
  static StreamSubscription<html.Event>? _startSub;
  static StreamSubscription<html.Event>? _errorSub;
  static StreamSubscription<html.Event>? _chunkSub;
  static StreamSubscription<html.Event>? _flipSub;
  static StreamSubscription<html.Event>? _muteSub;
  static StreamSubscription<html.Event>? _endSub;
  static String? _registeredPreviewViewId;

  /// Registers a DOM <video> view for real-time camera preview inside Flutter HtmlElementView.
  static String ensurePreviewViewRegistered() {
    if (_registeredPreviewViewId != null) {
      Future.microtask(() {
        if (kIsWeb) {
          html.window.dispatchEvent(html.CustomEvent('register-live-video-el'));
        }
      });
      return _registeredPreviewViewId!;
    }
    final viewId = 'spaces-live-preview-${DateTime.now().microsecondsSinceEpoch}';
    _registeredPreviewViewId = viewId;
    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
        final existing = html.document.getElementById('spaces-live-preview-video');
        if (existing is html.VideoElement) {
          Future.microtask(() {
            html.window.dispatchEvent(html.CustomEvent('register-live-video-el'));
          });
          return existing;
        }
        final video = html.VideoElement()
          ..id = 'spaces-live-preview-video'
          ..autoplay = true
          ..muted = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.backgroundColor = '#05070B';
        video.setAttribute('playsinline', 'true');
        video.setAttribute('webkit-playsinline', 'true');
        Future.delayed(const Duration(milliseconds: 60), () {
          html.window.dispatchEvent(html.CustomEvent('register-live-video-el'));
        });
        return video;
      });
    }
    return viewId;
  }

  static Future<bool> startCameraBroadcast({
    required String streamId,
    String facingMode = 'user',
    required void Function(int seq, int viewers) onChunkUploaded,
    required void Function(String facingMode) onCameraFlipped,
    required void Function(bool isMuted) onMicToggled,
    required void Function(String error) onError,
  }) async {
    if (!kIsWeb) {
      onError('CAMERA_UNSUPPORTED');
      return false;
    }

    _disposeListeners();
    final completer = Completer<bool>();

    _startSub = html.window.on['live-broadcast-started'].listen((_) {
      html.window.dispatchEvent(html.CustomEvent('register-live-video-el'));
      if (!completer.isCompleted) completer.complete(true);
    });

    _errorSub = html.window.on['live-broadcast-error'].listen((event) {
      final err = (event as html.CustomEvent).detail?.toString() ?? 'CAMERA_ERROR';
      onError(err);
      if (!completer.isCompleted) completer.complete(false);
    });

    _chunkSub = html.window.on['live-chunk-sent'].listen((event) {
      try {
        final map = jsonDecode((event as html.CustomEvent).detail?.toString() ?? '{}');
        final seq = (map['seq'] as num?)?.toInt() ?? 1;
        final viewers = (map['viewerCount'] as num?)?.toInt() ?? 1;
        onChunkUploaded(seq, viewers);
      } catch (_) {}
    });

    _flipSub = html.window.on['live-camera-flipped'].listen((event) {
      try {
        final map = jsonDecode((event as html.CustomEvent).detail?.toString() ?? '{}');
        onCameraFlipped(map['facingMode']?.toString() ?? 'user');
      } catch (_) {}
    });

    _muteSub = html.window.on['live-mic-toggled'].listen((event) {
      try {
        final map = jsonDecode((event as html.CustomEvent).detail?.toString() ?? '{}');
        onMicToggled(map['isMuted'] == true);
      } catch (_) {}
    });

    html.window.dispatchEvent(
      html.CustomEvent(
        'trigger-live-start',
        detail: jsonEncode({'streamId': streamId, 'facingMode': facingMode}),
      ),
    );

    Future.delayed(const Duration(seconds: 15), () {
      if (!completer.isCompleted) completer.complete(false);
    });

    return completer.future;
  }

  static void flipCamera() {
    if (!kIsWeb) return;
    html.window.dispatchEvent(html.CustomEvent('trigger-live-flip'));
  }

  static void toggleMute() {
    if (!kIsWeb) return;
    html.window.dispatchEvent(html.CustomEvent('trigger-live-mute'));
  }

  static Future<Map<String, dynamic>?> stopBroadcast() async {
    if (!kIsWeb) return null;
    _endSub?.cancel();
    final completer = Completer<Map<String, dynamic>?>();

    _endSub = html.window.on['live-broadcast-ended'].listen((event) {
      try {
        final parsed = jsonDecode((event as html.CustomEvent).detail?.toString() ?? '{}');
        if (!completer.isCompleted) {
          completer.complete(parsed is Map ? Map<String, dynamic>.from(parsed) : null);
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
      _disposeListeners();
    });

    html.window.dispatchEvent(html.CustomEvent('trigger-live-stop'));

    Future.delayed(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        _disposeListeners();
        completer.complete(null);
      }
    });

    return completer.future;
  }

  static void _disposeListeners() {
    _startSub?.cancel();
    _errorSub?.cancel();
    _chunkSub?.cancel();
    _flipSub?.cancel();
    _muteSub?.cancel();
  }
}

