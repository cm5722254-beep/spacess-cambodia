import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

// Top-level background message handler for Firebase
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Fill these from Firebase Console -> Project Settings -> Web App + Cloud Messaging Web Push certificates (VAPID Key)
  static const String webApiKey = '';
  static const String webAppId = '';
  static const String webMessagingSenderId = '914782829465';
  static const String webProjectId = 'project-513606';
  static const String webVapidKey = 'BKRr0al-IX3B0ZttyzNCuGBlYTV-HAupZigQqpUbsvmwXbpx1OmpnhHCEAC2MJHDHaM86yhHX5GfHPkPOQ9JWVo';

  bool _isInitialized = false;
  bool _listenerAttached = false;
  String? _fcmToken;

  bool get isInitialized => _isInitialized;
  bool get isConfiguredForWeb => webApiKey.isNotEmpty && webAppId.isNotEmpty && webVapidKey.isNotEmpty;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    if (!_listenerAttached) {
      _listenerAttached = true;
      ApiService().authNotifier.addListener(() {
        final user = ApiService().currentUser;
        if (user != null && _fcmToken != null && _fcmToken!.isNotEmpty) {
          ApiService().saveFcmToken(_fcmToken!);
        }
      });
    }

    try {
      debugPrint('Initializing Firebase Cloud Messaging...');

      if (kIsWeb) {
        if (!isConfiguredForWeb) {
          _isInitialized = true;
          debugPrint('FCM Web awaiting Firebase Console Web App config (apiKey, appId, vapidKey).');
          return;
        }
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: webApiKey,
            appId: webAppId,
            messagingSenderId: webMessagingSenderId,
            projectId: webProjectId,
            authDomain: '$webProjectId.firebaseapp.com',
            storageBucket: '$webProjectId.appspot.com',
          ),
        );
      } else {
        await Firebase.initializeApp();
      }

      _isInitialized = true;
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('Firebase Permission status: ${settings.authorizationStatus}');

      _fcmToken = kIsWeb
          ? await messaging.getToken(vapidKey: webVapidKey)
          : await messaging.getToken();

      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        debugPrint('Firebase FCM Device Token registered.');
        await ApiService().saveFcmToken(_fcmToken!);
      }

      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        ApiService().saveFcmToken(newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground FCM Notification: ${message.notification?.title} - ${message.notification?.body}');
      });

      debugPrint('Firebase Cloud Messaging initialized successfully!');
    } catch (e) {
      _isInitialized = true;
      debugPrint('Firebase Messaging running in standby mode: $e');
    }
  }
}
