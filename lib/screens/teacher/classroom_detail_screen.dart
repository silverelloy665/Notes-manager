import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate_classroom/models/announcement_model.dart';
import 'package:studymate_classroom/models/classroom_model.dart';
import 'package:studymate_classroom/models/grade_model.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/screens/student/student_grades_screen.dart';
import 'package:studymate_classroom/screens/teacher/student_grade_history_screen.dart';
import 'package:studymate_classroom/services/export_service.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';
import 'package:studymate_classroom/widgets/primary_button.dart';
import 'package:studymate_classroom/widgets/watercolor_blob_container.dart';

/// Full-featured Classroom Workspace shell for Faculty and Students.
/// Supports 8 tabs:
/// Overview · Notes · Question Bank · Exams · Assignments · Live Class · Students · Analytics
class ClassroomDetailScreen extends StatefulWidget {
  final Classroom classroom;
  final User currentUser;
  final User? teacher;

  ClassroomDetailScreen({
    super.key,
    required this.classroom,
    User? currentUser,
    this.teacher,
  }) : currentUser = currentUser ?? teacher!;

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Classroom _classroom;
  List<StudentGradeSummary> _students = [];
  bool _isLoadingStudents = true;
  String _studentSearchQuery = '';

  // Stream announcement composer controllers
  final TextEditingController _announcementController = TextEditingController();
  bool _isPinnedAnnouncement = false;
  bool _isPostingAnnouncement = false;
  final List<AnnouncementAttachment> _stagedAttachments = [];

  // Roster search controller
  final TextEditingController _searchController = TextEditingController();

