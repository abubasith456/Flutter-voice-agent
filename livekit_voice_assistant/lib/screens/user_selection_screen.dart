import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user.dart';
import 'main_screen.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final List<AppUser> demoUsers = const [
    AppUser(id: '12345', name: 'Abu'),
    AppUser(id: '6789', name: 'Gowtham'),
  ];

  AppUser? selectedUser;
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _roomCtrl = TextEditingController(text: dotenv.env['LIVEKIT_ROOM_NAME'] ?? 'voice-assistant-room');

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    AppUser user = selectedUser ?? AppUser(id: _idCtrl.text.trim(), name: _nameCtrl.text.trim());
    Navigator.of(context).pushNamed(
      MainScreen.routeName,
      arguments: SelectedUserArgs(user, roomName: _roomCtrl.text.trim().isEmpty ? null : _roomCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select User')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text('Quick pick', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...demoUsers.map((user) {
                    final isSelected = selectedUser?.id == user.id;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                      title: Text(user.name),
                      subtitle: Text('ID: ${user.id}'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.circle_outlined),
                      onTap: () => setState(() => selectedUser = user),
                    );
                  }),
                  const Divider(height: 32),
                  Text('Custom user', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _idCtrl,
                    decoration: const InputDecoration(labelText: 'User ID'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'User Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _roomCtrl,
                    decoration: const InputDecoration(labelText: 'Room Name'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Note: This is the demo voice assistance. The user is manually selected in real-time. The actual user will be based on credentials when this plugin is integrated.',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
                onPressed: () {
                  if (selectedUser == null && (_idCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter ID and Name or pick a demo user')));
                    return;
                  }
                  _continue();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}