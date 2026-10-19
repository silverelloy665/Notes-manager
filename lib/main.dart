import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/common/firebase_not_configured_screen.dart';
import 'services/firestore_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isFirebaseReady = false;
  String? firebaseError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseReady = true;
    // Ensure foundational practice questions are seeded in Cloud Firestore
    FirestoreService.instance.seedInitialQuestions().ignore();
  } catch (e) {
    isFirebaseReady = false;
    firebaseError = e.toString();
  }

  runApp(StudyMateApp(
    isFirebaseReady: isFirebaseReady,
    firebaseError: firebaseError,
  ));
}

/// Root widget of the StudyMate Classroom application.
class StudyMateApp extends StatefulWidget {
  final bool isFirebaseReady;
  final String? firebaseError;

  const StudyMateApp({
    super.key,
    required this.isFirebaseReady,
    this.firebaseError,
  });

  @override
  State<StudyMateApp> createState() => _StudyMateAppState();
}

class _StudyMateAppState extends State<StudyMateApp> {
  late bool _isReady;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isReady = widget.isFirebaseReady;
    _error = widget.firebaseError;
  }

  Future<void> _retryInitialization() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      setState(() {
        _isReady = true;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isReady = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyMate Classroom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _isReady
          ? const LoginScreen()
          : FirebaseNotConfiguredScreen(
              errorMessage: _error,
              onRetry: _retryInitialization,
            ),
    );
  }
}
