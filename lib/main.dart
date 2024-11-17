import 'package:flutter/material.dart';
import 'package:raimon_ai/screens/initial_form_screen.dart';
import 'package:raimon_ai/screens/qr_scanner_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/menu_screen.dart'; // Actualizar import
import 'screens/chat_screen.dart';
import 'screens/introduction_screen.dart';
import 'screens/results_screen.dart';

const supabaseUrl = 'https://gkhunoslayeiitipmkkz.supabase.co';
const supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdraHVub3NsYXllaWl0aXBta2t6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzE3NTU3MzksImV4cCI6MjA0NzMzMTczOX0.Gr13V2YCbzPXRh3FjY4lldZeVA2agdF8PTRkv7_B1jk';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raimon AI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/', // Volver a la ruta inicial
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/menu': (context) => const MenuScreen(), // Cambiar ruta de home a menu
        '/introduction': (context) => const IntroductionScreen(),
        '/chat': (context) => const ChatScreen(),
        '/results': (context) => const ResultsScreen(),
        '/initial_form': (context) => const InitialFormScreen(),
        '/qr_scanner': (context) => const QRScannerScreen(),
      },
    );
  }
}
