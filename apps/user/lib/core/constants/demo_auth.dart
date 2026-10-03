/// Demo household customer used by Quick Demo Access.
/// Register/login goes through the shared Node `/api/auth` gateway (role USER).
class DemoUserAuth {
  static const String phoneNumber = '9000012345';
  static const String name = 'Ananya Sharma';
  static const String city = 'Pune';
  static const String role = 'USER';

  /// Public demo password (min 8 chars for `/api/auth/register`). Not a prod secret.
  static const String password = 'DemoUser1';
}
