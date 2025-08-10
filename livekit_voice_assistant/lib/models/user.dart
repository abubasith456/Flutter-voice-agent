class AppUser {
  final String id;
  final String name;

  const AppUser({required this.id, required this.name});
}

class SelectedUserArgs {
  final AppUser selectedUser;
  final String? roomName;
  const SelectedUserArgs(this.selectedUser, {this.roomName});
}