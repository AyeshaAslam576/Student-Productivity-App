class AppValidators {
  AppValidators._();

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.isEmpty) return 'Name is required';
    if (value.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? creditHours(String? value) {
    if (value == null || value.isEmpty) return 'Credit hours required';
    final n = int.tryParse(value);
    if (n == null || n < 1 || n > 6) return 'Credit hours must be 1-6';
    return null;
  }

  static String? marks(String? value) {
    if (value == null || value.isEmpty) return 'Marks required';
    final n = double.tryParse(value);
    if (n == null || n < 0 || n > 100) return 'Marks must be between 0-100';
    return null;
  }

  static String? url(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    final urlRegex = RegExp(
        r'^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$');
    if (!urlRegex.hasMatch(value)) return 'Enter a valid URL';
    return null;
  }
}
