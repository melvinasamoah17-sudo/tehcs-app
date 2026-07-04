import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  String? firebaseError;
  try {
    debugPrint('Initializing Firebase Core...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase Core initialized successfully');
  } catch (e) {
    debugPrint('Firebase Core initialization error: $e');
    firebaseError = e.toString();
  }

  runApp(TEHCSApp(firebaseError: firebaseError));
}

class TEHCSApp extends StatelessWidget {
  final String? firebaseError;
  const TEHCSApp({super.key, this.firebaseError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TEHCS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: firebaseError != null 
        ? Scaffold(body: Center(child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('Firebase Error: $firebaseError\n\nPlease check your configuration.', textAlign: TextAlign.center),
          )))
        : const SplashScreen(),
    );
  }
}
