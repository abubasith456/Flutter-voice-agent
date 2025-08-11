import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
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
      home: const PermissionInitializer(child: UserSelectionScreen()),
      onGenerateRoute: (settings) {
        if (settings.name == MainScreen.routeName) {
          final args = settings.arguments as SelectedUserArgs;
          return MaterialPageRoute(
            builder: (_) => MainScreen(selectedUser: args.selectedUser),
          );
        }
        return null;
      },
    );
  }
}

class PermissionInitializer extends StatefulWidget {
  final Widget child;
  const PermissionInitializer({super.key, required this.child});

  @override
  State<PermissionInitializer> createState() => _PermissionInitializerState();
}

class _PermissionInitializerState extends State<PermissionInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestMic());
  }

  Future<void> _requestMic() async {
    if (kIsWeb) return;
    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) return;
      if (status.isPermanentlyDenied || status.isRestricted) return; // user must enable in Settings
      await Permission.microphone.request();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