  static const List<({String label, IconData icon})> _workspaceTabs = [
    (label: 'Overview', icon: Icons.dashboard_outlined),
    (label: 'Notes', icon: Icons.description_outlined),
    (label: 'Question Bank', icon: Icons.quiz_outlined),
    (label: 'Exams', icon: Icons.assignment_outlined),
    (label: 'Assignments', icon: Icons.task_alt_outlined),
    (label: 'Live Class', icon: Icons.videocam_outlined),
    (label: 'Students', icon: Icons.people_outline),
    (label: 'Analytics', icon: Icons.bar_chart_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _classroom = widget.classroom;
    _tabController = TabController(length: _workspaceTabs.length, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _announcementController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isTeacher {
    return widget.currentUser.isTeacher &&
        (_classroom.teacherId == widget.currentUser.id ||
            _classroom.coTeacherIds.contains(widget.currentUser.id));
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final list = await FirestoreService.instance.getStudentSummaries(
        _classroom.id,
        _classroom.studentIds,
      );
      if (mounted) {
        setState(() {
          _students = list;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  void _copyClassCode() {
    Clipboard.setData(ClipboardData(text: _classroom.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Join code "${_classroom.code}" copied to clipboard!'),
        backgroundColor: AppTheme.inkForest,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareInviteText() {
    final text = 'Join my classroom "${_classroom.name}" (${_classroom.subject}) on StudyMate using join code: ${_classroom.code}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Classroom invite message copied to clipboard! Share it with your students.'),
        backgroundColor: AppTheme.inkForest,
      ),
    );
  }

  void _showQrCodeModal() {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Classroom Join Code & QR',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.sageBlob, width: 2),
              ),
              child: Column(
                children: [
                  // High contrast botanical QR pattern representation
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      color: AppTheme.creamPaper,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.inkForest.withValues(alpha: 0.3)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        GridPaper(
                          color: AppTheme.inkForest.withValues(alpha: 0.15),
                          divisions: 4,
                          subdivisions: 2,
                          interval: 32,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.inkForest,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            _classroom.code,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _classroom.name,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontCardo,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.inkForest,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _classroom.subject,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontZilla,
                      fontSize: 14,
                      color: AppTheme.charcoalSlate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.mintWash.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Students: open StudyMate > Classrooms > Join and enter code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontZilla,
                        fontSize: 12,
                        color: AppTheme.inkForest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        confirmText: 'Copy Code',
        onConfirm: () {
          Navigator.of(ctx).pop();
          _copyClassCode();
        },
      ),
    );
  }

  void _showRegenerateCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Regenerate Join Code?',
        content: const Text(
          'A new 6-character code will be generated. The old code will expire immediately. Enrolled students will remain enrolled.',
          style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 14, color: AppTheme.charcoalSlate),
        ),
        confirmText: 'Regenerate',
        confirmColor: AppTheme.errorColor,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          try {
            final newCode = await FirestoreService.instance.regenerateClassroomCode(
              classroomId: _classroom.id,
              oldCode: _classroom.code,
              teacherId: widget.currentUser.id,
            );
            if (mounted) {
              setState(() {
                _classroom = _classroom.copyWith(code: newCode);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('New join code generated: $newCode'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor),
              );
            }
          }
        },
      ),
    );
  }

  void _showSettingsModal() {
    final nameCtrl = TextEditingController(text: _classroom.name);
    final subjectCtrl = TextEditingController(text: _classroom.subject);
    final descCtrl = TextEditingController(text: _classroom.description ?? '');
    bool isJoiningEnabled = _classroom.isJoiningEnabled;
    bool requireApproval = _classroom.requireApproval;
    bool isArchived = _classroom.isArchived;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.creamPaper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Classroom Settings',
                      style: TextStyle(
                        fontFamily: AppTheme.fontCardo,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppTheme.inkForest,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: nameCtrl,
                  label: 'Classroom Name',
                  hintText: 'e.g. Operating Systems CE',
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: subjectCtrl,
                  label: 'Subject / Code',
                  hintText: 'e.g. CS 301 - Operating Systems',
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: descCtrl,
                  label: 'Description / Syllabus (Optional)',
                  hintText: 'Semester overview, office hours, grading policy...',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Divider(),
                SwitchListTile(
                  title: const Text(
                    'Allow Students to Join via Code',
                    style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('When disabled, new students entering the code cannot join.'),
                  value: isJoiningEnabled,
                  activeThumbColor: AppTheme.inkForest,
                  onChanged: (v) => setModalState(() => isJoiningEnabled = v),
                ),
                SwitchListTile(
                  title: const Text(
                    'Require Join Approval',
                    style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Students are placed in a pending queue until you approve them.'),
                  value: requireApproval,
                  activeThumbColor: AppTheme.inkForest,
                  onChanged: (v) => setModalState(() => requireApproval = v),
                ),
                SwitchListTile(
                  title: const Text(
                    'Archive Classroom',
                    style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Makes classroom read-only for students and hides from active lists.'),
                  value: isArchived,
                  activeThumbColor: AppTheme.warningColor,
                  onChanged: (v) => setModalState(() => isArchived = v),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showDeleteClassroomDialog();
                        },
                        child: const Text('Delete Classroom'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        text: 'Save Settings',
                        onPressed: () async {
                          try {
                            await FirestoreService.instance.updateClassroomSettings(
                              _classroom.id,
                              name: nameCtrl.text,
                              subject: subjectCtrl.text,
                              description: descCtrl.text,
                              isJoiningEnabled: isJoiningEnabled,
                              requireApproval: requireApproval,
                              isArchived: isArchived,
                            );
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            if (mounted) {
                              setState(() {
                                _classroom = _classroom.copyWith(
                                  name: nameCtrl.text.trim(),
                                  subject: subjectCtrl.text.trim(),
                                  description: descCtrl.text.trim(),
                                  isJoiningEnabled: isJoiningEnabled,
                                  requireApproval: requireApproval,
                                  isArchived: isArchived,
                                );
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Classroom settings updated successfully!'),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteClassroomDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Permanently Delete Classroom?',
        content: Text(
          'Are you sure you want to delete "${_classroom.name}"? This action cannot be undone. All stream posts, student links, and class code will be deleted.',
          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 14, color: AppTheme.charcoalSlate),
        ),
        confirmText: 'Delete Classroom',
        confirmColor: AppTheme.errorColor,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          try {
            await FirestoreService.instance.deleteClassroom(
              classroomId: _classroom.id,
              code: _classroom.code,
            );
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Classroom "${_classroom.name}" deleted.'),
                  backgroundColor: AppTheme.inkForest,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _handlePostAnnouncement() async {
    final text = _announcementController.text.trim();
    if (text.isEmpty && _stagedAttachments.isEmpty) return;

    setState(() => _isPostingAnnouncement = true);
    try {
      await FirestoreService.instance.postAnnouncement(
        classroomId: _classroom.id,
        authorId: widget.currentUser.id,
        authorName: widget.currentUser.name,
        authorRole: widget.currentUser.role,
        content: text,
        attachments: List.from(_stagedAttachments),
        pinned: _isPinnedAnnouncement,
      );

      _announcementController.clear();
      _stagedAttachments.clear();
      _isPinnedAnnouncement = false;
      if (mounted) {
        setState(() => _isPostingAnnouncement = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement posted to class stream.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPostingAnnouncement = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showAddAttachmentDialog() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String type = 'link';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => CustomDialog(
          title: 'Add Announcement Attachment',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Attachment Type'),
                items: const [
                  DropdownMenuItem(value: 'link', child: Text('External Web Link / Video')),
                  DropdownMenuItem(value: 'note', child: Text('Classroom Note Reference')),
                  DropdownMenuItem(value: 'file', child: Text('Document Resource')),
                ],
                onChanged: (v) => setDlgState(() => type = v ?? 'link'),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: nameCtrl,
                label: 'Display Title',
                hintText: 'e.g. Unit 1 Lecture Slides',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: urlCtrl,
                label: 'URL or Reference Link',
                hintText: 'https://...',
              ),
            ],
          ),
          confirmText: 'Add Attachment',
          onConfirm: () {
            if (nameCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) return;
            setState(() {
              _stagedAttachments.add(AnnouncementAttachment(
                name: nameCtrl.text.trim(),
                url: urlCtrl.text.trim(),
                type: type,
              ));
            });
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  void _exportRosterCsv() {
    final csvContent = ExportService.instance.generateRosterCsv(_classroom, _students);
    Clipboard.setData(ClipboardData(text: csvContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Roster CSV copied to clipboard (${_students.length} students). You can paste it into Excel or Google Sheets.'),
        backgroundColor: AppTheme.inkForest,
        action: SnackBarAction(
          label: 'OK',
          textColor: AppTheme.mintWash,
          onPressed: () {},
        ),
      ),
    );
  }

  void _removeStudent(StudentGradeSummary student) {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Remove Student?',
        content: Text(
          'Are you sure you want to remove ${student.studentName} (${student.studentEmail}) from this classroom?',
          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 14, color: AppTheme.charcoalSlate),
        ),
        confirmText: 'Remove',
        confirmColor: AppTheme.errorColor,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          try {
            await FirestoreService.instance.removeStudentFromClassroom(
              classroomId: _classroom.id,
              studentId: student.studentId,
            );
            if (mounted) {
              setState(() {
                _classroom = _classroom.copyWith(
                  studentIds: _classroom.studentIds.where((id) => id != student.studentId).toList(),
                );
                _students.removeWhere((s) => s.studentId == student.studentId);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${student.studentName} removed from classroom.'),
                  backgroundColor: AppTheme.inkForest,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 840;

    return Scaffold(
      backgroundColor: AppTheme.creamPaper,
      appBar: AppBar(
        backgroundColor: AppTheme.creamPaper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkForest),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    _classroom.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontCardo,
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                      color: AppTheme.inkForest,
                    ),
                  ),
                ),
                if (_classroom.isArchived) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ARCHIVED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              _classroom.subject,
              style: const TextStyle(
                fontFamily: AppTheme.fontZilla,
                fontSize: 12,
                color: AppTheme.charcoalSlate,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.inkForest),
            tooltip: 'Refresh Roster',
            onPressed: _loadStudents,
          ),
          if (_isTeacher)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppTheme.inkForest),
              tooltip: 'Classroom Settings',
              onPressed: _showSettingsModal,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.8)),
              ),
            ),
            child: isDesktop ? _buildDesktopTabBar() : _buildMobileScrollableTabBar(),
          ),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildNotesTab(),
            _buildQuestionBankTab(),
            _buildExamsTab(),
            _buildAssignmentsTab(),
            _buildLiveClassTab(),
            _buildStudentsTab(),
            _buildAnalyticsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: false,
      labelColor: AppTheme.inkForest,
      unselectedLabelColor: AppTheme.textSecondary,
      indicatorColor: AppTheme.inkForest,
      indicatorWeight: 3,
      labelStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13.5),
      unselectedLabelStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13),
      tabs: _workspaceTabs.map((t) => Tab(icon: Icon(t.icon, size: 18), text: t.label)).toList(),
    );
  }

  Widget _buildMobileScrollableTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: List.generate(_workspaceTabs.length, (index) {
          final tab = _workspaceTabs[index];
          final isSelected = _tabController.index == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              avatar: Icon(
                tab.icon,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.inkForest,
              ),
              label: Text(
                tab.label,
                style: TextStyle(
                  fontFamily: AppTheme.fontZilla,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12.5,
                  color: isSelected ? Colors.white : AppTheme.inkForest,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.inkForest,
              backgroundColor: AppTheme.mintWash.withValues(alpha: 0.25),
              side: BorderSide(
                color: isSelected ? AppTheme.inkForest : AppTheme.borderColor,
                width: 1,
              ),
              onSelected: (selected) {
                if (selected) {
                  _tabController.animateTo(index);
                }
              },
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: OVERVIEW & STREAM
  // ===========================================================================
  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Classroom Banner & Join Code Card
        _buildClassroomHeaderCard(),
        const SizedBox(height: 16),

        // Quick Actions Bar (Faculty) / Student Shortcuts
        _buildQuickActionBar(),
        const SizedBox(height: 16),

        // Upcoming Items Card
        _buildUpcomingWidget(),
        const SizedBox(height: 20),

        // Stream Announcements Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Classroom Stream',
              style: TextStyle(
                fontFamily: AppTheme.fontCardo,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.inkForest,
              ),
            ),
            Text(
              _isTeacher ? 'Post to students' : 'Instructor announcements',
              style: const TextStyle(
                fontFamily: AppTheme.fontZilla,
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Stream Composer (Teacher only)
        if (_isTeacher) ...[
          _buildStreamComposer(),
          const SizedBox(height: 16),
        ],

        // Stream Feed
        _buildStreamFeed(),
      ],
    );
  }

  Widget _buildClassroomHeaderCard() {
    return WatercolorBlobContainer(
      variant: BlobVariant.sageSoft,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _classroom.name,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontCardo,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppTheme.inkForest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_classroom.subject} • Instructor: ${_classroom.teacherName}',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontZilla,
                        fontSize: 13.5,
                        color: AppTheme.charcoalSlate,
                      ),
                    ),
                    if (_classroom.description != null && _classroom.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _classroom.description!,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontZilla,
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Join code chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.mintWash.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.inkForest.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _classroom.code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppTheme.inkForest,
                        fontSize: 15,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16, color: AppTheme.inkForest),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy join code',
                      onPressed: _copyClassCode,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Share & Join Controls
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_2, size: 16),
                label: const Text('Show QR Code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.inkForest,
                  side: const BorderSide(color: AppTheme.inkForest),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _showQrCodeModal,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share Code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.inkForest,
                  side: const BorderSide(color: AppTheme.inkForest),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _shareInviteText,
              ),
              if (_isTeacher) ...[
                TextButton.icon(
                  icon: const Icon(Icons.autorenew, size: 16),
                  label: const Text('Regenerate Code'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.inkForest,
                    textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12),
                  ),
                  onPressed: _showRegenerateCodeDialog,
                ),
                Chip(
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: _classroom.isJoiningEnabled
                      ? AppTheme.successColor.withValues(alpha: 0.12)
                      : Colors.grey.shade200,
                  avatar: Icon(
                    _classroom.isJoiningEnabled ? Icons.check_circle : Icons.lock,
                    size: 14,
                    color: _classroom.isJoiningEnabled ? AppTheme.successColor : Colors.grey.shade700,
                  ),
                  label: Text(
                    _classroom.isJoiningEnabled ? 'Joining Open' : 'Joining Paused',
                    style: TextStyle(
                      fontFamily: AppTheme.fontZilla,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _classroom.isJoiningEnabled ? AppTheme.successColor : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBar() {
    if (_isTeacher) {
      return Row(
        children: [
          Expanded(
            child: _buildActionTile(
              icon: Icons.upload_file,
              label: 'Upload Notes',
              color: AppTheme.mintWash,
              onTap: () => _tabController.animateTo(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionTile(
              icon: Icons.assignment_add,
              label: 'Create Exam',
              color: AppTheme.tealWash,
              onTap: () => _tabController.animateTo(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionTile(
              icon: Icons.add_task,
              label: 'Assignment',
              color: AppTheme.accentPeach,
              onTap: () => _tabController.animateTo(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionTile(
              icon: Icons.video_call,
              label: 'Live Class',
              color: AppTheme.sageBlob,
              onTap: () => _tabController.animateTo(5),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: _buildActionTile(
              icon: Icons.menu_book,
              label: 'Class Notes',
              color: AppTheme.mintWash,
              onTap: () => _tabController.animateTo(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionTile(
              icon: Icons.quiz,
              label: 'Practice Bank',
              color: AppTheme.tealWash,
              onTap: () => _tabController.animateTo(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionTile(
              icon: Icons.assignment,
              label: 'My Exams',
              color: AppTheme.accentPeach,
              onTap: () => _tabController.animateTo(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionTile(
              icon: Icons.grade,
              label: 'My Grades',
              color: AppTheme.sageBlob,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudentGradesScreen(
                      classroom: _classroom,
                      studentId: widget.currentUser.id,
                      studentName: widget.currentUser.name,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.inkForest, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontZilla,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                color: AppTheme.inkForest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingWidget() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppTheme.inkForest),
                SizedBox(width: 8),
                Text(
                  'Upcoming Deadlines & Sessions',
                  style: TextStyle(
                    fontFamily: AppTheme.fontCardo,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: AppTheme.inkForest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.creamPaper,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.mintWash.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline, color: AppTheme.inkForest, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You are all caught up!',
                          style: TextStyle(
                            fontFamily: AppTheme.fontZilla,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.inkForest,
                          ),
                        ),
                        Text(
                          'New assignments and exam schedules will appear here automatically.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontZilla,
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamComposer() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.mintWash.withValues(alpha: 0.5),
                  child: const Icon(Icons.person, size: 18, color: AppTheme.inkForest),
                ),
                const SizedBox(width: 10),
                Text(
                  'Share something with ${_classroom.name}...',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontZilla,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.inkForest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _announcementController,
              maxLines: 3,
              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Announce a new lecture, upload instructions, or share resources...',
                hintStyle: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: Colors.grey.shade500),
                filled: true,
                fillColor: AppTheme.creamPaper,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.6)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppTheme.inkForest),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (_stagedAttachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _stagedAttachments.map((att) {
                  return Chip(
                    backgroundColor: AppTheme.mintWash.withValues(alpha: 0.3),
                    avatar: const Icon(Icons.attach_file, size: 14, color: AppTheme.inkForest),
                    label: Text(
                      att.name,
                      style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.inkForest),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() => _stagedAttachments.remove(att));
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file, size: 15),
                  label: const Text('Add Link/File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.inkForest,
                    side: const BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12),
                  ),
                  onPressed: _showAddAttachmentDialog,
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _isPinnedAnnouncement,
                      activeColor: AppTheme.inkForest,
                      onChanged: (v) => setState(() => _isPinnedAnnouncement = v ?? false),
                    ),
                    const Text(
                      'Pin post',
                      style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.inkForest),
                    ),
                  ],
                ),
                const Spacer(),
                PrimaryButton(
                  text: _isPostingAnnouncement ? 'Posting...' : 'Post',
                  icon: Icons.send,
                  height: 38,
                  onPressed: _isPostingAnnouncement ? null : _handlePostAnnouncement,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamFeed() {
    return StreamBuilder<List<Announcement>>(
      stream: FirestoreService.instance.getAnnouncementsStream(_classroom.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final announcements = snapshot.data ?? [];
        if (announcements.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: EmptyState(
              icon: Icons.campaign_outlined,
              title: 'Class Stream is Empty',
              message: _isTeacher
                  ? 'Keep your students engaged by posting announcements, sharing class links, and discussing topics here.'
                  : 'Your instructor has not posted any announcements in the stream yet.',
              actionText: _isTeacher ? 'Compose Announcement' : null,
              onAction: _isTeacher ? () {} : null,
            ),
          );
        }

        return Column(
          children: announcements.map((ann) => _buildAnnouncementCard(ann)).toList(),
        );
      },
    );
  }

  Widget _buildAnnouncementCard(Announcement ann) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: ann.pinned ? AppTheme.inkForest.withValues(alpha: 0.5) : AppTheme.borderColor,
          width: ann.pinned ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Author + Pin + Options
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: ann.isTeacherPost
                      ? AppTheme.inkForest.withValues(alpha: 0.12)
                      : AppTheme.mintWash.withValues(alpha: 0.4),
                  child: Icon(
                    ann.isTeacherPost ? Icons.school : Icons.person,
                    size: 18,
                    color: AppTheme.inkForest,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ann.authorName,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontCardo,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: AppTheme.inkForest,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ann.isTeacherPost
                                  ? AppTheme.inkForest.withValues(alpha: 0.1)
                                  : AppTheme.sageBlob.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ann.authorRole.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: ann.isTeacherPost ? AppTheme.inkForest : AppTheme.charcoalSlate,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatTimestamp(ann.createdAt),
                        style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (ann.pinned)
                  const Tooltip(
                    message: 'Pinned Announcement',
                    child: Icon(Icons.push_pin, size: 16, color: AppTheme.inkForest),
                  ),
                if (_isTeacher)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.charcoalSlate),
                    onSelected: (val) async {
                      if (val == 'pin') {
                        await FirestoreService.instance.togglePinAnnouncement(_classroom.id, ann.id, ann.pinned);
                      } else if (val == 'delete') {
                        await FirestoreService.instance.deleteAnnouncement(_classroom.id, ann.id);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(ann.pinned ? 'Unpin post' : 'Pin to top'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete post', style: TextStyle(color: AppTheme.errorColor)),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Text(
              ann.content,
              style: const TextStyle(
                fontFamily: AppTheme.fontZilla,
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            // Attachments
            if (ann.attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ann.attachments.map((att) {
                  return InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: att.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Attachment link "${att.url}" copied to clipboard!'),
                          backgroundColor: AppTheme.inkForest,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.creamPaper,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            att.type == 'link' ? Icons.link : Icons.description,
                            size: 14,
                            color: AppTheme.inkForest,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            att.name,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontZilla,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.inkForest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(height: 1),
            // Comments Component
            _AnnouncementCommentsWidget(
              classroomId: _classroom.id,
              announcement: ann,
              currentUser: widget.currentUser,
              isTeacher: _isTeacher,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: NOTES (Phase 2 Shell)
  // ===========================================================================
  Widget _buildNotesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WatercolorBlobContainer(
          variant: BlobVariant.mintWash,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.folder_special, size: 36, color: AppTheme.inkForest),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Classroom Notes & Units',
                      style: TextStyle(
                        fontFamily: AppTheme.fontCardo,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppTheme.inkForest,
                      ),
                    ),
                    Text(
                      _isTeacher
                          ? 'Upload PDFs, slides, and docs categorized by units for your students.'
                          : 'Access verified notes, topic maps, and AI summaries posted by your teacher.',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontZilla,
                        fontSize: 12.5,
                        color: AppTheme.charcoalSlate,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isTeacher)
                PrimaryButton(
                  text: 'Upload',
                  icon: Icons.upload_file,
                  height: 38,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Multi-format unit notes upload with OCR topic map parser is activating in Phase 2.'),
                        backgroundColor: AppTheme.inkForest,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No Classroom Notes Published Yet',
            message: _isTeacher
                ? 'Organize your syllabus into units/chapters and upload lecture notes, slides, and reading materials.'
                : 'Your instructor will publish lecture notes and study guides here.',
            actionText: _isTeacher ? 'Upload First Note' : null,
            onAction: _isTeacher ? () {} : null,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: QUESTION BANK (Phase 3 Shell)
  // ===========================================================================
  Widget _buildQuestionBankTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WatercolorBlobContainer(
          variant: BlobVariant.sageSoft,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.psychology, size: 36, color: AppTheme.inkForest),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Classroom Question Bank',
                      style: TextStyle(
                        fontFamily: AppTheme.fontCardo,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppTheme.inkForest,
                      ),
                    ),
                    Text(
                      _isTeacher
                          ? 'Author questions manually or generate AI questions grounded in uploaded notes.'
                          : 'Practice questions authored and approved by your faculty.',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontZilla,
                        fontSize: 12.5,
                        color: AppTheme.charcoalSlate,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isTeacher)
                PrimaryButton(
                  text: 'AI Suggest',
                  icon: Icons.auto_awesome,
                  height: 38,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('AI Question generation grounded in notes with review pipeline is activating in Phase 3.'),
                        backgroundColor: AppTheme.inkForest,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: EmptyState(
            icon: Icons.quiz_outlined,
            title: 'Classroom Question Bank is Empty',
            message: _isTeacher
                ? 'Create MCQs, numericals, and conceptual questions with marking rubrics or auto-generate them from class notes.'
                : 'Questions added by your instructor will appear here for practice.',
            actionText: _isTeacher ? 'Create Question' : null,
            onAction: _isTeacher ? () {} : null,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: EXAMS (Phase 4 Shell)
  // ===========================================================================
  Widget _buildExamsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WatercolorBlobContainer(
          variant: BlobVariant.mintWash,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 36, color: AppTheme.inkForest),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Timed Exams & Assessments',
                      style: TextStyle(
                        fontFamily: AppTheme.fontCardo,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppTheme.inkForest,
                      ),
                    ),
                    Text(
                      _isTeacher
                          ? 'Build online exams with blueprint generation, randomized questions, and tab-switch monitoring.'
                          : 'View scheduled exams, take tests, and review auto-graded results.',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontZilla,
                        fontSize: 12.5,
                        color: AppTheme.charcoalSlate,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isTeacher)
                PrimaryButton(
                  text: 'New Exam',
                  icon: Icons.add,
                  height: 38,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Exam builder with blueprint generation and test-taking engine is activating in Phase 4.'),
                        backgroundColor: AppTheme.inkForest,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: EmptyState(
            icon: Icons.assignment_turned_in_outlined,
            title: 'No Active or Scheduled Exams',
            message: _isTeacher
                ? 'Create your first exam with duration, start window, passing marks, and question shuffling.'
                : 'No exams have been assigned to you in this classroom yet.',
            actionText: _isTeacher ? 'Create Exam' : null,
            onAction: _isTeacher ? () {} : null,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 5: ASSIGNMENTS (Phase 5 Shell)
  // ===========================================================================
  Widget _buildAssignmentsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WatercolorBlobContainer(
          variant: BlobVariant.creamPaper,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.assignment_ind_outlined, size: 36, color: AppTheme.inkForest),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Course Assignments',
                      style: TextStyle(
                        fontFamily: AppTheme.fontCardo,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppTheme.inkForest,
                      ),
                    ),
                    Text(
                      _isTeacher
                          ? 'Publish assignments with rubrics, track submissions (Assigned/Submitted/Late), and grade student files.'
                          : 'Submit your homework files, view instructor feedback, and track your grades.',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontZilla,
                        fontSize: 12.5,
                        color: AppTheme.charcoalSlate,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isTeacher)
                PrimaryButton(
                  text: 'Create',
                  icon: Icons.add,
                  height: 38,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Teams-style assignment builder with rubrics & submissions is activating in Phase 5.'),
                        backgroundColor: AppTheme.inkForest,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: EmptyState(
            icon: Icons.task_outlined,
            title: 'No Assignments Assigned',
            message: _isTeacher
                ? 'Create assignments with rich-text instructions, due dates, late submission policies, and marking rubrics.'
                : 'You have no pending assignments in this classroom.',
            actionText: _isTeacher ? 'New Assignment' : null,
            onAction: _isTeacher ? () {} : null,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 6: LIVE CLASS (Phase 6 Shell)
  // ===========================================================================
  Widget _buildLiveClassTab() {
    final jitsiRoomName = 'StudyMate_${_classroom.code}_${_classroom.id.substring(0, _classroom.id.length.clamp(0, 8))}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WatercolorBlobContainer(
          variant: BlobVariant.sageSoft,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.inkForest.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam, color: AppTheme.inkForest, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jitsi Meet Live Classroom',
                          style: TextStyle(
                            fontFamily: AppTheme.fontCardo,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.inkForest,
                          ),
                        ),
                        Text(
                          'Room: $jitsiRoomName',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppTheme.charcoalSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Instant audio/video conferencing with screen sharing and chat. Free, secure, and accessible directly in any browser without installing software.',
                style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  PrimaryButton(
                    text: _isTeacher ? 'Start Live Class Now' : 'Join Live Class',
                    icon: Icons.video_call,
                    onPressed: () {
                      final url = 'https://meet.jit.si/$jitsiRoomName';
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Live class link "$url" copied! Full Jitsi integration is activating in Phase 6.'),
                          backgroundColor: AppTheme.inkForest,
                        ),
                      );
                    },
                  ),
                  if (_isTeacher)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.schedule, size: 16),
                      label: const Text('Schedule Live Session'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.inkForest,
                        side: const BorderSide(color: AppTheme.inkForest),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Scheduled live classes with auto-stream posting is activating in Phase 6.'),
                            backgroundColor: AppTheme.inkForest,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 7: STUDENTS ROSTER
  // ===========================================================================
  Widget _buildStudentsTab() {
    final filtered = _students.where((s) {
      if (_studentSearchQuery.isEmpty) return true;
      final q = _studentSearchQuery.toLowerCase();
      return s.studentName.toLowerCase().contains(q) ||
          s.studentEmail.toLowerCase().contains(q) ||
          s.studentPhone.contains(q);
    }).toList();

    return Column(
      children: [
        // Top Toolbar: Search + Action buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search roster by name or email...',
                        hintStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.inkForest),
                        suffixIcon: _studentSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _studentSearchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        filled: true,
                        fillColor: AppTheme.creamPaper,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.6)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: AppTheme.inkForest),
                        ),
                      ),
                      onChanged: (v) => setState(() => _studentSearchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isTeacher) ...[
                    IconButton(
                      icon: const Icon(Icons.download, color: AppTheme.inkForest),
                      tooltip: 'Export Roster CSV',
                      onPressed: _students.isEmpty ? null : _exportRosterCsv,
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: AppTheme.inkForest),
                      tooltip: 'Share Join Code',
                      onPressed: _shareInviteText,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Enrolled Students (${_students.length})',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontCardo,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.inkForest,
                    ),
                  ),
                  const Spacer(),
                  if (_classroom.requireApproval && _classroom.pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_classroom.pendingCount} Pending Approval',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Pending Approval Banner (Teacher)
        if (_isTeacher && _classroom.requireApproval && _classroom.pendingCount > 0)
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.warningColor.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_classroom.pendingCount} students are waiting for approval to enter this classroom.',
                    style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, color: AppTheme.charcoalSlate),
                  ),
                ),
              ],
            ),
          ),

        // Students Roster List
        Expanded(
          child: _isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? (_studentSearchQuery.isNotEmpty
                      ? const Center(
                          child: Text(
                            'No students match your search criteria.',
                            style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 14, color: AppTheme.textSecondary),
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: EmptyState(
                              icon: Icons.people_outline,
                              title: 'No Students Enrolled Yet',
                              message: 'Share your 6-character join code with students to let them join this classroom workspace.',
                              actionText: 'Copy Join Code (${_classroom.code})',
                              onAction: _copyClassCode,
                            ),
                          ),
                        ))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final student = filtered[index];
                        final hasGrade = student.assessmentsCount > 0;

                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.borderColor),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.mintWash.withValues(alpha: 0.5),
                              child: Text(
                                student.studentName.isNotEmpty
                                    ? student.studentName[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.inkForest,
                                ),
                              ),
                            ),
                            title: Text(
                              student.studentName,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontCardo,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.inkForest,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  student.studentEmail,
                                  style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hasGrade
                                            ? AppTheme.successColor.withValues(alpha: 0.1)
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        hasGrade
                                            ? '${student.percentage.toStringAsFixed(1)}% (${student.assessmentsCount} tests)'
                                            : 'No assessments',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: hasGrade ? AppTheme.successColor : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: _isTeacher
                                ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.charcoalSlate),
                                    onSelected: (val) {
                                      if (val == 'history') {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => StudentGradeHistoryScreen(
                                              classroomId: _classroom.id,
                                              classroomName: _classroom.name,
                                              studentSummary: student,
                                            ),
                                          ),
                                        );
                                      } else if (val == 'remove') {
                                        _removeStudent(student);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'history',
                                        child: Text('View Grade History'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Remove from Class', style: TextStyle(color: AppTheme.errorColor)),
                                      ),
                                    ],
                                  )
                                : null,
                            onTap: _isTeacher
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => StudentGradeHistoryScreen(
                                          classroomId: _classroom.id,
                                          classroomName: _classroom.name,
                                          studentSummary: student,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 8: ANALYTICS (Phase 7 Shell)
  // ===========================================================================
  Widget _buildAnalyticsTab() {
    final int totalEnrolled = _students.length;
    final double avgPercentage = _students.isEmpty
        ? 0.0
        : (_students.map((s) => s.percentage).reduce((a, b) => a + b) / _students.length);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WatercolorBlobContainer(
          variant: BlobVariant.sageSoft,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Class Performance & Health',
                style: TextStyle(
                  fontFamily: AppTheme.fontCardo,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.inkForest,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'High-level summary of classroom participation, assessment averages, and student engagement.',
                style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Enrolled Students',
                      value: '$totalEnrolled',
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Class Average',
                      value: '${avgPercentage.toStringAsFixed(1)}%',
                      icon: Icons.trending_up,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: EmptyState(
            icon: Icons.insights,
            title: 'Detailed Analytics Activating in Phase 7',
            message: 'Weak topic matrix, student engagement trends, and test distributions will populate once assignments and exams are recorded.',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.inkForest),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontZilla,
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppTheme.fontCardo,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: AppTheme.inkForest,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return 'Just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Sub-widget managing comments on a stream announcement.
class _AnnouncementCommentsWidget extends StatefulWidget {
  final String classroomId;
  final Announcement announcement;
  final User currentUser;
  final bool isTeacher;

  const _AnnouncementCommentsWidget({
    required this.classroomId,
    required this.announcement,
    required this.currentUser,
    required this.isTeacher,
  });

  @override
  State<_AnnouncementCommentsWidget> createState() => _AnnouncementCommentsWidgetState();
}

class _AnnouncementCommentsWidgetState extends State<_AnnouncementCommentsWidget> {
  bool _isExpanded = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await FirestoreService.instance.addComment(
        classroomId: widget.classroomId,
        announcementId: widget.announcement.id,
        authorId: widget.currentUser.id,
        authorName: widget.currentUser.name,
        authorRole: widget.currentUser.role,
        content: text,
      );
      _commentController.clear();
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to comment: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 14,
                  color: widget.announcement.commentCount > 0 ? AppTheme.inkForest : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.announcement.commentCount == 0
                      ? 'Add comment'
                      : '${widget.announcement.commentCount} comment${widget.announcement.commentCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontFamily: AppTheme.fontZilla,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.announcement.commentCount > 0 ? AppTheme.inkForest : Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          StreamBuilder<List<AnnouncementComment>>(
            stream: FirestoreService.instance.getCommentsStream(widget.classroomId, widget.announcement.id),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? [];
              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No comments yet. Start the conversation!',
                    style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.textSecondary),
                  ),
                );
              }
              return Column(
                children: comments.map((c) {
                  final canDelete = widget.isTeacher || c.authorId == widget.currentUser.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.creamPaper,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    c.authorName,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontZilla,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.inkForest,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${c.authorRole})',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.content,
                                style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        if (canDelete)
                          IconButton(
                            icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              FirestoreService.instance.deleteComment(
                                widget.classroomId,
                                widget.announcement.id,
                                c.id,
                              );
                            },
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Write a reply...',
                    hintStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.creamPaper,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: AppTheme.inkForest),
                    ),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: _isSubmitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 18, color: AppTheme.inkForest),
                onPressed: _isSubmitting ? null : _submitComment,
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
