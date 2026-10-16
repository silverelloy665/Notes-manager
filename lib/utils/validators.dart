/// Pure static validation helper methods returning null when valid or a descriptive error string.
class Validators {
  Validators._();

  /// Regex pattern for standard RFC email validation.
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  /// Regex for alphabetic names with allowed spaces.
  static final RegExp _nameRegex = RegExp(r"^[a-zA-Z\s]+$");

  /// Regex for Indian standard mobile phone numbers (10 digits starting with 6, 7, 8, or 9).
  static final RegExp _phoneRegex = RegExp(r'^[6-9]\d{9}$');

  /// Regex for 6-character alphanumeric classroom join codes.
  static final RegExp _classCodeRegex = RegExp(r'^[A-Za-z0-9]{6}$');

  /// Validates that a string is non-null and not blank.
  static String? validateRequired(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  /// Validates that a string meets a minimum character length.
  static String? validateMinLength(
    String? value,
    int minLength, [
    String fieldName = 'This field',
  ]) {
    final requiredCheck = validateRequired(value, fieldName);
    if (requiredCheck != null) return requiredCheck;
    if (value!.trim().length < minLength) {
      return '$fieldName must be at least $minLength characters long.';
    }
    return null;
  }

  /// Validates that a user's full name contains only alphabets and spaces, and is at least 2 characters.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters.';
    }
    if (!_nameRegex.hasMatch(trimmed)) {
      return 'Name must contain letters and spaces only.';
    }
    return null;
  }

  /// Validates email address format.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }
    final trimmed = value.trim();
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address (e.g., student@domain.com).';
    }
    return null;
  }

  /// Validates a 10-digit mobile phone number starting with 6, 7, 8, or 9.
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    final trimmed = value.trim();
    if (trimmed.length != 10) {
      return 'Phone number must be exactly 10 digits.';
    }
    if (!_phoneRegex.hasMatch(trimmed)) {
      return 'Phone number must be 10 digits starting with 6, 7, 8, or 9.';
    }
    return null;
  }

  /// Validates password security (minimum 8 characters, at least 1 uppercase letter, at least 1 number).
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one numeric digit.';
    }
    return null;
  }

  /// Validates that confirm password matches the primary password.
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != password) {
      return 'Passwords do not match.';
    }
    return null;
  }

  /// Validates a 6-character alphanumeric classroom join code.
  static String? validateClassCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Classroom code is required.';
    }
    final trimmed = value.trim();
    if (trimmed.length != 6 || !_classCodeRegex.hasMatch(trimmed)) {
      return 'Classroom code must be exactly 6 letters/digits.';
    }
    return null;
  }

  /// Validates maximum marks between 1 and 1000.
  static String? validateMaxMarks(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Maximum marks is required.';
    }
    final numValue = double.tryParse(value.trim());
    if (numValue == null) {
      return 'Maximum marks must be a valid number.';
    }
    if (numValue < 1 || numValue > 1000) {
      return 'Maximum marks must be between 1 and 1000.';
    }
    return null;
  }

  /// Validates marks obtained (numeric, non-negative, and not greater than maximum marks).
  static String? validateMarksObtained(String? value, double? maxMarks) {
    if (value == null || value.trim().isEmpty) {
      return 'Marks obtained is required.';
    }
    final numValue = double.tryParse(value.trim());
    if (numValue == null) {
      return 'Marks obtained must be a valid number.';
    }
    if (numValue < 0) {
      return 'Marks obtained cannot be negative.';
    }
    if (maxMarks != null && numValue > maxMarks) {
      return 'Marks obtained cannot exceed maximum marks ($maxMarks).';
    }
    return null;
  }
}

