import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'api_service.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final ValueNotifier<Map<String, dynamic>?> latestToastNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<bool> connectedNotifier = ValueNotifier<bool>(false);

  html.EventSource? _eventSource;
  StreamSubscription<html.MessageEvent>? _msgSub;
  StreamSubscription<html.Event>? _errSub;
  StreamSubscription<html.Event>? _openSub;
  Timer? _reconnectTimer;
  Timer? _toastClearTimer;
  String? _activeUserId;
  bool _initialized = false;

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  void init() {
    if (_initialized) return;
    _initialized = true;

    ApiService().authNotifier.addListener(_syncConnection);
    _syncConnection();
  }

  void _syncConnection() {
    final userId = ApiService().currentUser?.id;
    if (userId == null || userId.isEmpty) {
      disconnect();
      return;
    }
    if (_activeUserId == userId && _eventSource != null) return;
    connect(userId);
  }

  void connect(String userId) {
    disconnect();
    _activeUserId = userId;
    if (!kIsWeb) return;

    try {
      final url = '/api/v1/events/stream?userId=${Uri.encodeComponent(userId)}';
      final es = html.EventSource(url);
      _eventSource = es;

      _openSub = es.onOpen.listen((_) {
        connectedNotifier.value = true;
      });

      _msgSub = es.onMessage.listen((event) {
        try {
          final raw = event.data;
          if (raw == null) return;
          final parsed = jsonDecode(raw.toString());
          if (parsed is Map<String, dynamic>) {
            _eventController.add(parsed);
            final type = parsed['type']?.toString() ?? '';
            if (type != 'SYSTEM') {
              _showToastAndBrowserAlert(parsed);
            }
          }
        } catch (e) {
          debugPrint('[RealtimeService] Parse error: $e');
        }
      });

      _errSub = es.onError.listen((_) {
        connectedNotifier.value = false;
        _scheduleReconnect();
      });
    } catch (e) {
      debugPrint('[RealtimeService] SSE connect error: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final uid = _activeUserId;
    if (uid == null || uid.isEmpty) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_activeUserId == uid) {
        connect(uid);
      }
    });
  }

  void _showToastAndBrowserAlert(Map<String, dynamic> event) {
    final title = event['title']?.toString() ?? 'Spaces Cambodia';
    final body = event['body']?.toString() ?? '';

    latestToastNotifier.value = event;
    _toastClearTimer?.cancel();
    _toastClearTimer = Timer(const Duration(seconds: 4), () {
      latestToastNotifier.value = null;
    });

    if (kIsWeb && html.Notification.supported && html.Notification.permission == 'granted') {
      try {
        html.Notification(
          title,
          body: body,
          icon: '/icons/Icon-192.png',
        );
      } catch (_) {}
    }
  }

  bool get browserNotificationsSupported => kIsWeb && html.Notification.supported;

  String get browserPermissionStatus {
    if (!kIsWeb || !html.Notification.supported) return 'unsupported';
    return html.Notification.permission ?? 'default';
  }

  Future<String> requestBrowserNotificationPermission() async {
    if (!kIsWeb || !html.Notification.supported) return 'unsupported';
    try {
      return await html.Notification.requestPermission();
    } catch (_) {
      return 'denied';
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _msgSub?.cancel();
    _errSub?.cancel();
    _openSub?.cancel();
    try {
      _eventSource?.close();
    } catch (_) {}
    _eventSource = null;
    _activeUserId = null;
    connectedNotifier.value = false;
  }
}

