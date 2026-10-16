import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/database_service.dart';
import '../../utils/app_exception.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../student/student_home_screen.dart';
import '../teacher/teacher_home_screen.dart';

/// Screen allowing new users to register as a Student or Teacher.
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
      final user = await DatabaseService.instance.registerUser(
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

      // Route to appropriate home screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => user.isTeacher
              ? TeacherHomeScreen(currentUser: user)
              : StudentHomeScreen(currentUser: user),
        ),
        (route) => false,
      );
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
          content: Text('Registration failed: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingLg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'User Registration',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Please complete the fields below to register.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Full Name
                            CustomTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              hint: 'Enter your full name (letters only)',
                              textCapitalization: TextCapitalization.words,
                              prefixIcon: const Icon(Icons.person_outline, size: 20),
                              validator: Validators.validateName,
                            ),
                            const SizedBox(height: 16),

                            // Email Address
                            CustomTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              hint: 'example@domain.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(Icons.email_outlined, size: 20),
                              validator: Validators.validateEmail,
                            ),
                            const SizedBox(height: 16),

                            // 10-digit Phone
                            CustomTextField(
                              controller: _phoneController,
                              label: 'Phone Number (10 digits)',
                              hint: '9876543210',
                              keyboardType: TextInputType.phone,
                              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: Validators.validatePhone,
                            ),
                            const SizedBox(height: 16),

                            // Role Selection Dropdown
                            const Text(
                              'Select Role',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedRole,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.badge_outlined, size: 20),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Student',
                                  child: Text('Student (View notes, practice, track grades)'),
                                ),
                                DropdownMenuItem(
                                  value: 'Teacher',
                                  child: Text('Teacher (Create classrooms, grade, add questions)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedRole = val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password
                            CustomTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Min 8 chars, 1 uppercase & 1 number',
                              isPassword: true,
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              validator: Validators.validatePassword,
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password
                            CustomTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              hint: 'Re-enter your password',
                              isPassword: true,
                              prefixIcon: const Icon(Icons.lock_reset_outlined, size: 20),
                              validator: (val) => Validators.validateConfirmPassword(
                                val,
                                _passwordController.text,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Submit Button
                            PrimaryButton(
                              label: 'Create Account',
                              icon: Icons.person_add_alt_1,
                              isLoading: _isLoading,
                              onPressed: _handleRegister,
                            ),
                          ],
                        ),
                      ),
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
