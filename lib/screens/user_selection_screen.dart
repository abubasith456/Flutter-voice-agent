import 'package:flutter/material.dart';
import '../models/user.dart';
import 'main_screen.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  final List<AppUser> demoUsers = const [
    AppUser(id: '12345', name: 'Abu Basith', otp: "9585"),
    AppUser(id: '6789', name: 'Aravind Babu', otp: "8765"),
  ];

  AppUser? selectedUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select User')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: demoUsers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = demoUsers[index];
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
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: This is the demo voice assistance. The user is manually selected in real-time. The actual user will be based on credentials when this plugin is integrated.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
                onPressed: selectedUser == null
                    ? null
                    : () {
                        Navigator.of(context).pushNamed(
                          MainScreen.routeName,
                          arguments: SelectedUserArgs(selectedUser!),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
