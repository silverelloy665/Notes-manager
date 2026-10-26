import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/screens/auth/login_screen.dart';
import 'package:studymate_classroom/screens/student/library_tab.dart';
import 'package:studymate_classroom/screens/student/practice_tab.dart';
import 'package:studymate_classroom/screens/student/student_classrooms_tab.dart';
import 'package:studymate_classroom/screens/student/student_notes_tab.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/phone_frame_wrapper.dart';

/// Main container screen for Students, hosting Notes, Practice, Library, and Classrooms tabs.
/// Recreated with Botanical Watercolor presentation aesthetic:
/// - Cream paper header with deep green icons and Cardo typography.
/// - Active navigation marker with tiny leaf icon.
/// - Calm mode toggle (distraction-free focus).
/// - Charcoal botanical dark mode variant toggle.
class StudentHomeScreen extends StatefulWidget {
  final User currentUser;

  const StudentHomeScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sign Out', style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of your study workspace?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FirestoreService.instance.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = [
      StudentNotesTab(currentUser: widget.currentUser),
      const PracticeTab(),
      LibraryTab(userId: widget.currentUser.id),
      StudentClassroomsTab(currentUser: widget.currentUser),
    ];

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkSlateBase : AppTheme.creamPaper,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSlateBase : AppTheme.creamPaper,
        foregroundColor: isDark ? const Color(0xFFE8F5E9) : AppTheme.inkForest,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.spa_rounded,
                  color: isDark ? const Color(0xFF81C784) : AppTheme.inkForest,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'StudyMate Classroom',
                  style: TextStyle(
                    fontFamily: AppTheme.fontCardo,
                    fontSize: 18.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                    color: isDark ? const Color(0xFFE8F5E9) : AppTheme.inkForest,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                'Student Workspace • ${widget.currentUser.name}',
                style: TextStyle(
                  fontFamily: AppTheme.fontZilla,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Phone / Desktop Frame Switcher Toggle
          ValueListenableBuilder<bool>(
            valueListenable: PhoneFrameWrapper.isPhoneMode,
            builder: (context, isPhone, _) {
              return IconButton(
                tooltip: isPhone ? 'Switch to Full Desktop View' : 'Switch to Mobile Phone View',
                icon: Icon(
                  isPhone ? Icons.desktop_windows_outlined : Icons.smartphone_outlined,
                  color: isDark ? const Color(0xFFA5D6A7) : AppTheme.inkForest,
                ),
                onPressed: () => PhoneFrameWrapper.toggle(),
              );
            },
          ),
          // Calm Mode Toggle
          ValueListenableBuilder<bool>(
            valueListenable: AppTheme.calmModeNotifier,
            builder: (context, isCalm, _) {
              return IconButton(
                tooltip: isCalm ? 'Calm Mode Active (Click to show botanical artwork)' : 'Calm Mode (Zero Distraction)',
                icon: Icon(
                  isCalm ? Icons.filter_vintage_outlined : Icons.filter_vintage_rounded,
                  color: isCalm
                      ? (isDark ? const Color(0xFF81C784) : AppTheme.accentPeach)
                      : (isDark ? const Color(0xFFA5D6A7) : AppTheme.inkForest),
                ),
                onPressed: () {
                  AppTheme.toggleCalmMode();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 1400),
                      content: Text(
                        AppTheme.isCalmMode
                            ? '🌿 Calm Mode activated: Clean paper & distraction-free typography'
                            : '🌸 Botanical Artwork & watercolor washes restored',
                        style: const TextStyle(fontFamily: AppTheme.fontZilla),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // Charcoal Botanical Dark Mode Toggle
          IconButton(
            tooltip: isDark ? 'Switch to Cream Paper Light Theme' : 'Switch to Charcoal Botanical Dark Theme',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? const Color(0xFFA5D6A7) : AppTheme.inkForest,
            ),
            onPressed: () => AppTheme.toggleThemeMode(),
          ),
          // Sign out
          IconButton(
            tooltip: 'Sign Out',
            icon: Icon(
              Icons.logout_rounded,
              color: isDark ? const Color(0xFFA5D6A7) : AppTheme.inkForest,
            ),
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSageCard : AppTheme.creamPaper,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkBronzeBorder : AppTheme.borderColor,
              width: 1.2,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? AppTheme.darkSageCard : AppTheme.creamPaper,
          selectedItemColor: isDark ? const Color(0xFF81C784) : AppTheme.inkForest,
          unselectedItemColor: isDark ? const Color(0xFF7D9789) : AppTheme.textMuted,
          selectedLabelStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12),
          items: [
            _buildBotanicalNavItem(icon: Icons.note_alt_outlined, activeIcon: Icons.note_alt, label: 'Notes', isSelected: _currentIndex == 0, isDark: isDark),
            _buildBotanicalNavItem(icon: Icons.quiz_outlined, activeIcon: Icons.quiz, label: 'Practice', isSelected: _currentIndex == 1, isDark: isDark),
            _buildBotanicalNavItem(icon: Icons.library_books_outlined, activeIcon: Icons.library_books, label: 'Library', isSelected: _currentIndex == 2, isDark: isDark),
            _buildBotanicalNavItem(icon: Icons.school_outlined, activeIcon: Icons.school, label: 'Classrooms', isSelected: _currentIndex == 3, isDark: isDark),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildBotanicalNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      activeIcon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active item marked by tiny botanical leaf marker
          Icon(
            Icons.eco_rounded,
            size: 13,
            color: isDark ? const Color(0xFF81C784) : AppTheme.inkForest,
          ),
          const SizedBox(height: 1),
          Icon(activeIcon, size: 21),
        ],
      ),
      label: label,
    );
  }
}
