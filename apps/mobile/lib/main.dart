import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/firebase_service.dart';
import 'services/api_service.dart';
import 'services/language_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Session, Language & Firebase Integration
  await ApiService().init();
  await LanguageService().init();
  await FirebaseService().initialize();

  runApp(
    const ProviderScope(
      child: SpacesApp(),
    ),
  );
}

