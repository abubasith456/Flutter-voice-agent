class AppUser {
  final String id;
  final String name;
  final String otp;

  const AppUser({required this.id, required this.name, required this.otp});
}

class SelectedUserArgs {
  final AppUser selectedUser;
  const SelectedUserArgs(this.selectedUser);
}
