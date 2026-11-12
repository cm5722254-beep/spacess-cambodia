import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/firebase_service.dart';
import 'services/api_service.dart';
import 'services/language_service.dart';
import 'services/realtime_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Session, Language, Real-time SSE & Firebase Integration
  await ApiService().init();
  await LanguageService().init();
  await FirebaseService().initialize();
  RealtimeService().init();

  runApp(
    const ProviderScope(
      child: SpacesApp(),
    ),
  );
}

