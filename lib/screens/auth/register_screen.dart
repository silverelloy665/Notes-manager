import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/screens/student/student_home_screen.dart';
import 'package:studymate_classroom/screens/teacher/teacher_home_screen.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_exception.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/utils/validators.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/primary_button.dart';

/// Screen allowing new users to register as a Student or Teacher using Firebase Auth and Firestore.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'Student';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await FirestoreService.instance.register(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        role: _selectedRole,
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created successfully! Welcome, ${user.name}'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      _navigateUser(user);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateUser(User user) {
    if (user.isTeacher) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => TeacherHomeScreen(currentUser: user)),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => StudentHomeScreen(currentUser: user)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTheme.maxFormWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Join StudyMate Classroom',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A202C),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Role Selector Segmented Controls
                            const Text(
                              'Select Your Role',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'Student',
                                  label: Text('Student'),
                                  icon: Icon(Icons.school_outlined),
                                ),
                                ButtonSegment(
                                  value: 'Teacher',
                                  label: Text('Teacher'),
                                  icon: Icon(Icons.co_present_outlined),
                                ),
                              ],
                              selected: {_selectedRole},
                              onSelectionChanged: (newSelection) {
                                setState(() => _selectedRole = newSelection.first);
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              hintText: 'Enter your full name (letters only)',
                              textCapitalization: TextCapitalization.words,
                              prefixIcon: Icons.person_outline,
                              validator: Validators.validateName,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              hintText: 'student@domain.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.email_outlined,
                              validator: Validators.validateEmail,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _phoneController,
                              label: 'Phone Number (10 digits)',
                              hintText: '9876543210',
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_outlined,
                              maxLength: 10,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: Validators.validatePhone,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hintText: 'Min 8 chars, 1 uppercase & 1 number',
                              isPassword: true,
                              prefixIcon: Icons.lock_outline,
                              validator: Validators.validatePassword,
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              hintText: 'Re-enter your password',
                              isPassword: true,
                              prefixIcon: Icons.lock_outline,
                              validator: (val) => Validators.validateConfirmPassword(
                                val,
                                _passwordController.text,
                              ),
                            ),
                            const SizedBox(height: 24),
                            PrimaryButton(
                              text: 'Create Account',
                              isLoading: _isLoading,
                              icon: Icons.person_add_rounded,
                              onPressed: _handleRegister,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?', style: TextStyle(color: Colors.grey.shade700)),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
