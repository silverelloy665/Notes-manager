import 'package:firebase_auth/firebase_auth.dart';

/// Custom application exception for user-facing domain, Firebase, and parser errors.
class AppException implements Exception {
  final String message;

  const AppException(this.message);

  /// Map FirebaseAuthException codes to clear, friendly user messages.
  factory AppException.fromFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return const AppException(
          'An account with this email address already exists. Please log in or use a different email.',
        );
      case 'wrong-password':
      case 'invalid-credential':
        return const AppException(
          'Incorrect email or password. Please verify your credentials.',
        );
      case 'user-not-found':
        return const AppException(
          'No account found with this email address. Please register first.',
        );
      case 'network-request-failed':
        return const AppException(
          'Network connection error. Please verify your internet connection and try again.',
        );
      case 'too-many-requests':
        return const AppException(
          'Too many failed attempts. Please wait a few moments and try again.',
        );
      case 'weak-password':
        return const AppException(
          'The password is too weak. Please choose a stronger password.',
        );
      case 'user-disabled':
        return const AppException(
          'This user account has been disabled by an administrator.',
        );
      case 'operation-not-allowed':
        return const AppException(
          'Email/Password sign-in is not enabled in the Firebase Console.',
        );
      default:
        return AppException(
          e.message?.isNotEmpty == true
              ? e.message!
              : 'Authentication failed. Please verify your details and try again.',
        );
    }
  }

  /// Map FirebaseException codes to clear, friendly user messages.
  factory AppException.fromFirebase(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const AppException(
          'Access denied: You do not have permission to view or modify this record.',
        );
      case 'unavailable':
        return const AppException(
          'Cloud service is currently unavailable. Working with offline cached data.',
        );
      case 'not-found':
        return const AppException(
          'The requested record or resource was not found in the database.',
        );
      case 'deadline-exceeded':
        return const AppException(
          'Database operation timed out. Please check your connectivity and retry.',
        );
      case 'already-exists':
        return const AppException(
          'A record with this identifier already exists.',
        );
      default:
        return AppException(
          e.message?.isNotEmpty == true
              ? e.message!
              : 'A database error occurred. Please try again.',
        );
    }
  }

  @override
  String toString() => message;
}
