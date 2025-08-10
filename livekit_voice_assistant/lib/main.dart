import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/user.dart';
import 'screens/user_selection_screen.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env").catchError((_) async {
    // Fallback to .env.example if .env is missing (dev convenience)
    try {
      await dotenv.load(fileName: ".env.example");
    } catch (_) {}
  });
  runApp(const VoiceAssistantApp());
}

class VoiceAssistantApp extends StatelessWidget {
  const VoiceAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiveKit Voice Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const UserSelectionScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == MainScreen.routeName) {
          final args = settings.arguments as SelectedUserArgs;
          return MaterialPageRoute(
            builder: (_) => MainScreen(selectedUser: args.selectedUser, roomName: args.roomName),
          );
        }
        return null;
      },
    );
  }
}
