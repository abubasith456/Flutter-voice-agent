class AppUser {
  final String id;
  final String name;

  const AppUser({required this.id, required this.name});
}

class SelectedUserArgs {
  final AppUser selectedUser;
  const SelectedUserArgs(this.selectedUser);
}