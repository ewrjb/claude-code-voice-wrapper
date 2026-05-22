import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final hasToken = prefs.getString('jwt_token') != null;

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStateNotifier(),
      child: VoiceDevApp(startLoggedIn: hasToken),
    ),
  );
}

class VoiceDevApp extends StatelessWidget {
  final bool startLoggedIn;

  const VoiceDevApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceDev',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      initialRoute: startLoggedIn ? '/main' : '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/main': (_) => const MainScreen(),
      },
    );
  }
}
