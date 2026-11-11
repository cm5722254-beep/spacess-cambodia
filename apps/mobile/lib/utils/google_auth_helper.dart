import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/api_service.dart';

class GoogleAuthHelper {
  /// Triggers Google Identity Services OAuth popup on Web using Client ID.
  /// If successful, signs in and returns true.
  /// If cancelled, blocked, or not on web, returns false so fallback dialog can open.
  static Future<bool> signInWithGoogle() async {
    if (!kIsWeb) return false;

    final completer = Completer<bool>();
    StreamSubscription? successSub;
    StreamSubscription? errorSub;

    void cleanup() {
      successSub?.cancel();
      errorSub?.cancel();
    }

    final timer = Timer(const Duration(seconds: 45), () {
      cleanup();
      if (!completer.isCompleted) completer.complete(false);
    });

    successSub = html.window.on['google-oauth-success'].listen((event) async {
      cleanup();
      timer.cancel();
      try {
        final customEvent = event as html.CustomEvent;
        final detailStr = customEvent.detail?.toString();
        if (detailStr != null && detailStr.isNotEmpty) {
          final profile = jsonDecode(detailStr) as Map<String, dynamic>;
          final email = profile['email'] as String?;
          final name = profile['name'] as String?;
          final picture = profile['picture'] as String?;
          final sub = profile['sub'] as String?;

          if (email != null && email.contains('@')) {
            final res = await ApiService().loginWithGoogle(
              email: email,
              name: name,
              avatar: picture,
              googleId: sub,
            );
            if (!completer.isCompleted) {
              completer.complete(res['success'] == true);
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Google OAuth success parse error: $e');
      }
      if (!completer.isCompleted) completer.complete(false);
    });

    errorSub = html.window.on['google-oauth-error'].listen((event) {
      cleanup();
      timer.cancel();
      if (!completer.isCompleted) completer.complete(false);
    });

    // Dispatch the trigger event to window
    html.window.dispatchEvent(html.CustomEvent('trigger-google-oauth'));

    return completer.future;
  }
}

