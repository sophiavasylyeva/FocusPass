import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'services/screen_time_service.dart';
import 'utils/constants.dart';
import 'package:firebase_core/firebase_core.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized(); // Ensures proper setup
//   await Firebase.initializeApp(); // Initializes Firebase
//   print(Firebase.apps);
//   runApp(FocusPassApp());
// }
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully!");
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
  }

  runApp(FocusPassApp());
}


class FocusPassApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusPass',
      theme: ThemeData(
        scaffoldBackgroundColor: kBackgroundWhite,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: kPrimaryBrown,
          secondary: kAccentGreen,
        ),
        textTheme: ThemeData.light().textTheme.copyWith(
          headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      home: WelcomeScreen(),
    );
  }
}
