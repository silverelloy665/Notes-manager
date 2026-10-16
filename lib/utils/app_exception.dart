/// Custom application exception for user-facing domain and database errors.
class AppException implements Exception {
  final String message;

  const AppException(this.message);

  @override
  String toString() => message;
}

