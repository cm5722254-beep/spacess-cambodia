import 'dart:async';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class PwaHelper {
  static bool get isWeb => kIsWeb;

  /// Check whether the app is currently running in standalone (PWA installed) mode
  static bool isStandalone() {
    if (!kIsWeb) return false;
    try {
      final standaloneMedia = html.window.matchMedia('(display-mode: standalone)').matches;
      // ignore: undefined_getter
      final isNavigatorStandalone = (html.window.navigator as dynamic).standalone == true;
      return standaloneMedia || isNavigatorStandalone;
    } catch (_) {
      return false;
    }
  }

  /// Detect whether the user is browsing on iOS Safari
  static bool isIosSafari() {
    if (!kIsWeb) return false;
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      final isIos = ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
      return isIos;
    } catch (_) {
      return false;
    }
  }

  /// Trigger the browser PWA install prompt.
  /// If native install prompt is unavailable (e.g. iOS Safari), returns false.
  static Future<bool> triggerInstallPrompt({VoidCallback? onNeedManualGuide}) async {
    if (!kIsWeb) return false;

    try {
      StreamSubscription? guideSub;
      StreamSubscription? resultSub;

      final completer = Completer<bool>();

      void cleanup() {
        guideSub?.cancel();
        resultSub?.cancel();
      }

      guideSub = html.window.on['pwa-install-guide'].listen((_) {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(false);
          onNeedManualGuide?.call();
        }
      });

      resultSub = html.window.on['pwa-install-result'].listen((event) {
        cleanup();
        if (!completer.isCompleted) {
          final customEvent = event as html.CustomEvent;
          final outcome = customEvent.detail?.toString() ?? '';
          completer.complete(outcome == 'accepted');
        }
      });

      // Dispatch event to JavaScript
      html.window.dispatchEvent(html.CustomEvent('trigger-pwa-install'));

      // Timeout fallback after 3 seconds: show manual guide if no response
      Timer(const Duration(seconds: 3), () {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(false);
          onNeedManualGuide?.call();
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('[PwaHelper] Trigger install error: $e');
      onNeedManualGuide?.call();
      return false;
    }
  }
}

