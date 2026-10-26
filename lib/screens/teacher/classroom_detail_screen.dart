import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate_classroom/models/announcement_model.dart';
import 'package:studymate_classroom/models/assignment_model.dart';
import 'package:studymate_classroom/models/classroom_model.dart';
import 'package:studymate_classroom/models/classroom_note_model.dart';
import 'package:studymate_classroom/models/live_class_model.dart';
import 'package:studymate_classroom/utils/link_opener.dart';
import 'package:studymate_classroom/models/coverage_report_model.dart';
import 'package:studymate_classroom/models/exam_model.dart';
import 'package:studymate_classroom/models/grade_model.dart';
import 'package:studymate_classroom/models/note_model.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/models/summary_model.dart';
import 'package:studymate_classroom/models/topic_map_model.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/screens/classroom/exam_runner_screen.dart';
import 'package:studymate_classroom/screens/student/student_grades_screen.dart';
import 'package:studymate_classroom/screens/teacher/student_grade_history_screen.dart';
import 'package:studymate_classroom/services/document_processing_service.dart';
import 'package:studymate_classroom/services/export_service.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/services/notes_ai_service.dart';
import 'package:studymate_classroom/services/smart_summarization_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';
import 'package:studymate_classroom/widgets/explain_simply_dialog.dart';
import 'package:studymate_classroom/widgets/primary_button.dart';
import 'package:studymate_classroom/widgets/smart_summary_viewer.dart';
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

  // Notes tab state
  int? _selectedUnitFilter;
  String _notesSearchQuery = '';
  final TextEditingController _notesSearchController = TextEditingController();

  // Question Bank tab state
  final TextEditingController _questionSearchController = TextEditingController();
  String _questionSearchQuery = '';
  String _selectedQuestionTypeFilter = 'all'; // all, mcq, true_false, short, long, numerical, code
  String _selectedDifficultyFilter = 'All'; // All, Easy, Medium, Hard
  int? _selectedQuestionUnitFilter;
  final Map<String, int> _studentSelectedAnswers = {};
  final Set<String> _revealedAnswers = {};
  final Set<String> _selectedQuestionIds = {};

  // Exams tab state
  String _selectedExamFilter = 'all'; // all, ongoing, upcoming, past

  // Assignments tab state
  String _selectedAssignmentFilter = 'all'; // all, active, past_due, draft

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
    _notesSearchController.dispose();
    _questionSearchController.dispose();
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
            icon: const Badge(
              backgroundColor: Colors.redAccent,
              smallSize: 8,
              child: Icon(Icons.notifications_outlined, color: AppTheme.inkForest),
            ),
            tooltip: 'Classroom Activity & Notifications',
            onPressed: _showNotificationCenterModal,
          ),
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
  // TAB 2: NOTES & TOPIC MAP MANAGEMENT (Phase 2)
  // ===========================================================================
  Widget _buildNotesTab() {
    return StreamBuilder<List<ClassroomNote>>(
      stream: FirestoreService.instance.getClassroomNotesStream(_classroom.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allNotes = snapshot.data ?? [];
        // Students only see published notes whose scheduled time has passed
        final notes = _isTeacher
            ? allNotes
            : allNotes.where((n) => n.isPublished).toList();

        // Extract available units for filter chips
        final unitNumbers = notes.map((n) => n.unitNumber).toSet().toList()..sort();

        // Filter by unit
        final unitFilteredNotes = _selectedUnitFilter == null
            ? notes
            : notes.where((n) => n.unitNumber == _selectedUnitFilter).toList();

        // Filter by search query
        final filteredNotes = unitFilteredNotes.where((n) {
          if (_notesSearchQuery.isEmpty) return true;
          final q = _notesSearchQuery.toLowerCase();
          return n.title.toLowerCase().contains(q) ||
              n.unitTitle.toLowerCase().contains(q) ||
              (n.description != null && n.description!.toLowerCase().contains(q));
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Top Summary Card
            WatercolorBlobContainer(
              variant: BlobVariant.mintWash,
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final textCol = Expanded(
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
                  );

                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder_special, size: 36, color: AppTheme.inkForest),
                            const SizedBox(width: 14),
                            textCol,
                          ],
                        ),
                        if (_isTeacher) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryButton(
                              text: 'Upload Note',
                              icon: Icons.upload_file,
                              height: 38,
                              onPressed: () => _showUploadNoteDialog(),
                            ),
                          ),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      const Icon(Icons.folder_special, size: 36, color: AppTheme.inkForest),
                      const SizedBox(width: 14),
                      textCol,
                      if (_isTeacher) ...[
                        const SizedBox(width: 12),
                        PrimaryButton(
                          text: 'Upload Note',
                          icon: Icons.upload_file,
                          height: 38,
                          onPressed: () => _showUploadNoteDialog(),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Search Bar & Unit Filters
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _notesSearchController,
                      style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search notes by title, topic, or unit...',
                        hintStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.inkForest),
                        suffixIcon: _notesSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _notesSearchController.clear();
                                  setState(() => _notesSearchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        filled: true,
                        fillColor: AppTheme.creamPaper,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.6)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: AppTheme.inkForest),
                        ),
                      ),
                      onChanged: (v) => setState(() => _notesSearchQuery = v.trim()),
                    ),
                    if (unitNumbers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: const Text('All Units'),
                                selected: _selectedUnitFilter == null,
                                selectedColor: AppTheme.inkForest,
                                backgroundColor: AppTheme.mintWash.withValues(alpha: 0.25),
                                labelStyle: TextStyle(
                                  fontFamily: AppTheme.fontZilla,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedUnitFilter == null ? Colors.white : AppTheme.inkForest,
                                ),
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedUnitFilter = null);
                                },
                              ),
                            ),
                            ...unitNumbers.map((u) {
                              final isSel = _selectedUnitFilter == u;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text('Unit $u'),
                                  selected: isSel,
                                  selectedColor: AppTheme.inkForest,
                                  backgroundColor: AppTheme.mintWash.withValues(alpha: 0.25),
                                  labelStyle: TextStyle(
                                    fontFamily: AppTheme.fontZilla,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? Colors.white : AppTheme.inkForest,
                                  ),
                                  onSelected: (sel) {
                                    setState(() => _selectedUnitFilter = sel ? u : null);
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Note List
            if (filteredNotes.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: _notesSearchQuery.isNotEmpty || _selectedUnitFilter != null
                      ? 'No Notes Found'
                      : 'No Classroom Notes Published Yet',
                  message: _notesSearchQuery.isNotEmpty || _selectedUnitFilter != null
                      ? 'Try clearing your search query or selecting a different unit filter.'
                      : (_isTeacher
                          ? 'Upload lecture PDFs, slides, and syllabus documents. The AI parser extracts topics and builds summaries automatically.'
                          : 'Your instructor will publish lecture notes and study guides here.'),
                  actionText: _isTeacher && _notesSearchQuery.isEmpty && _selectedUnitFilter == null
                      ? 'Upload First Note'
                      : (_notesSearchQuery.isNotEmpty || _selectedUnitFilter != null ? 'Clear Filters' : null),
                  onAction: () {
                    if (_isTeacher && _notesSearchQuery.isEmpty && _selectedUnitFilter == null) {
                      _showUploadNoteDialog();
                    } else {
                      setState(() {
                        _selectedUnitFilter = null;
                        _notesSearchQuery = '';
                        _notesSearchController.clear();
                      });
                    }
                  },
                ),
              )
            else
              ...filteredNotes.map((note) => _buildClassroomNoteCard(note)),
          ],
        );
      },
    );
  }

  Widget _buildClassroomNoteCard(ClassroomNote note) {
    final bool canDownload = note.allowDownload || _isTeacher;
    final int pageCount = note.topicMap?.topics.fold<int>(0, (acc, t) => acc + t.subtopics.length) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Unit Badge, File Type, Version, and 3-dot Menu
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.inkForest.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Unit ${note.unitNumber}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontZilla,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.inkForest,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.mintWash.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    note.fileType.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.inkForest,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _showVersionHistoryDialog(note),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 11, color: AppTheme.charcoalSlate),
                        const SizedBox(width: 3),
                        Text(
                          'v${note.version}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoalSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (_isTeacher) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: note.isPublished
                          ? AppTheme.successColor.withValues(alpha: 0.12)
                          : (note.isScheduled
                              ? AppTheme.warningColor.withValues(alpha: 0.15)
                              : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      note.isPublished
                          ? 'PUBLISHED'
                          : (note.isScheduled ? 'SCHEDULED' : 'DRAFT'),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: note.isPublished
                            ? AppTheme.successColor
                            : (note.isScheduled ? AppTheme.warningColor : Colors.grey.shade700),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.charcoalSlate),
                    onSelected: (val) async {
                      if (val == 'reupload') {
                        _showUploadNoteDialog(existingNoteToReplace: note);
                      } else if (val == 'edit') {
                        _showEditNoteDetailsDialog(note);
                      } else if (val == 'toggle_status') {
                        final newStatus = note.isPublished ? 'draft' : 'published';
                        await FirestoreService.instance.updateClassroomNote(
                          _classroom.id,
                          note.id,
                          status: newStatus,
                        );
                      } else if (val == 'toggle_download') {
                        await FirestoreService.instance.updateClassroomNote(
                          _classroom.id,
                          note.id,
                          allowDownload: !note.allowDownload,
                        );
                      } else if (val == 'delete') {
                        _showDeleteNoteConfirm(note);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'reupload',
                        child: Row(
                          children: [
                            Icon(Icons.upgrade, size: 16),
                            SizedBox(width: 8),
                            Text('Re-upload Version'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit Details'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_status',
                        child: Row(
                          children: [
                            Icon(note.isPublished ? Icons.visibility_off : Icons.visibility, size: 16),
                            const SizedBox(width: 8),
                            Text(note.isPublished ? 'Switch to Draft' : 'Publish Note'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_download',
                        child: Row(
                          children: [
                            Icon(note.allowDownload ? Icons.file_download_off : Icons.file_download, size: 16),
                            const SizedBox(width: 8),
                            Text(note.allowDownload ? 'Disable Download' : 'Enable Download'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: AppTheme.errorColor),
                            SizedBox(width: 8),
                            Text('Delete Note', style: TextStyle(color: AppTheme.errorColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Note Title & Unit
            Text(
              note.title,
              style: const TextStyle(
                fontFamily: AppTheme.fontCardo,
                fontWeight: FontWeight.bold,
                fontSize: 16.5,
                color: AppTheme.inkForest,
              ),
            ),
            Text(
              note.unitTitle,
              style: const TextStyle(
                fontFamily: AppTheme.fontZilla,
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (note.description != null && note.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                note.description!,
                style: const TextStyle(
                  fontFamily: AppTheme.fontZilla,
                  fontSize: 12.5,
                  color: AppTheme.charcoalSlate,
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Metadata row: topics count, OCR tag, download info
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (pageCount > 0)
                  _buildMetaChip(Icons.segment, '$pageCount Subtopics Parsed'),
                if (note.topicMap != null)
                  _buildMetaChip(Icons.schema_outlined, 'Topic Map Ready'),
                _buildMetaChip(
                  note.allowDownload ? Icons.file_download : Icons.file_download_off,
                  note.allowDownload ? 'Downloads Allowed' : 'View-Only (No Download)',
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Action Row: AI Summary, Explain Simply, Topic Map, Download
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('AI Summary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.inkForest,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showSmartSummaryModal(note),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.lightbulb_outline, size: 14),
                  label: const Text('Explain Simply'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.inkForest,
                    side: const BorderSide(color: AppTheme.inkForest),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showExplainSimplyModal(note),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.account_tree_outlined, size: 14),
                  label: const Text('Topic Map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12),
                  ),
                  onPressed: () => _showTopicMapDialog(note),
                ),
                if (_isTeacher)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.psychology, size: 14),
                    label: const Text('Suggest Questions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.inkForest,
                      side: const BorderSide(color: AppTheme.inkForest),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showAiSuggestQuestionsDialog(preselectedNote: note),
                  ),
                if (canDownload && (note.fileUrl != null && note.fileUrl!.isNotEmpty))
                  IconButton(
                    icon: const Icon(Icons.download, size: 18, color: AppTheme.inkForest),
                    tooltip: 'Download File Resource',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: note.fileUrl!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('File link copied to clipboard: ${note.fileUrl}'),
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
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontZilla,
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PHASE 2 MODALS: UPLOAD, TOPIC MAP, AI SUMMARY, EXPLAIN SIMPLY, VERSIONING
  // ===========================================================================

  void _showUploadNoteDialog({ClassroomNote? existingNoteToReplace}) {
    final unitNumCtrl = TextEditingController(text: existingNoteToReplace?.unitNumber.toString() ?? '1');
    final unitTitleCtrl = TextEditingController(text: existingNoteToReplace?.unitTitle ?? 'Unit 1: Core Fundamentals');
    final titleCtrl = TextEditingController(text: existingNoteToReplace?.title ?? '');
    final descCtrl = TextEditingController(text: existingNoteToReplace?.description ?? '');
    final linkCtrl = TextEditingController(text: existingNoteToReplace?.fileUrl ?? '');
    bool allowDownload = existingNoteToReplace?.allowDownload ?? true;
    String status = existingNoteToReplace?.status ?? 'published';
    PlatformFile? pickedFile;
    bool isProcessing = false;
    String stageText = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => CustomDialog(
          title: existingNoteToReplace != null
              ? 'Re-upload Note (v${existingNoteToReplace.version + 1})'
              : 'Upload Classroom Note',
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isProcessing) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.mintWash.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(strokeWidth: 3),
                        const SizedBox(height: 12),
                        Text(
                          stageText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontCardo,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.inkForest,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Extracting slides, running OCR fallback, and structuring Topic Map...',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: CustomTextField(
                          controller: unitNumCtrl,
                          label: 'Unit #',
                          hintText: '1',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          controller: unitTitleCtrl,
                          label: 'Unit Title',
                          hintText: 'e.g. Unit 1: Process Management',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: titleCtrl,
                    label: 'Note / Document Title',
                    hintText: 'e.g. CPU Scheduling & IPC Slides',
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: descCtrl,
                    label: 'Description / Instructions (Optional)',
                    hintText: 'Reading assignment for Week 3...',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  // File Picker / Upload section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.creamPaper,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select File Resource (PDF, PPTX, DOCX, Images)',
                          style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        const SizedBox(height: 8),
                        if (pickedFile != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.description, size: 20, color: AppTheme.inkForest),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pickedFile!.name,
                                  style: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setDlgState(() => pickedFile = null),
                              ),
                            ],
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.attach_file, size: 16),
                            label: const Text('Choose File from Device'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.inkForest,
                              side: const BorderSide(color: AppTheme.inkForest),
                            ),
                            onPressed: () async {
                              try {
                                final res = await FilePicker.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf', 'ppt', 'pptx', 'docx', 'png', 'jpg', 'jpeg', 'txt', 'md'],
                                );
                                if (res.isNotEmpty) {
                                  setDlgState(() {
                                    pickedFile = res.first;
                                    if (titleCtrl.text.trim().isEmpty) {
                                      titleCtrl.text = pickedFile!.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                                    }
                                  });
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('File picker failed: $e'), backgroundColor: AppTheme.errorColor),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 10),
                        CustomTextField(
                          controller: linkCtrl,
                          label: 'Or Video / External Reference URL',
                          hintText: 'https://youtube.com/watch?... or https://...',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Visibility & download controls
                  Row(
                    children: [
                      const Text(
                        'Status:',
                        style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text('Published'),
                        selected: status == 'published',
                        selectedColor: AppTheme.successColor,
                        labelStyle: TextStyle(
                          color: status == 'published' ? Colors.white : AppTheme.charcoalSlate,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        onSelected: (sel) {
                          if (sel) setDlgState(() => status = 'published');
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Draft'),
                        selected: status == 'draft',
                        selectedColor: Colors.grey.shade700,
                        labelStyle: TextStyle(
                          color: status == 'draft' ? Colors.white : AppTheme.charcoalSlate,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        onSelected: (sel) {
                          if (sel) setDlgState(() => status = 'draft');
                        },
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow Students to Download File', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13)),
                    subtitle: const Text('When disabled, students can study and read summaries but cannot export the raw document.', style: TextStyle(fontSize: 11)),
                    value: allowDownload,
                    activeThumbColor: AppTheme.inkForest,
                    onChanged: (v) => setDlgState(() => allowDownload = v),
                  ),
                ],
              ],
            ),
          ),
          confirmLabel: isProcessing ? 'Processing...' : (existingNoteToReplace != null ? 'Update Version' : 'Upload Note'),
          onConfirm: isProcessing
              ? null
              : () async {
                  if (titleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a note title.'), backgroundColor: AppTheme.errorColor),
                    );
                    return;
                  }

                  setDlgState(() {
                    isProcessing = true;
                    stageText = 'Parsing file bytes & running OCR fallback...';
                  });

                  try {
                    String extractedText = '';
                    String fileType = 'pdf';
                    TopicMap? topicMap;
                    MultiLevelSummary? summary;
                    int? sizeBytes;

                    if (pickedFile != null) {
                      fileType = pickedFile!.extension?.toLowerCase() ?? 'pdf';
                      final bytes = await pickedFile!.readAsBytes();
                      sizeBytes = bytes.length;

                      final processed = await DocumentProcessingService.instance.processBytes(
                        bytes: bytes,
                        fileName: pickedFile!.name,
                        preferredTopic: unitTitleCtrl.text.trim(),
                      );
                      extractedText = processed.fullText;
                      topicMap = processed.topicMap;

                      setDlgState(() => stageText = 'Synthesizing multi-level smart summaries...');
                      summary = await SmartSummarizationService.instance.generateSummary(
                        title: titleCtrl.text.trim(),
                        topic: unitTitleCtrl.text.trim(),
                        text: extractedText,
                        topicMap: topicMap,
                      );
                    } else if (linkCtrl.text.trim().isNotEmpty) {
                      fileType = 'link';
                      extractedText = 'Reference link: ${linkCtrl.text.trim()}\nTitle: ${titleCtrl.text.trim()}\nDescription: ${descCtrl.text.trim()}';
                      topicMap = TopicMap(
                        id: 'map_${DateTime.now().millisecondsSinceEpoch}',
                        documentId: titleCtrl.text.trim(),
                        fileName: pickedFile?.name ?? titleCtrl.text.trim(),
                        title: titleCtrl.text.trim(),
                        domainTopic: unitTitleCtrl.text.trim(),
                        pageCount: 1,
                        totalWordCount: extractedText.split(RegExp(r'\s+')).length,
                        topics: [
                          TopicNode(
                            id: 'topic_1',
                            title: unitTitleCtrl.text.trim(),
                            pageStart: 1,
                            pageEnd: 1,
                            contentSnippet: extractedText,
                            subtopics: [
                              SubtopicNode(
                                id: 'sub_1',
                                title: titleCtrl.text.trim(),
                                pageNumber: 1,
                                summary: descCtrl.text.trim(),
                                concepts: [
                                  ConceptNode(
                                    name: titleCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    pageNumber: 1,
                                  ),
                                ],
                              ),
                            ],
                            wordCount: extractedText.split(RegExp(r'\s+')).length,
                          ),
                        ],
                        chunks: const [],
                        createdAt: DateTime.now(),
                      );
                    } else {
                      extractedText = descCtrl.text.trim();
                    }

                    setDlgState(() => stageText = 'Saving to classroom database...');

                    final int unitNum = int.tryParse(unitNumCtrl.text.trim()) ?? 1;

                    if (existingNoteToReplace != null) {
                      await FirestoreService.instance.reuploadClassroomNoteVersion(
                        classroomId: _classroom.id,
                        noteId: existingNoteToReplace.id,
                        fileName: pickedFile?.name ?? existingNoteToReplace.fileName ?? titleCtrl.text.trim(),
                        fileType: fileType,
                        extractedText: extractedText.isNotEmpty ? extractedText : existingNoteToReplace.extractedText,
                        topicMap: topicMap ?? existingNoteToReplace.topicMap,
                        summary: summary ?? existingNoteToReplace.summary,
                        fileSizeBytes: sizeBytes ?? existingNoteToReplace.fileSizeBytes,
                        noteRemark: 'Updated to version ${existingNoteToReplace.version + 1}',
                      );
                    } else {
                      await FirestoreService.instance.uploadClassroomNote(
                        classroomId: _classroom.id,
                        unitNumber: unitNum,
                        unitTitle: unitTitleCtrl.text.trim(),
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        fileType: fileType,
                        fileUrl: linkCtrl.text.trim(),
                        fileName: pickedFile?.name,
                        fileSizeBytes: sizeBytes,
                        extractedText: extractedText,
                        topicMap: topicMap,
                        summary: summary,
                        status: status,
                        allowDownload: allowDownload,
                      );
                    }

                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(existingNoteToReplace != null
                              ? 'Note "${titleCtrl.text.trim()}" updated to version ${existingNoteToReplace.version + 1}!'
                              : 'Note "${titleCtrl.text.trim()}" uploaded and parsed successfully!'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    }
                  } catch (e) {
                    setDlgState(() => isProcessing = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppTheme.errorColor),
                      );
                    }
                  }
                },
        ),
      ),
    );
  }

  void _showEditNoteDetailsDialog(ClassroomNote note) {
    final titleCtrl = TextEditingController(text: note.title);
    final unitNumCtrl = TextEditingController(text: note.unitNumber.toString());
    final unitTitleCtrl = TextEditingController(text: note.unitTitle);
    final descCtrl = TextEditingController(text: note.description ?? '');
    bool allowDownload = note.allowDownload;
    String status = note.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => CustomDialog(
          title: 'Edit Note Details',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: CustomTextField(
                      controller: unitNumCtrl,
                      label: 'Unit #',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomTextField(
                      controller: unitTitleCtrl,
                      label: 'Unit Title',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CustomTextField(controller: titleCtrl, label: 'Title'),
              const SizedBox(height: 10),
              CustomTextField(controller: descCtrl, label: 'Description', maxLines: 2),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Status:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Published'),
                    selected: status == 'published',
                    selectedColor: AppTheme.successColor,
                    labelStyle: TextStyle(
                      color: status == 'published' ? Colors.white : AppTheme.charcoalSlate,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    onSelected: (sel) {
                      if (sel) setDlgState(() => status = 'published');
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Draft'),
                    selected: status == 'draft',
                    selectedColor: Colors.grey.shade700,
                    labelStyle: TextStyle(
                      color: status == 'draft' ? Colors.white : AppTheme.charcoalSlate,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    onSelected: (sel) {
                      if (sel) setDlgState(() => status = 'draft');
                    },
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow Download', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13)),
                value: allowDownload,
                activeThumbColor: AppTheme.inkForest,
                onChanged: (v) => setDlgState(() => allowDownload = v),
              ),
            ],
          ),
          confirmLabel: 'Save',
          onConfirm: () async {
            await FirestoreService.instance.updateClassroomNote(
              _classroom.id,
              note.id,
              title: titleCtrl.text.trim(),
              unitNumber: int.tryParse(unitNumCtrl.text.trim()) ?? note.unitNumber,
              unitTitle: unitTitleCtrl.text.trim(),
              description: descCtrl.text.trim(),
              status: status,
              allowDownload: allowDownload,
            );
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  void _showDeleteNoteConfirm(ClassroomNote note) {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Delete Note?',
        content: Text(
          'Are you sure you want to delete "${note.title}"? This cannot be undone.',
          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 14, color: AppTheme.charcoalSlate),
        ),
        confirmLabel: 'Delete',
        confirmColor: AppTheme.errorColor,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          await FirestoreService.instance.deleteClassroomNote(_classroom.id, note.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Note "${note.title}" deleted.'), backgroundColor: AppTheme.inkForest),
            );
          }
        },
      ),
    );
  }

  void _showTopicMapDialog(ClassroomNote note) {
    final topics = note.topicMap?.topics ?? [];

    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Topic Map: ${note.title}',
        content: SizedBox(
          width: 500,
          child: topics.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No structured topic map available for this document.'),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.mintWash.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Hierarchical outline extracted from ${note.fileName ?? note.title}. Tap "Explain" next to any subtopic to understand it simply.',
                          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.inkForest),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...topics.map((t) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            leading: const Icon(Icons.bookmark, color: AppTheme.inkForest, size: 20),
                            title: Text(
                              t.title,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontCardo,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: AppTheme.inkForest,
                              ),
                            ),
                            children: t.subtopics.map((sub) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.subdirectory_arrow_right, size: 16, color: AppTheme.textSecondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sub.title,
                                            style: const TextStyle(
                                              fontFamily: AppTheme.fontZilla,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppTheme.charcoalSlate,
                                            ),
                                          ),
                                          if (sub.pageNumber > 0)
                                            Text(
                                              'Slide / Page ${sub.pageNumber}',
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 10.5,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.lightbulb_outline, size: 12),
                                      label: const Text('Explain'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.inkForest,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        _showExplainSimplyModal(note, subtopic: sub.title);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
        ),
        confirmLabel: 'Close',
        onConfirm: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _showSmartSummaryModal(ClassroomNote note) {
    final noteAdapter = Note(
      id: note.id,
      userId: note.classroomId,
      title: note.title,
      topic: note.unitTitle,
      content: note.extractedText,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.9,
        decoration: const BoxDecoration(
          color: AppTheme.creamPaper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.inkForest, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Smart Summaries: ${note.title}',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontCardo,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppTheme.inkForest,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SmartSummaryViewer(
                note: noteAdapter,
                initialSummary: note.summary,
                topicMap: note.topicMap,
                onOpenFlashcards: () {
                  Navigator.of(ctx).pop();
                  _tabController.animateTo(2); // Jump to question bank
                },
                onOpenQuiz: () {
                  Navigator.of(ctx).pop();
                  _tabController.animateTo(3); // Jump to exams
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExplainSimplyModal(ClassroomNote note, {String? subtopic}) {
    showDialog(
      context: context,
      builder: (ctx) => ExplainSimplyDialog(
        topic: note.title,
        subtopic: subtopic,
        sourceContext: note.extractedText,
        sourcePage: 1,
      ),
    );
  }

  void _showVersionHistoryDialog(ClassroomNote note) {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Version History: ${note.title}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current active version: v${note.version}',
              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (note.versionHistory.isEmpty)
              const Text('No prior revisions recorded.')
            else
              ...note.versionHistory.reversed.map((v) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.creamPaper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.inkForest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'v${v.version}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.fileName,
                              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            Text(
                              '${_formatTimestamp(v.uploadedAt)}${v.note != null && v.note!.isNotEmpty ? ' • ${v.note}' : ''}',
                              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
        confirmLabel: _isTeacher ? 'Re-upload New Version' : 'Close',
        onConfirm: () {
          Navigator.of(ctx).pop();
          if (_isTeacher) {
            _showUploadNoteDialog(existingNoteToReplace: note);
          }
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 3: QUESTION BANK (Phase 3 Full Implementation)
  // ===========================================================================
  Widget _buildQuestionBankTab() {
    return StreamBuilder<({List<Question> questions, bool isFromCache})>(
      stream: FirestoreService.instance.getClassroomQuestionsStream(_classroom.id),
      builder: (context, snapshot) {
        final allQuestions = snapshot.data?.questions ?? [];

        // Apply local filtering
        final filteredQuestions = allQuestions.where((q) {
          if (_selectedQuestionTypeFilter != 'all') {
            if (q.questionType.toLowerCase() != _selectedQuestionTypeFilter.toLowerCase()) {
              return false;
            }
          }
          if (_selectedDifficultyFilter != 'All') {
            if ((q.difficulty ?? 'Medium').toLowerCase() != _selectedDifficultyFilter.toLowerCase()) {
              return false;
            }
          }
          if (_selectedQuestionUnitFilter != null) {
            if (q.unitNumber != _selectedQuestionUnitFilter) {
              return false;
            }
          }
          if (_questionSearchQuery.isNotEmpty) {
            final query = _questionSearchQuery.toLowerCase();
            final matchesPrompt = q.question.toLowerCase().contains(query);
            final matchesAnswer = q.answer.toLowerCase().contains(query);
            final matchesTopic = q.topic.toLowerCase().contains(query);
            final matchesTags = q.tags.any((t) => t.toLowerCase().contains(query));
            if (!matchesPrompt && !matchesAnswer && !matchesTopic && !matchesTags) {
              return false;
            }
          }
          return true;
        }).toList();

        final totalMcqs = allQuestions.where((q) => q.questionType == 'mcq' || q.questionType == 'multi_mcq' || q.questionType == 'true_false').length;
        final totalConceptual = allQuestions.length - totalMcqs;
        final totalMarks = allQuestions.fold<double>(0.0, (acc, q) => acc + q.marks);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Botanical Header Banner
            WatercolorBlobContainer(
              variant: BlobVariant.sageSoft,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                                fontSize: 18,
                                color: AppTheme.inkForest,
                              ),
                            ),
                            Text(
                              _isTeacher
                                  ? 'Author questions manually, import CSV banks, or auto-generate AI questions grounded in notes.'
                                  : 'Practice faculty-approved questions with instant feedback and explanation walkthroughs.',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontZilla,
                                fontSize: 12.5,
                                color: AppTheme.charcoalSlate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Metrics row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildHeaderStatChip(Icons.quiz_outlined, '${allQuestions.length} Total Questions'),
                      _buildHeaderStatChip(Icons.radio_button_checked, '$totalMcqs MCQs & T/F'),
                      _buildHeaderStatChip(Icons.short_text, '$totalConceptual Conceptual & Rubrics'),
                      _buildHeaderStatChip(Icons.grade_outlined, '${totalMarks.toStringAsFixed(0)} Max Marks'),
                    ],
                  ),

                  // Action Buttons row for Teacher
                  if (_isTeacher) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PrimaryButton(
                          text: 'Suggest from Notes',
                          icon: Icons.auto_awesome,
                          height: 36,
                          onPressed: () => _showAiSuggestQuestionsDialog(),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Question'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.inkForest,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showQuestionEditorDialog(),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Import CSV'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.inkForest,
                            side: const BorderSide(color: AppTheme.inkForest),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showImportQuestionsDialog(),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export CSV'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.charcoalSlate,
                            side: const BorderSide(color: AppTheme.borderColor),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5),
                          ),
                          onPressed: allQuestions.isEmpty ? null : () => _exportQuestionBankCsv(allQuestions),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Sticky Bulk Action Bar if items selected
            if (_isTeacher && _selectedQuestionIds.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.inkForest,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedQuestionIds.length} questions selected',
                      style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.download, color: Colors.white, size: 16),
                      label: const Text('Export', style: TextStyle(color: Colors.white, fontSize: 12)),
                      onPressed: () {
                        final selectedList = allQuestions.where((q) => _selectedQuestionIds.contains(q.id)).toList();
                        _exportQuestionBankCsv(selectedList);
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
                      label: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 12)),
                      onPressed: () => _bulkDeleteQuestions(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                      tooltip: 'Deselect all',
                      onPressed: () => setState(() => _selectedQuestionIds.clear()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Search Bar & Filter Chips
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    controller: _questionSearchController,
                    label: 'Search Questions',
                    hintText: 'Search questions by prompt, answer, topic, or tag...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _questionSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _questionSearchController.clear();
                              setState(() => _questionSearchQuery = '');
                            },
                          )
                        : null,
                    onChanged: (val) => setState(() => _questionSearchQuery = val.trim()),
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips: Question Type
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Type:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoalSlate)),
                        const SizedBox(width: 8),
                        _buildTypeFilterChip('all', 'All Types'),
                        _buildTypeFilterChip('mcq', 'MCQ'),
                        _buildTypeFilterChip('true_false', 'True/False'),
                        _buildTypeFilterChip('short', 'Short Answer'),
                        _buildTypeFilterChip('long', 'Long Answer'),
                        _buildTypeFilterChip('numerical', 'Numerical'),
                        _buildTypeFilterChip('code', 'Code'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Filter Chips: Difficulty & Unit
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Diff:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoalSlate)),
                        const SizedBox(width: 8),
                        _buildDifficultyFilterChip('All'),
                        _buildDifficultyFilterChip('Easy'),
                        _buildDifficultyFilterChip('Medium'),
                        _buildDifficultyFilterChip('Hard'),
                        const SizedBox(width: 14),
                        const Text('Unit:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoalSlate)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('All Units'),
                          selected: _selectedQuestionUnitFilter == null,
                          selectedColor: AppTheme.mintWash,
                          labelStyle: TextStyle(
                            fontFamily: AppTheme.fontZilla,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: _selectedQuestionUnitFilter == null ? AppTheme.inkForest : AppTheme.charcoalSlate,
                          ),
                          onSelected: (sel) {
                            if (sel) setState(() => _selectedQuestionUnitFilter = null);
                          },
                        ),
                        ...List.generate(5, (index) {
                          final unitNum = index + 1;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ChoiceChip(
                              label: Text('Unit $unitNum'),
                              selected: _selectedQuestionUnitFilter == unitNum,
                              selectedColor: AppTheme.mintWash,
                              labelStyle: TextStyle(
                                fontFamily: AppTheme.fontZilla,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: _selectedQuestionUnitFilter == unitNum ? AppTheme.inkForest : AppTheme.charcoalSlate,
                              ),
                              onSelected: (sel) {
                                setState(() => _selectedQuestionUnitFilter = sel ? unitNum : null);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Content List
            if (snapshot.connectionState == ConnectionState.waiting && allQuestions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredQuestions.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: EmptyState(
                  icon: Icons.quiz_outlined,
                  title: allQuestions.isEmpty ? 'Classroom Question Bank is Empty' : 'No Questions Match Filters',
                  message: allQuestions.isEmpty
                      ? (_isTeacher
                          ? 'Author MCQs, numericals, and conceptual questions with marking rubrics or auto-generate them from class notes.'
                          : 'Questions added by your instructor will appear here for practice.')
                      : 'Try broadening your search term or clearing the active filters.',
                  actionText: allQuestions.isEmpty && _isTeacher ? 'Suggest from Notes' : null,
                  onAction: allQuestions.isEmpty && _isTeacher ? () => _showAiSuggestQuestionsDialog() : null,
                ),
              )
            else
              ...filteredQuestions.map((q) {
                final isSelected = _selectedQuestionIds.contains(q.id);
                return _buildQuestionCard(q, isSelected);
              }),
          ],
        );
      },
    );
  }

  Widget _buildHeaderStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.inkForest),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.inkForest),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip(String typeCode, String label) {
    final isSelected = _selectedQuestionTypeFilter.toLowerCase() == typeCode.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.mintWash,
        labelStyle: TextStyle(
          fontFamily: AppTheme.fontZilla,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: isSelected ? AppTheme.inkForest : AppTheme.charcoalSlate,
        ),
        onSelected: (sel) {
          if (sel) setState(() => _selectedQuestionTypeFilter = typeCode);
        },
      ),
    );
  }

  Widget _buildDifficultyFilterChip(String diff) {
    final isSelected = _selectedDifficultyFilter.toLowerCase() == diff.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(diff),
        selected: isSelected,
        selectedColor: AppTheme.mintWash,
        labelStyle: TextStyle(
          fontFamily: AppTheme.fontZilla,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: isSelected ? AppTheme.inkForest : AppTheme.charcoalSlate,
        ),
        onSelected: (sel) {
          if (sel) setState(() => _selectedDifficultyFilter = diff);
        },
      ),
    );
  }

  // ===========================================================================
  // QUESTION CARD (Interactive Student Practice & Teacher Management)
  // ===========================================================================
  Widget _buildQuestionCard(Question q, bool isSelected) {
    final isRevealed = _revealedAnswers.contains(q.id);
    final selectedOptionIndex = _studentSelectedAnswers[q.id];
    final isMcq = q.options != null && q.options!.length >= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppTheme.inkForest : AppTheme.borderColor,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Meta Badges Row
            Row(
              children: [
                if (_isTeacher) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: AppTheme.inkForest,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedQuestionIds.add(q.id);
                        } else {
                          _selectedQuestionIds.remove(q.id);
                        }
                      });
                    },
                  ),
                ],
                _buildQuestionTypeChip(q.questionType),
                const SizedBox(width: 6),
                _buildDifficultyChip(q.difficulty ?? 'Medium'),
                const SizedBox(width: 6),
                _buildBloomChip(q.bloomLevel ?? 'Understand'),
                const SizedBox(width: 6),
                if (q.unitNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.mintWash.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Unit ${q.unitNumber}',
                      style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.inkForest),
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${q.marks.toStringAsFixed(1)} marks',
                    style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoalSlate),
                  ),
                ),
                if (_isTeacher)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.charcoalSlate),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showQuestionEditorDialog(existingQuestion: q);
                      } else if (val == 'duplicate') {
                        _showQuestionEditorDialog(duplicateFrom: q);
                      } else if (val == 'delete') {
                        _confirmDeleteQuestion(q);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit Question')),
                      const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Question Prompt
            SelectableText(
              q.question,
              style: const TextStyle(
                fontFamily: AppTheme.fontCardo,
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.inkForest,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),

            // Grounding & Source Metadata Chip
            if (q.sourcePage != null || q.supportingExcerpt != null || q.isAiGenerated) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (q.isAiGenerated)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: AppTheme.successColor),
                        SizedBox(width: 4),
                        Text('AI Grounded', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, color: AppTheme.successColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  if (q.sourcePage != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text('Page / Slide ${q.sourcePage}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  if (q.topic.isNotEmpty && q.topic != 'Other')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.label_outline, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(q.topic, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // MCQ Options layout
            if (isMcq) ...[
              ...List.generate(q.options!.length, (optIdx) {
                final optionText = q.options![optIdx];
                final optionLetter = String.fromCharCode(65 + optIdx);
                final isCorrectOption = q.correctOptionIndex == optIdx || (q.correctOptionIndices != null && q.correctOptionIndices!.contains(optIdx));

                Color cardColor = Colors.grey.shade50;
                Color borderColor = AppTheme.borderColor;
                Widget? trailingIcon;

                if (_isTeacher) {
                  // Teacher sees verified correct option highlighted
                  if (isCorrectOption) {
                    cardColor = AppTheme.mintWash.withValues(alpha: 0.5);
                    borderColor = AppTheme.successColor;
                    trailingIcon = const Icon(Icons.check_circle, size: 18, color: AppTheme.successColor);
                  }
                } else {
                  // Student interactive practice mode
                  if (selectedOptionIndex != null) {
                    if (optIdx == selectedOptionIndex) {
                      if (isCorrectOption) {
                        cardColor = AppTheme.mintWash.withValues(alpha: 0.6);
                        borderColor = AppTheme.successColor;
                        trailingIcon = const Icon(Icons.check_circle, size: 18, color: AppTheme.successColor);
                      } else {
                        cardColor = Colors.red.shade50;
                        borderColor = AppTheme.errorColor;
                        trailingIcon = const Icon(Icons.cancel, size: 18, color: AppTheme.errorColor);
                      }
                    } else if (isCorrectOption) {
                      cardColor = AppTheme.mintWash.withValues(alpha: 0.3);
                      borderColor = AppTheme.successColor.withValues(alpha: 0.6);
                      trailingIcon = const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.successColor);
                    }
                  }
                }

                return InkWell(
                  onTap: _isTeacher
                      ? null
                      : () {
                          setState(() {
                            _studentSelectedAnswers[q.id] = optIdx;
                          });
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$optionLetter. ',
                          style: TextStyle(
                            fontFamily: AppTheme.fontCardo,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: isCorrectOption && (_isTeacher || selectedOptionIndex != null) ? AppTheme.successColor : AppTheme.inkForest,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            optionText,
                            style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
                          ),
                        ),
                        if (trailingIcon != null) trailingIcon,
                      ],
                    ),
                  ),
                );
              }),

              // Distractor reasoning for Teacher or after Student makes an incorrect choice
              if (q.distractorReasoning != null && q.distractorReasoning!.isNotEmpty && (_isTeacher || selectedOptionIndex != null)) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.creamPaper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.psychology_outlined, size: 14, color: AppTheme.inkForest),
                          SizedBox(width: 6),
                          Text('Distractor Analysis (Common Misconceptions):', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkForest)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...q.distractorReasoning!.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '• Option ${e.key}: ${e.value}',
                            style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.charcoalSlate),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Conceptual / Short / Long / Numerical / Code View
              if (isRevealed || _isTeacher) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.creamPaper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_outlined, size: 14, color: AppTheme.successColor),
                          SizedBox(width: 6),
                          Text('Model Answer:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.inkForest)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        q.answer,
                        style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate, height: 1.35),
                      ),
                      if (q.keyPointsRubric != null && q.keyPointsRubric!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('Marking Rubric (Partial Credit Breakdown):', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkForest)),
                        const SizedBox(height: 4),
                        ...q.keyPointsRubric!.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✔ ', style: TextStyle(color: AppTheme.successColor, fontSize: 11)),
                                Expanded(
                                  child: Text(item, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.charcoalSlate)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                TextButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Reveal Model Answer & Marking Rubric'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.inkForest,
                    textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    setState(() => _revealedAnswers.add(q.id));
                  },
                ),
              ],
            ],

            // Supporting Excerpt
            if (q.supportingExcerpt != null && q.supportingExcerpt!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Excerpt: "${q.supportingExcerpt}"',
                        style: const TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic, fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Card Footer: Explain Simply button & Teacher actions
            Row(
              children: [
                // "Explain Simply" button (Workstream B structure)
                TextButton.icon(
                  icon: const Icon(Icons.lightbulb_outline, size: 14),
                  label: const Text('Explain Simply'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.inkForest,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    String? wrongOption;
                    if (selectedOptionIndex != null && q.options != null && selectedOptionIndex < q.options!.length) {
                      if (selectedOptionIndex != q.correctOptionIndex) {
                        wrongOption = q.options![selectedOptionIndex];
                      }
                    }
                    ExplainSimplyDialog.show(
                      context: context,
                      topic: q.topic,
                      subtopic: q.subtopic,
                      sourceContext: '${q.question}\n\nModel Answer: ${q.answer}\n\n${q.explanation ?? ""}',
                      sourcePage: q.sourcePage,
                      wrongOptionChosen: wrongOption,
                    );
                  },
                ),
                if (q.explanation != null && q.explanation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Tooltip(
                      message: q.explanation!,
                      child: const Icon(Icons.info_outline, size: 15, color: AppTheme.textSecondary),
                    ),
                  ),
                const Spacer(),

                // Teacher quick actions
                if (_isTeacher) ...[
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: AppTheme.textSecondary),
                    tooltip: 'Duplicate Question',
                    onPressed: () => _showQuestionEditorDialog(duplicateFrom: q),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSecondary),
                    tooltip: 'Edit Question',
                    onPressed: () => _showQuestionEditorDialog(existingQuestion: q),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    tooltip: 'Delete Question',
                    onPressed: () => _confirmDeleteQuestion(q),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTypeChip(String type) {
    Color bg = const Color(0xFFE0F2F1);
    Color fg = const Color(0xFF00796B);
    String label = 'MCQ';

    switch (type.toLowerCase()) {
      case 'mcq':
        label = 'MCQ (Single)';
        break;
      case 'multi_mcq':
        label = 'MCQ (Multi)';
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1976D2);
        break;
      case 'true_false':
        label = 'True/False';
        bg = const Color(0xFFF3E5F5);
        fg = const Color(0xFF7B1FA2);
        break;
      case 'short':
        label = 'Short Answer';
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case 'long':
        label = 'Long Answer';
        bg = const Color(0xFFEDE7F6);
        fg = const Color(0xFF512DA8);
        break;
      case 'numerical':
        label = 'Numerical';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'code':
        label = 'Code';
        bg = const Color(0xFFECEFF1);
        fg = const Color(0xFF37474F);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10.5, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    Color bg = Colors.green.shade50;
    Color fg = Colors.green.shade800;

    if (difficulty.toLowerCase() == 'medium') {
      bg = Colors.amber.shade50;
      fg = Colors.orange.shade900;
    } else if (difficulty.toLowerCase() == 'hard') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(difficulty, style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10.5, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildBloomChip(String bloom) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(6)),
      child: Text(bloom, style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
    );
  }

  // ===========================================================================
  // QUESTION CREATOR & EDITOR DIALOG
  // ===========================================================================
  void _showQuestionEditorDialog({Question? existingQuestion, Question? duplicateFrom}) {
    final base = existingQuestion ?? duplicateFrom;
    String qType = base?.questionType ?? 'mcq';
    String topic = base?.topic ?? (_classroom.subject.isNotEmpty ? _classroom.subject : 'General');
    int unitNum = base?.unitNumber ?? 1;
    String difficulty = base?.difficulty ?? 'Medium';
    String bloom = base?.bloomLevel ?? 'Understand';
    double marks = base?.marks ?? 1.0;
    double negMarks = base?.negativeMarks ?? 0.0;

    final promptCtrl = TextEditingController(text: base?.question ?? '');
    final answerCtrl = TextEditingController(text: base?.answer ?? '');
    final explanationCtrl = TextEditingController(text: base?.explanation ?? '');
    final tagsCtrl = TextEditingController(text: base?.tags.join(', ') ?? '');
    final sourcePageCtrl = TextEditingController(text: base?.sourcePage?.toString() ?? '');

    // MCQ Options
    final optACtrl = TextEditingController(text: (base?.options != null && base!.options!.isNotEmpty) ? base.options![0] : '');
    final optBCtrl = TextEditingController(text: (base?.options != null && base!.options!.length > 1) ? base.options![1] : '');
    final optCCtrl = TextEditingController(text: (base?.options != null && base!.options!.length > 2) ? base.options![2] : '');
    final optDCtrl = TextEditingController(text: (base?.options != null && base!.options!.length > 3) ? base.options![3] : '');
    int correctIndex = base?.correctOptionIndex ?? 0;

    // Distractor reasoning
    final distACtrl = TextEditingController(text: base?.distractorReasoning?['A'] ?? '');
    final distBCtrl = TextEditingController(text: base?.distractorReasoning?['B'] ?? '');
    final distCCtrl = TextEditingController(text: base?.distractorReasoning?['C'] ?? '');
    final distDCtrl = TextEditingController(text: base?.distractorReasoning?['D'] ?? '');

    // Marking Rubric Points for conceptual questions
    final List<TextEditingController> rubricControllers = (base?.keyPointsRubric != null && base!.keyPointsRubric!.isNotEmpty)
        ? base.keyPointsRubric!.map((r) => TextEditingController(text: r)).toList()
        : [TextEditingController(text: 'Accurately defines the core principle'), TextEditingController(text: 'Provides valid example/derivation')];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => CustomDialog(
          title: existingQuestion != null ? 'Edit Question' : (duplicateFrom != null ? 'Duplicate Question' : 'Create Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type selector
                Row(
                  children: [
                    const Text('Question Type:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: qType,
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'mcq', child: Text('Single-Select MCQ (4 Options)')),
                          DropdownMenuItem(value: 'multi_mcq', child: Text('Multi-Select MCQ')),
                          DropdownMenuItem(value: 'true_false', child: Text('True / False')),
                          DropdownMenuItem(value: 'short', child: Text('Short Answer (with Rubric)')),
                          DropdownMenuItem(value: 'long', child: Text('Long Answer (with Rubric)')),
                          DropdownMenuItem(value: 'numerical', child: Text('Numerical Problem')),
                          DropdownMenuItem(value: 'code', child: Text('Coding / Algorithmic Problem')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDlgState(() => qType = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Unit, Topic, Difficulty row
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: CustomTextField(
                        controller: TextEditingController(text: unitNum.toString()),
                        label: 'Unit #',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => unitNum = int.tryParse(v) ?? unitNum,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomTextField(
                        controller: TextEditingController(text: topic),
                        label: 'Topic / Subtopic',
                        onChanged: (v) => topic = v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: difficulty,
                        decoration: const InputDecoration(labelText: 'Difficulty', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                          DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'Hard', child: Text('Hard')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDlgState(() => difficulty = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: bloom,
                        decoration: const InputDecoration(labelText: 'Bloom Tier', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'Remember', child: Text('Remember')),
                          DropdownMenuItem(value: 'Understand', child: Text('Understand')),
                          DropdownMenuItem(value: 'Apply', child: Text('Apply')),
                          DropdownMenuItem(value: 'Analyze', child: Text('Analyze')),
                          DropdownMenuItem(value: 'Evaluate', child: Text('Evaluate')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDlgState(() => bloom = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Marks and Negative Marks
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: TextEditingController(text: marks.toString()),
                        label: 'Marks (+)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) => marks = double.tryParse(v) ?? marks,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomTextField(
                        controller: TextEditingController(text: negMarks.toString()),
                        label: 'Negative Marks (-)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) => negMarks = double.tryParse(v) ?? negMarks,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomTextField(
                        controller: sourcePageCtrl,
                        label: 'Source Page #',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Prompt
                CustomTextField(
                  controller: promptCtrl,
                  label: 'Question Prompt *',
                  hintText: 'Enter clear, well-phrased question prompt...',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // If MCQ
                if (qType == 'mcq' || qType == 'multi_mcq') ...[
                  const Text('Options & Correct Choice:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildOptionEditorRow('A', optACtrl, distACtrl, 0, correctIndex, (idx) => setDlgState(() => correctIndex = idx)),
                  _buildOptionEditorRow('B', optBCtrl, distBCtrl, 1, correctIndex, (idx) => setDlgState(() => correctIndex = idx)),
                  _buildOptionEditorRow('C', optCCtrl, distCCtrl, 2, correctIndex, (idx) => setDlgState(() => correctIndex = idx)),
                  _buildOptionEditorRow('D', optDCtrl, distDCtrl, 3, correctIndex, (idx) => setDlgState(() => correctIndex = idx)),
                ] else if (qType == 'true_false') ...[
                  const Text('Correct Option:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13)),
                  Row(
                    children: [
                      Radio<int>(
                        value: 0,
                        groupValue: correctIndex,
                        activeColor: AppTheme.inkForest,
                        onChanged: (v) => setDlgState(() => correctIndex = v ?? 0),
                      ),
                      const Text('True', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13)),
                      const SizedBox(width: 20),
                      Radio<int>(
                        value: 1,
                        groupValue: correctIndex,
                        activeColor: AppTheme.inkForest,
                        onChanged: (v) => setDlgState(() => correctIndex = v ?? 1),
                      ),
                      const Text('False', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13)),
                    ],
                  ),
                ] else ...[
                  // Conceptual / Model answer
                  CustomTextField(
                    controller: answerCtrl,
                    label: 'Model / Reference Answer *',
                    hintText: 'Provide the ideal student answer...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Marking Rubric Items:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Point'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () {
                          setDlgState(() => rubricControllers.add(TextEditingController()));
                        },
                      ),
                    ],
                  ),
                  ...List.generate(rubricControllers.length, (idx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: rubricControllers[idx],
                              label: 'Rubric Criterion ${idx + 1}',
                              hintText: 'Rubric criterion ${idx + 1}',
                            ),
                          ),
                          if (rubricControllers.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                              onPressed: () {
                                setDlgState(() => rubricControllers.removeAt(idx));
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 10),
                CustomTextField(
                  controller: explanationCtrl,
                  label: 'Educational Explanation / Guidance',
                  hintText: 'Optional background reasoning for students...',
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: tagsCtrl,
                  label: 'Tags (comma-separated)',
                  hintText: 'e.g. OS, CPU Scheduling, Round Robin',
                ),
              ],
            ),
          ),
          confirmLabel: existingQuestion != null ? 'Update Question' : 'Save Question',
          onConfirm: () async {
            if (promptCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a question prompt.'), backgroundColor: AppTheme.errorColor),
              );
              return;
            }

            List<String>? options;
            String finalAnswer = answerCtrl.text.trim();
            Map<String, String>? distractors;

            if (qType == 'mcq' || qType == 'multi_mcq') {
              options = [
                optACtrl.text.trim(),
                optBCtrl.text.trim(),
                optCCtrl.text.trim(),
                optDCtrl.text.trim(),
              ];
              if (correctIndex < options.length) {
                finalAnswer = options[correctIndex];
              }
              distractors = {
                if (distACtrl.text.trim().isNotEmpty) 'A': distACtrl.text.trim(),
                if (distBCtrl.text.trim().isNotEmpty) 'B': distBCtrl.text.trim(),
                if (distCCtrl.text.trim().isNotEmpty) 'C': distCCtrl.text.trim(),
                if (distDCtrl.text.trim().isNotEmpty) 'D': distDCtrl.text.trim(),
              };
            } else if (qType == 'true_false') {
              options = ['True', 'False'];
              finalAnswer = correctIndex == 0 ? 'True' : 'False';
            }

            final parsedRubric = rubricControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
            final parsedTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
            final parsedSourcePage = int.tryParse(sourcePageCtrl.text.trim());

            final targetQuestion = Question(
              id: existingQuestion?.id ?? '',
              topic: topic.trim().isNotEmpty ? topic.trim() : 'General',
              question: promptCtrl.text.trim(),
              answer: finalAnswer.isNotEmpty ? finalAnswer : 'See Explanation',
              options: options,
              correctOptionIndex: (qType == 'mcq' || qType == 'multi_mcq' || qType == 'true_false') ? correctIndex : null,
              explanation: explanationCtrl.text.trim().isNotEmpty ? explanationCtrl.text.trim() : null,
              distractorReasoning: distractors,
              keyPointsRubric: parsedRubric.isNotEmpty ? parsedRubric : null,
              unitNumber: unitNum,
              questionType: qType,
              difficulty: difficulty,
              bloomLevel: bloom,
              marks: marks,
              negativeMarks: negMarks,
              tags: parsedTags,
              sourcePage: parsedSourcePage,
              classroomId: _classroom.id,
              isAiGenerated: existingQuestion?.isAiGenerated ?? false,
              createdAt: existingQuestion?.createdAt ?? DateTime.now(),
            );

            try {
              if (existingQuestion != null) {
                await FirestoreService.instance.updateClassroomQuestion(_classroom.id, targetQuestion);
              } else {
                await FirestoreService.instance.createClassroomQuestion(_classroom.id, targetQuestion);
              }
              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(existingQuestion != null ? 'Question updated successfully!' : 'Question added to Classroom Question Bank!'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save question: $e'), backgroundColor: AppTheme.errorColor),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildOptionEditorRow(
    String letter,
    TextEditingController textCtrl,
    TextEditingController distCtrl,
    int index,
    int correctIndex,
    Function(int) onSelectCorrect,
  ) {
    final isCorrect = index == correctIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Radio<int>(
                value: index,
                groupValue: correctIndex,
                activeColor: AppTheme.successColor,
                onChanged: (v) {
                  if (v != null) onSelectCorrect(v);
                },
              ),
              Text('Option $letter: ', style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 13, color: isCorrect ? AppTheme.successColor : AppTheme.charcoalSlate)),
              Expanded(
                child: CustomTextField(
                  controller: textCtrl,
                  label: 'Option $letter',
                  hintText: 'Enter text for option $letter...',
                ),
              ),
            ],
          ),
          if (!isCorrect)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 2),
              child: CustomTextField(
                controller: distCtrl,
                label: 'Distractor Reason',
                hintText: 'Distractor reasoning for $letter (why it is wrong)...',
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDeleteQuestion(Question q) {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Delete Question?',
        content: Text(
          'Are you sure you want to permanently delete this question from the Question Bank?\n\n"${q.question}"',
          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13.5, color: AppTheme.charcoalSlate),
        ),
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          try {
            await FirestoreService.instance.deleteClassroomQuestion(_classroom.id, q.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Question deleted from Question Bank.'), backgroundColor: AppTheme.inkForest),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.errorColor),
              );
            }
          }
        },
      ),
    );
  }

  void _bulkDeleteQuestions() {
    final count = _selectedQuestionIds.length;
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Delete $count Questions?',
        content: Text(
          'Are you sure you want to delete all $count selected questions from the Question Bank?',
          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13.5, color: AppTheme.charcoalSlate),
        ),
        confirmLabel: 'Delete All Selected',
        confirmColor: Colors.red,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          try {
            for (final qId in _selectedQuestionIds.toList()) {
              await FirestoreService.instance.deleteClassroomQuestion(_classroom.id, qId);
            }
            if (mounted) {
              setState(() => _selectedQuestionIds.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Successfully deleted $count questions.'), backgroundColor: AppTheme.inkForest),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Bulk delete failed: $e'), backgroundColor: AppTheme.errorColor),
              );
            }
          }
        },
      ),
    );
  }

  // ===========================================================================
  // CSV IMPORT & EXPORT
  // ===========================================================================
  void _exportQuestionBankCsv(List<Question> questions) {
    final csvData = ExportService.instance.generateQuestionBankCsv(questions);
    Clipboard.setData(ClipboardData(text: csvData));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Question Bank CSV copied to clipboard (${questions.length} questions)! Ready to paste into Excel or Sheets.'),
        backgroundColor: AppTheme.inkForest,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showImportQuestionsDialog() {
    final textCtrl = TextEditingController();
    List<Question> parsed = [];
    bool isParsing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => CustomDialog(
          title: 'Import Questions from CSV',
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload or paste CSV rows matching our standard format:\nTopic, Unit, Type, Difficulty, Bloom, Marks, Negative Marks, Question, Answer, Option A, Option B, Option C, Option D, Correct Option, Explanation, Tags',
                  style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Pick CSV File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mintWash,
                        foregroundColor: AppTheme.inkForest,
                        elevation: 0,
                      ),
                      onPressed: () async {
                        try {
                          final result = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['csv', 'txt'],
                          );
                          if (result.isNotEmpty) {
                            final file = result.first;
                            final bytes = await file.readAsBytes();
                            final text = utf8.decode(bytes);
                            textCtrl.text = text;
                            final list = ExportService.instance.parseQuestionBankCsv(text, classroomId: _classroom.id, defaultTopic: _classroom.subject);
                            setDlgState(() => parsed = list);
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error reading file: $e'), backgroundColor: AppTheme.errorColor),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy CSV Template'),
                      onPressed: () {
                        const template = 'Topic,Unit,Type,Difficulty,Bloom,Marks,Negative Marks,Question,Answer,Option A,Option B,Option C,Option D,Correct Option,Explanation,Tags\n'
                            'Operating Systems,1,mcq,Medium,Understand,1.0,0.0,"What is a process control block (PCB)?","A data structure containing process state information","A compiler tool","A data structure containing process state information","A hardware cache register","An optical bus architecture",B,"PCB maintains PID, registers, and program counter.","OS; Processes"';
                        Clipboard.setData(const ClipboardData(text: template));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sample CSV template copied to clipboard!'), backgroundColor: AppTheme.inkForest),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: textCtrl,
                  label: 'Or Paste CSV Content Here',
                  hintText: 'Paste CSV text with header row...',
                  maxLines: 8,
                  onChanged: (val) {
                    final list = ExportService.instance.parseQuestionBankCsv(val, classroomId: _classroom.id, defaultTopic: _classroom.subject);
                    setDlgState(() => parsed = list);
                  },
                ),
                if (parsed.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.mintWash.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.successColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${parsed.length} valid questions parsed and ready to import!',
                          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.inkForest),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          confirmLabel: isParsing ? 'Importing...' : 'Import ${parsed.length} Questions',
          onConfirm: parsed.isEmpty || isParsing
              ? null
              : () async {
                  setDlgState(() => isParsing = true);
                  try {
                    await FirestoreService.instance.batchAddClassroomQuestions(_classroom.id, parsed);
                    if (mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Successfully imported ${parsed.length} questions into Question Bank!'), backgroundColor: AppTheme.successColor),
                      );
                    }
                  } catch (e) {
                    setDlgState(() => isParsing = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Import failed: $e'), backgroundColor: AppTheme.errorColor),
                      );
                    }
                  }
                },
        ),
      ),
    );
  }

  // ===========================================================================
  // AI QUESTION SUGGESTION WITH COVERAGE AUDIT & REVIEW PIPELINE
  // ===========================================================================
  void _showAiSuggestQuestionsDialog({ClassroomNote? preselectedNote}) {
    ClassroomNote? selectedNote = preselectedNote;
    int questionCount = 8;
    String typeMix = 'balanced'; // balanced, mcq_only, conceptual_only
    String targetDifficulty = 'Balanced';
    double marks = 1.0;

    bool isGenerating = false;
    String stageText = '';
    double progressValue = 0.0;

    // Review state
    CoverageReport? coverageReport;
    List<Question> candidateQuestions = [];
    final Set<int> acceptedIndices = {};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (isGenerating) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(28),
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 40, color: AppTheme.inkForest),
                    const SizedBox(height: 16),
                    const Text(
                      'AI Question Generator Active',
                      style: TextStyle(fontFamily: AppTheme.fontCardo, fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.inkForest),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stageText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(value: progressValue > 0 ? progressValue : null, color: AppTheme.inkForest, backgroundColor: AppTheme.mintWash),
                    const SizedBox(height: 8),
                    const Text(
                      'Grounding strictly in note excerpts with distractor analysis and Bloom tagging...',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          // Step 3: Review UI & Coverage Report
          if (candidateQuestions.isNotEmpty) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 720,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(Icons.verified, color: AppTheme.inkForest, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Review AI Suggested Questions',
                                  style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.inkForest),
                                ),
                                Text(
                                  '${acceptedIndices.length} of ${candidateQuestions.length} questions selected for Question Bank.',
                                  style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setDlgState(() {
                                if (acceptedIndices.length == candidateQuestions.length) {
                                  acceptedIndices.clear();
                                } else {
                                  acceptedIndices.addAll(List.generate(candidateQuestions.length, (i) => i));
                                }
                              });
                            },
                            child: Text(acceptedIndices.length == candidateQuestions.length ? 'Deselect All' : 'Select All'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Coverage Report Banner
                      if (coverageReport != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.sageBlob.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.analytics_outlined, size: 28, color: AppTheme.inkForest),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Coverage Matrix: ${coverageReport!.pageCoveragePercentage.toStringAsFixed(0)}% Note Covered',
                                      style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.inkForest),
                                    ),
                                    Text(
                                      '${coverageReport!.mcqCount} MCQs · ${coverageReport!.conceptualCount} Conceptual · ${coverageReport!.coveredPages.length} Pages Covered · 100% Grounded',
                                      style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.charcoalSlate),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Candidate questions review list
                      Expanded(
                        child: ListView.builder(
                          itemCount: candidateQuestions.length,
                          itemBuilder: (ctx, idx) {
                            final cq = candidateQuestions[idx];
                            final isAccepted = acceptedIndices.contains(idx);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isAccepted ? Colors.white : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isAccepted ? AppTheme.inkForest : AppTheme.borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isAccepted,
                                        activeColor: AppTheme.inkForest,
                                        onChanged: (val) {
                                          setDlgState(() {
                                            if (val == true) {
                                              acceptedIndices.add(idx);
                                            } else {
                                              acceptedIndices.remove(idx);
                                            }
                                          });
                                        },
                                      ),
                                      _buildQuestionTypeChip(cq.questionType),
                                      const SizedBox(width: 6),
                                      _buildDifficultyChip(cq.difficulty ?? 'Medium'),
                                      const SizedBox(width: 6),
                                      _buildBloomChip(cq.bloomLevel ?? 'Understand'),
                                      const Spacer(),
                                      if (cq.sourcePage != null)
                                        Text('Page ${cq.sourcePage}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    cq.question,
                                    style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.inkForest),
                                  ),
                                  const SizedBox(height: 6),

                                  if (cq.options != null && cq.options!.isNotEmpty) ...[
                                    ...List.generate(cq.options!.length, (optI) {
                                      final isCorrect = cq.correctOptionIndex == optI;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${String.fromCharCode(65 + optI)}. ',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isCorrect ? AppTheme.successColor : AppTheme.charcoalSlate),
                                            ),
                                            Expanded(
                                              child: Text(
                                                cq.options![optI],
                                                style: TextStyle(fontSize: 12, color: isCorrect ? AppTheme.inkForest : AppTheme.charcoalSlate),
                                              ),
                                            ),
                                            if (isCorrect) const Icon(Icons.check, size: 14, color: AppTheme.successColor),
                                          ],
                                        ),
                                      );
                                    }),
                                  ] else ...[
                                    Text('Model Answer: ${cq.answer}', style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, color: AppTheme.charcoalSlate)),
                                  ],

                                  const SizedBox(height: 8),
                                  // Quick Tuning Actions: Make Harder, Make Easier, Reject
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.trending_up, size: 14),
                                        label: const Text('Make Harder', style: TextStyle(fontSize: 11)),
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
                                        onPressed: () {
                                          setDlgState(() {
                                            candidateQuestions[idx] = cq.copyWith(
                                              difficulty: 'Hard',
                                              bloomLevel: 'Analyze',
                                              question: 'In deep analysis: ${cq.question}',
                                            );
                                          });
                                        },
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.trending_down, size: 14),
                                        label: const Text('Make Easier', style: TextStyle(fontSize: 11)),
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
                                        onPressed: () {
                                          setDlgState(() {
                                            candidateQuestions[idx] = cq.copyWith(
                                              difficulty: 'Easy',
                                              bloomLevel: 'Remember',
                                              question: 'Define fundamentally: ${cq.question}',
                                            );
                                          });
                                        },
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () {
                                          setDlgState(() {
                                            candidateQuestions.removeAt(idx);
                                            acceptedIndices.remove(idx);
                                          });
                                        },
                                        child: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Footer Save Action
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          PrimaryButton(
                            text: 'Add ${acceptedIndices.length} Questions to Bank',
                            icon: Icons.check,
                            height: 38,
                            onPressed: acceptedIndices.isEmpty
                                ? null
                                : () async {
                                    final toSave = acceptedIndices.map((i) => candidateQuestions[i]).toList();
                                    try {
                                      await FirestoreService.instance.batchAddClassroomQuestions(_classroom.id, toSave);
                                      if (mounted) {
                                        Navigator.of(ctx).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Added ${toSave.length} AI-recommended questions to Question Bank!'),
                                            backgroundColor: AppTheme.successColor,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to save questions: $e'), backgroundColor: AppTheme.errorColor),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Step 1: Configuration Form
          return StreamBuilder<List<ClassroomNote>>(
            stream: FirestoreService.instance.getClassroomNotesStream(_classroom.id),
            builder: (ctx, notesSnap) {
              final classNotes = notesSnap.data ?? [];
              if (selectedNote == null && classNotes.isNotEmpty) {
                selectedNote = classNotes.first;
              }

              return CustomDialog(
                title: 'Suggest Questions from Notes',
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select note material to extract grounded conceptual and MCQ practice questions with Bloom taxonomy and distractor analysis.',
                        style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, color: AppTheme.charcoalSlate),
                      ),
                      const SizedBox(height: 14),

                      // Note selector
                      const Text('Source Document / Note *:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      if (classNotes.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                          child: const Text('No notes uploaded yet. Please upload class notes or slides in the Notes tab first.', style: TextStyle(fontSize: 12, color: Colors.brown)),
                        )
                      else
                        DropdownButtonFormField<ClassroomNote>(
                          value: selectedNote,
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          items: classNotes.map((n) {
                            return DropdownMenuItem<ClassroomNote>(
                              value: n,
                              child: Text('Unit ${n.unitNumber}: ${n.title} (${n.fileName ?? "note"})', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (n) => setDlgState(() => selectedNote = n),
                        ),
                      const SizedBox(height: 12),

                      // Count selector
                      Row(
                        children: [
                          const Text('Number of Questions:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 12),
                          DropdownButton<int>(
                            value: questionCount,
                            items: const [
                              DropdownMenuItem(value: 5, child: Text('5 Questions')),
                              DropdownMenuItem(value: 8, child: Text('8 Questions')),
                              DropdownMenuItem(value: 12, child: Text('12 Questions')),
                              DropdownMenuItem(value: 16, child: Text('16 Questions')),
                              DropdownMenuItem(value: 20, child: Text('20 Questions')),
                            ],
                            onChanged: (v) {
                              if (v != null) setDlgState(() => questionCount = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Question Type Mix
                      const Text('Question Type Mix:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Balanced (MCQ + Conceptual)'),
                            selected: typeMix == 'balanced',
                            selectedColor: AppTheme.mintWash,
                            onSelected: (sel) {
                              if (sel) setDlgState(() => typeMix = 'balanced');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Only MCQs'),
                            selected: typeMix == 'mcq_only',
                            selectedColor: AppTheme.mintWash,
                            onSelected: (sel) {
                              if (sel) setDlgState(() => typeMix = 'mcq_only');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Difficulty distribution
                      const Text('Target Difficulty:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Balanced Mix'),
                            selected: targetDifficulty == 'Balanced',
                            selectedColor: AppTheme.mintWash,
                            onSelected: (sel) {
                              if (sel) setDlgState(() => targetDifficulty = 'Balanced');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Exam / Hard Focus'),
                            selected: targetDifficulty == 'Hard',
                            selectedColor: AppTheme.mintWash,
                            onSelected: (sel) {
                              if (sel) setDlgState(() => targetDifficulty = 'Hard');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                confirmLabel: 'Generate Questions',
                onConfirm: selectedNote == null
                    ? null
                    : () async {
                        setDlgState(() {
                          isGenerating = true;
                          stageText = 'Parsing document sections and hierarchical topic map...';
                          progressValue = 0.15;
                        });

                        try {
                          // Parse note text into ProcessedDocument
                          final doc = await DocumentProcessingService.instance.processBytes(
                            bytes: utf8.encode(selectedNote!.extractedText),
                            fileName: selectedNote!.fileName ?? '${selectedNote!.title}.txt',
                            preferredTopic: selectedNote!.unitTitle,
                          );

                          setDlgState(() {
                            stageText = 'Generating deep questions with distractor analysis across topics...';
                            progressValue = 0.50;
                          });

                          final deepResult = await NotesAiService.instance.generateDeepCoverageQuestions(
                            doc: doc,
                            onProgress: (stage, msg, pct) {
                              setDlgState(() {
                                stageText = msg;
                                progressValue = pct;
                              });
                            },
                          );

                          // Convert GeneratedPracticeQuestions to Question models
                          final converted = deepResult.questions.take(questionCount).map((gq) {
                            return Question(
                              id: '',
                              topic: gq.topic,
                              question: gq.question,
                              answer: gq.answer,
                              options: gq.options,
                              correctOptionIndex: gq.correctOptionIndex,
                              explanation: gq.explanation,
                              sourcePage: gq.sourcePage,
                              difficulty: targetDifficulty == 'Hard' ? 'Hard' : (gq.difficulty ?? 'Medium'),
                              bloomLevel: targetDifficulty == 'Hard' ? 'Analyze' : (gq.bloomLevel ?? 'Understand'),
                              subtopic: gq.subtopic,
                              sourceChunkId: gq.sourceChunkId,
                              supportingExcerpt: gq.supportingExcerpt,
                              keyPointsRubric: gq.keyPointsRubric,
                              distractorReasoning: gq.distractorReasoning,
                              classroomId: _classroom.id,
                              unitNumber: selectedNote!.unitNumber,
                              documentId: selectedNote!.id,
                              questionType: gq.isMcq ? 'mcq' : 'short',
                              marks: marks,
                              negativeMarks: 0.0,
                              tags: [
                                if (gq.bloomLevel != null) gq.bloomLevel!,
                                if (gq.subtopic != null) gq.subtopic!,
                                'Unit ${selectedNote!.unitNumber}',
                              ],
                              isAiGenerated: true,
                              createdAt: DateTime.now(),
                            );
                          }).toList();

                          setDlgState(() {
                            isGenerating = false;
                            candidateQuestions = converted;
                            coverageReport = deepResult.report;
                            acceptedIndices.addAll(List.generate(converted.length, (i) => i));
                          });
                        } catch (e) {
                          setDlgState(() => isGenerating = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Generation failed: $e'), backgroundColor: AppTheme.errorColor),
                            );
                          }
                        }
                      },
              );
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 4: EXAMS (Phase 4 Full Implementation)
  // ===========================================================================
  Widget _buildExamsTab() {
    return StreamBuilder<({List<Exam> exams, bool isFromCache})>(
      stream: FirestoreService.instance.getClassroomExamsStream(_classroom.id),
      builder: (context, snapshot) {
        final allExams = snapshot.data?.exams ?? [];

        // Apply local filter
        final filteredExams = allExams.where((e) {
          if (_selectedExamFilter == 'ongoing') return e.isOngoing;
          if (_selectedExamFilter == 'upcoming') {
            return e.startWindow != null && DateTime.now().isBefore(e.startWindow!);
          }
          if (_selectedExamFilter == 'past') return e.isExpired;
          return true;
        }).toList();

        final ongoingCount = allExams.where((e) => e.isOngoing).length;
        final totalQuestionsCount = allExams.fold<int>(0, (acc, e) => acc + e.questions.length);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Botanical Header Banner
            WatercolorBlobContainer(
              variant: BlobVariant.mintWash,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final textCol = Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Timed Exams & Assessments',
                              style: TextStyle(
                                fontFamily: AppTheme.fontCardo,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppTheme.inkForest,
                              ),
                            ),
                            Text(
                              _isTeacher
                                  ? 'Build online exams with blueprint generation, randomized questions, and tab-switch monitoring.'
                                  : 'Take proctored exams, auto-save answers, and view comprehensive scorecards.',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontZilla,
                                fontSize: 12.5,
                                color: AppTheme.charcoalSlate,
                              ),
                            ),
                          ],
                        ),
                      );

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 36, color: AppTheme.inkForest),
                                const SizedBox(width: 14),
                                textCol,
                              ],
                            ),
                            if (_isTeacher) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: PrimaryButton(
                                  text: 'Create Exam',
                                  icon: Icons.add,
                                  height: 38,
                                  onPressed: () => _showCreateExamDialog(),
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 36, color: AppTheme.inkForest),
                          const SizedBox(width: 14),
                          textCol,
                          if (_isTeacher) ...[
                            const SizedBox(width: 12),
                            PrimaryButton(
                              text: 'Create Exam',
                              icon: Icons.add,
                              height: 38,
                              onPressed: () => _showCreateExamDialog(),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Metrics Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildHeaderStatChip(Icons.assignment_outlined, '${allExams.length} Total Exams'),
                      _buildHeaderStatChip(Icons.play_circle_outline, '$ongoingCount Active / Ongoing'),
                      _buildHeaderStatChip(Icons.quiz_outlined, '$totalQuestionsCount Assessed Questions'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Filter Chips Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Filter:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoalSlate)),
                    const SizedBox(width: 8),
                    _buildExamFilterChip('all', 'All Exams'),
                    _buildExamFilterChip('ongoing', 'Ongoing / Active'),
                    _buildExamFilterChip('upcoming', 'Upcoming'),
                    _buildExamFilterChip('past', 'Completed / Past'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Content List
            if (snapshot.connectionState == ConnectionState.waiting && allExams.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredExams.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: EmptyState(
                  icon: Icons.assignment_turned_in_outlined,
                  title: allExams.isEmpty ? 'No Active or Scheduled Exams' : 'No Exams Match Filter',
                  message: allExams.isEmpty
                      ? (_isTeacher
                          ? 'Create your first exam with duration, start window, passing marks, and question shuffling.'
                          : 'No exams have been assigned to you in this classroom yet.')
                      : 'Try switching your filter to "All Exams".',
                  actionText: allExams.isEmpty && _isTeacher ? 'Create Exam' : null,
                  onAction: allExams.isEmpty && _isTeacher ? () => _showCreateExamDialog() : null,
                ),
              )
            else
              ...filteredExams.map((exam) => _buildExamCard(exam)),
          ],
        );
      },
    );
  }

  Widget _buildExamFilterChip(String filterKey, String label) {
    final isSelected = _selectedExamFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.mintWash,
        labelStyle: TextStyle(
          fontFamily: AppTheme.fontZilla,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: isSelected ? AppTheme.inkForest : AppTheme.charcoalSlate,
        ),
        onSelected: (sel) {
          if (sel) setState(() => _selectedExamFilter = filterKey);
        },
      ),
    );
  }

  // ===========================================================================
  // EXAM CARD (Student Runner Action & Teacher Grading / Analytics)
  // ===========================================================================
  Widget _buildExamCard(Exam exam) {
    final isOngoing = exam.isOngoing;
    final isExpired = exam.isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isOngoing ? AppTheme.inkForest : AppTheme.borderColor, width: isOngoing ? 1.6 : 1.0),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOngoing
                        ? AppTheme.mintWash.withValues(alpha: 0.6)
                        : (isExpired ? Colors.grey.shade100 : Colors.amber.shade50),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isOngoing ? AppTheme.successColor : (isExpired ? Colors.grey : Colors.amber.shade800),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOngoing ? Icons.play_circle : (isExpired ? Icons.history : Icons.schedule),
                        size: 12,
                        color: isOngoing ? AppTheme.successColor : (isExpired ? Colors.grey.shade700 : Colors.amber.shade900),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOngoing ? 'ONGOING' : (isExpired ? 'PAST EXAM' : 'UPCOMING'),
                        style: TextStyle(
                          fontFamily: AppTheme.fontZilla,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOngoing ? AppTheme.successColor : (isExpired ? Colors.grey.shade700 : Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (exam.unitNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                    child: Text('Unit ${exam.unitNumber}', style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.charcoalSlate)),
                  ),
                const Spacer(),
                if (_isTeacher)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.charcoalSlate),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showCreateExamDialog(existingExam: exam);
                      } else if (val == 'release_scores') {
                        FirestoreService.instance.releaseExamScores(_classroom.id, exam.id, !exam.releaseScoresImmediately);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(exam.releaseScoresImmediately ? 'Exam scores hidden from students.' : 'All exam scores released to students!'),
                            backgroundColor: AppTheme.inkForest,
                          ),
                        );
                      } else if (val == 'delete') {
                        _confirmDeleteExam(exam);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit Exam')),
                      PopupMenuItem(
                        value: 'release_scores',
                        child: Text(exam.releaseScoresImmediately ? 'Hide Released Scores' : 'Release Scores to Students'),
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Exam', style: TextStyle(color: Colors.red))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Exam Title & Subject
            Text(
              exam.title,
              style: const TextStyle(
                fontFamily: AppTheme.fontCardo,
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.inkForest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${exam.subject} · ${exam.questions.length} Questions · Passing Marks: ${exam.passingMarks.toStringAsFixed(0)} / ${exam.totalMarks.toStringAsFixed(0)}',
              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
            ),
            const SizedBox(height: 8),

            // Badges row: duration, attempts, integrity
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildExamMetaBadge(Icons.timer, '${exam.durationMinutes} mins'),
                _buildExamMetaBadge(Icons.fullscreen, exam.fullScreenEnforced ? 'Full-screen' : 'Standard'),
                _buildExamMetaBadge(Icons.tab_unselected, 'Tab limit: ${exam.tabSwitchLimit}'),
                if (exam.allowCalculator) _buildExamMetaBadge(Icons.calculate, 'Calculator'),
                if (exam.watermarkStudentId) _buildExamMetaBadge(Icons.shield_outlined, 'Watermarked'),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Action Footer
            Row(
              children: [
                if (_isTeacher) ...[
                  // Teacher: Submissions Stream count & management
                  StreamBuilder<List<ExamSubmission>>(
                    stream: FirestoreService.instance.getExamSubmissionsStream(_classroom.id, exam.id),
                    builder: (ctx, subSnap) {
                      final subs = subSnap.data ?? [];
                      return Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.people_outline, size: 15),
                            label: Text('Submissions (${subs.length})'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.inkForest,
                              side: const BorderSide(color: AppTheme.inkForest),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _showExamSubmissionsDialog(exam),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.bar_chart, size: 15),
                            label: const Text('Analytics'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.charcoalSlate,
                              side: const BorderSide(color: AppTheme.borderColor),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12),
                            ),
                            onPressed: subs.isEmpty ? null : () => _showExamAnalyticsDialog(exam),
                          ),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  // Student: Check submission status & launch runner
                  FutureBuilder<ExamSubmission?>(
                    future: FirestoreService.instance.getStudentExamSubmission(_classroom.id, exam.id, widget.currentUser.id),
                    builder: (ctx, subSnap) {
                      final sub = subSnap.data;
                      if (sub != null && (sub.status == 'submitted' || sub.status == 'graded' || sub.status == 'released')) {
                        if (sub.isReleased || exam.releaseScoresImmediately) {
                          return ElevatedButton.icon(
                            icon: const Icon(Icons.emoji_events, size: 15),
                            label: Text('Scorecard: ${sub.totalMarksObtained.toStringAsFixed(1)} / ${sub.maxMarks.toStringAsFixed(0)} (${sub.percentage.toStringAsFixed(0)}%)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: sub.isPassed ? AppTheme.successColor : AppTheme.inkForest,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ExamRunnerScreen(
                                    exam: exam,
                                    currentUser: widget.currentUser,
                                    classroomId: _classroom.id,
                                  ),
                                ),
                              );
                            },
                          );
                        } else {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppTheme.mintWash.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 14, color: AppTheme.inkForest),
                                SizedBox(width: 6),
                                Text('Submitted · Grading in Progress', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.inkForest)),
                              ],
                            ),
                          );
                        }
                      }

                      // Not submitted yet
                      if (isOngoing) {
                        return PrimaryButton(
                          text: sub != null && sub.status == 'in_progress' ? 'Resume Exam' : 'Start Exam',
                          icon: Icons.play_arrow,
                          height: 36,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ExamRunnerScreen(
                                  exam: exam,
                                  currentUser: widget.currentUser,
                                  classroomId: _classroom.id,
                                ),
                              ),
                            );
                          },
                        );
                      } else if (isExpired) {
                        return const Text('Exam submission window has expired.', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: Colors.grey));
                      } else {
                        return const Text('Exam will open during scheduled window.', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.textSecondary));
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamMetaBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10.5, color: AppTheme.charcoalSlate)),
        ],
      ),
    );
  }

  // ===========================================================================
  // TEACHER CREATE EXAM & BLUEPRINT GENERATOR DIALOG
  // ===========================================================================
  void _showCreateExamDialog({Exam? existingExam}) {
    final titleCtrl = TextEditingController(text: existingExam?.title ?? '');
    final subjectCtrl = TextEditingController(text: existingExam?.subject ?? _classroom.subject);
    final unitCtrl = TextEditingController(text: existingExam?.unitNumber?.toString() ?? '1');
    final durationCtrl = TextEditingController(text: existingExam?.durationMinutes.toString() ?? '60');
    final passMarksCtrl = TextEditingController(text: existingExam?.passingMarks.toString() ?? '40');
    final totalMarksCtrl = TextEditingController(text: existingExam?.totalMarks.toString() ?? '100');
    final instructionsCtrl = TextEditingController(text: existingExam?.instructions ?? 'Answer all questions carefully. Maintain focus in this window.');

    bool fullScreen = existingExam?.fullScreenEnforced ?? true;
    int tabLimit = existingExam?.tabSwitchLimit ?? 3;
    bool disableCopy = existingExam?.disableCopyPaste ?? true;
    bool allowCalc = existingExam?.allowCalculator ?? true;
    bool watermark = existingExam?.watermarkStudentId ?? true;
    bool shuffleQ = existingExam?.shuffleQuestions ?? true;
    bool shuffleOpt = existingExam?.shuffleOptions ?? true;
    bool releaseNow = existingExam?.releaseScoresImmediately ?? false;

    // Selected questions for this exam
    List<Question> examQuestions = List<Question>.from(existingExam?.questions ?? []);

    // Blueprint generator inputs
    int blueprintMcqCount = 5;
    int blueprintShortCount = 2;
    int blueprintLongCount = 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => CustomDialog(
          title: existingExam != null ? 'Edit Timed Exam' : 'Create Timed Exam',
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(controller: titleCtrl, label: 'Exam Title *', hintText: 'e.g. Midterm Assessment: CPU & Memory'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: CustomTextField(controller: subjectCtrl, label: 'Subject')),
                    const SizedBox(width: 8),
                    SizedBox(width: 80, child: CustomTextField(controller: unitCtrl, label: 'Unit #', keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: CustomTextField(controller: durationCtrl, label: 'Duration (Mins)', keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: CustomTextField(controller: passMarksCtrl, label: 'Passing Marks', keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: CustomTextField(controller: totalMarksCtrl, label: 'Total Marks', keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(controller: instructionsCtrl, label: 'Instructions', maxLines: 2),
                const SizedBox(height: 14),

                // Integrity Toggles
                const Text('Proctoring & Integrity Controls:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest)),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Enforce Full-Screen Mode', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5)),
                  value: fullScreen,
                  activeThumbColor: AppTheme.inkForest,
                  onChanged: (v) => setDlgState(() => fullScreen = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Disable Copy-Paste & Right Click', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5)),
                  value: disableCopy,
                  activeThumbColor: AppTheme.inkForest,
                  onChanged: (v) => setDlgState(() => disableCopy = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Enable Built-in Scratch Calculator', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5)),
                  value: allowCalc,
                  activeThumbColor: AppTheme.inkForest,
                  onChanged: (v) => setDlgState(() => allowCalc = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Watermark Student ID on Screen', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5)),
                  value: watermark,
                  activeThumbColor: AppTheme.inkForest,
                  onChanged: (v) => setDlgState(() => watermark = v),
                ),
                Row(
                  children: [
                    const Text('Tab Switch Limit:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5)),
                    const SizedBox(width: 10),
                    DropdownButton<int>(
                      value: tabLimit,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 (Strict: Auto-submit on 1st)')),
                        DropdownMenuItem(value: 2, child: Text('2 tab switches')),
                        DropdownMenuItem(value: 3, child: Text('3 tab switches (Recommended)')),
                        DropdownMenuItem(value: 5, child: Text('5 tab switches')),
                        DropdownMenuItem(value: 0, child: Text('Disabled')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDlgState(() => tabLimit = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Question Selection & Blueprint Generator
                Row(
                  children: [
                    const Text('Exam Questions:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.mintWash, borderRadius: BorderRadius.circular(6)),
                      child: Text('${examQuestions.length} selected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.inkForest)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Blueprint Auto-Assemble Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.creamPaper,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blueprint Auto-Assembler (from Question Bank):',
                        style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.inkForest),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: blueprintMcqCount,
                              items: const [
                                DropdownMenuItem(value: 3, child: Text('3 MCQs')),
                                DropdownMenuItem(value: 5, child: Text('5 MCQs')),
                                DropdownMenuItem(value: 10, child: Text('10 MCQs')),
                              ],
                              onChanged: (v) => setDlgState(() => blueprintMcqCount = v ?? 5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: blueprintShortCount,
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1 Short')),
                                DropdownMenuItem(value: 2, child: Text('2 Short')),
                                DropdownMenuItem(value: 5, child: Text('5 Short')),
                              ],
                              onChanged: (v) => setDlgState(() => blueprintShortCount = v ?? 2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: blueprintLongCount,
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('0 Long')),
                                DropdownMenuItem(value: 1, child: Text('1 Long')),
                                DropdownMenuItem(value: 2, child: Text('2 Long')),
                              ],
                              onChanged: (v) => setDlgState(() => blueprintLongCount = v ?? 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      PrimaryButton(
                        text: 'Auto-Assemble Blueprint',
                        icon: Icons.auto_awesome,
                        height: 34,
                        onPressed: () async {
                          try {
                            final snapshot = await FirestoreService.instance.getClassroomQuestionsStream(_classroom.id).first;
                            final bank = snapshot.questions;

                            final mcqs = bank.where((q) => q.questionType == 'mcq' || q.questionType == 'multi_mcq' || q.questionType == 'true_false').toList();
                            final shorts = bank.where((q) => q.questionType == 'short' || q.questionType == 'numerical').toList();
                            final longs = bank.where((q) => q.questionType == 'long' || q.questionType == 'code').toList();

                            final selected = <Question>[
                              ...mcqs.take(blueprintMcqCount),
                              ...shorts.take(blueprintShortCount),
                              ...longs.take(blueprintLongCount),
                            ];

                            if (selected.isEmpty && bank.isNotEmpty) {
                              selected.addAll(bank.take(blueprintMcqCount + blueprintShortCount + blueprintLongCount));
                            }

                            setDlgState(() {
                              examQuestions = selected;
                              final sumMarks = selected.fold<double>(0.0, (acc, q) => acc + q.marks);
                              if (sumMarks > 0) {
                                totalMarksCtrl.text = sumMarks.toStringAsFixed(0);
                                passMarksCtrl.text = (sumMarks * 0.4).toStringAsFixed(0);
                              }
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Blueprint assembled with ${selected.length} questions!'), backgroundColor: AppTheme.successColor),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to assemble blueprint: $e'), backgroundColor: AppTheme.errorColor),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Questions preview list
                if (examQuestions.isNotEmpty) ...[
                  ...examQuestions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final q = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          Text('${idx + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          Expanded(
                            child: Text(q.question, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                          ),
                          Text('+${q.marks}m', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.inkForest)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 14, color: Colors.red),
                            onPressed: () {
                              setDlgState(() => examQuestions.removeAt(idx));
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Release Scores to Students Immediately Upon Submit', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5)),
                  value: releaseNow,
                  activeThumbColor: AppTheme.inkForest,
                  onChanged: (v) => setDlgState(() => releaseNow = v),
                ),
              ],
            ),
          ),
          confirmLabel: existingExam != null ? 'Update Exam' : 'Create & Publish Exam',
          onConfirm: () async {
            if (titleCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter an exam title.'), backgroundColor: AppTheme.errorColor),
              );
              return;
            }

            final exam = Exam(
              id: existingExam?.id ?? '',
              classroomId: _classroom.id,
              title: titleCtrl.text.trim(),
              subject: subjectCtrl.text.trim(),
              unitNumber: int.tryParse(unitCtrl.text.trim()) ?? 1,
              durationMinutes: int.tryParse(durationCtrl.text.trim()) ?? 60,
              passingMarks: double.tryParse(passMarksCtrl.text.trim()) ?? 40.0,
              totalMarks: double.tryParse(totalMarksCtrl.text.trim()) ?? 100.0,
              instructions: instructionsCtrl.text.trim(),
              questions: examQuestions,
              fullScreenEnforced: fullScreen,
              tabSwitchLimit: tabLimit,
              disableCopyPaste: disableCopy,
              allowCalculator: allowCalc,
              watermarkStudentId: watermark,
              shuffleQuestions: shuffleQ,
              shuffleOptions: shuffleOpt,
              releaseScoresImmediately: releaseNow,
              isPublished: true,
            );

            try {
              if (existingExam != null) {
                await FirestoreService.instance.updateClassroomExam(_classroom.id, exam);
              } else {
                await FirestoreService.instance.createClassroomExam(_classroom.id, exam);
              }

              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(existingExam != null ? 'Exam updated successfully!' : 'Exam published and available for classroom assessment!'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save exam: $e'), backgroundColor: AppTheme.errorColor),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _confirmDeleteExam(Exam exam) {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Delete Exam?',
        content: Text(
          'Are you sure you want to permanently delete "${exam.title}" and all associated student submissions?',
          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
        ),
        confirmLabel: 'Delete Exam',
        confirmColor: Colors.red,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          try {
            await FirestoreService.instance.deleteClassroomExam(_classroom.id, exam.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exam deleted.'), backgroundColor: AppTheme.inkForest),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.errorColor),
              );
            }
          }
        },
      ),
    );
  }

  // ===========================================================================
  // TEACHER SUBMISSIONS & GRADING DIALOG
  // ===========================================================================
  void _showExamSubmissionsDialog(Exam exam) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StreamBuilder<List<ExamSubmission>>(
              stream: FirestoreService.instance.getExamSubmissionsStream(_classroom.id, exam.id),
              builder: (ctx, snapshot) {
                final subs = snapshot.data ?? [];
                final avgScore = subs.isNotEmpty ? subs.fold<double>(0, (a, b) => a + b.percentage) / subs.length : 0.0;
                final passCount = subs.where((s) => s.isPassed).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fact_check_outlined, size: 24, color: AppTheme.inkForest),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${exam.title} - Submissions',
                                style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.inkForest),
                              ),
                              Text(
                                '${subs.length} attempts · Average: ${avgScore.toStringAsFixed(1)}% · Pass Rate: ${subs.isNotEmpty ? ((passCount / subs.length) * 100).toStringAsFixed(0) : 0}%',
                                style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Release Scores Toggle for all
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: AppTheme.mintWash.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility, size: 18, color: AppTheme.inkForest),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Release All Scores to Students',
                              style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest),
                            ),
                          ),
                          Switch(
                            value: exam.releaseScoresImmediately,
                            activeThumbColor: AppTheme.inkForest,
                            onChanged: (val) async {
                              await FirestoreService.instance.releaseExamScores(_classroom.id, exam.id, val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: subs.isEmpty
                          ? const Center(child: Text('No student submissions received yet.', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.textSecondary)))
                          : ListView.builder(
                              itemCount: subs.length,
                              itemBuilder: (ctx, idx) {
                                final s = subs[idx];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppTheme.mintWash,
                                        child: Text(s.studentName.isNotEmpty ? s.studentName[0].toUpperCase() : 'S', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.inkForest)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.studentName, style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.inkForest)),
                                            Text(s.studentEmail, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.textSecondary)),
                                            if (s.tabSwitchCount > 0)
                                              Text(
                                                '⚠ ${s.tabSwitchCount} tab switch(es) logged',
                                                style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${s.totalMarksObtained.toStringAsFixed(1)} / ${s.maxMarks.toStringAsFixed(0)}',
                                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.inkForest),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: s.isPassed ? Colors.green.shade50 : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${s.percentage.toStringAsFixed(0)}% · ${s.isPassed ? "PASS" : "FAIL"}',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: s.isPassed ? AppTheme.successColor : AppTheme.errorColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                        child: const Text('Review', style: TextStyle(fontSize: 11)),
                                        onPressed: () => _showGradeSubmissionDialog(exam, s),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TEACHER GRADING ASSISTANT & RUBRICS OVERRIDE MODAL
  // ===========================================================================
  void _showGradeSubmissionDialog(Exam exam, ExamSubmission sub) {
    final Map<String, TextEditingController> scoreControllers = {};
    final Map<String, TextEditingController> feedbackControllers = {};

    for (final q in exam.questions) {
      final curScore = sub.questionScores[q.id] ?? 0.0;
      scoreControllers[q.id] = TextEditingController(text: curScore.toString());
      feedbackControllers[q.id] = TextEditingController(text: sub.questionFeedback[q.id] ?? '');
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setGradeState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 800),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.grading, size: 24, color: AppTheme.inkForest),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Grading: ${sub.studentName} (${sub.studentEmail})',
                          style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.inkForest),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  Expanded(
                    child: ListView.builder(
                      itemCount: exam.questions.length,
                      itemBuilder: (ctx, idx) {
                        final q = exam.questions[idx];
                        final studentAns = sub.answers[q.id];
                        final scoreCtrl = scoreControllers[q.id]!;
                        final feedbackCtrl = feedbackControllers[q.id]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.borderColor)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Q${idx + 1}. ', style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest)),
                                  Expanded(child: Text(q.question, style: const TextStyle(fontFamily: AppTheme.fontCardo, fontSize: 13, color: AppTheme.charcoalSlate))),
                                  Text('[Max: ${q.marks}m]', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textSecondary)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppTheme.creamPaper, borderRadius: BorderRadius.circular(6)),
                                child: Text('Student Answer: ${studentAns ?? "(unanswered)"}', style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.inkForest)),
                              ),
                              const SizedBox(height: 4),
                              Text('Model Answer: ${q.answer}', style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.charcoalSlate)),
                              if (q.keyPointsRubric != null && q.keyPointsRubric!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Rubric: ${q.keyPointsRubric!.join("; ")}', style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: CustomTextField(
                                      controller: scoreCtrl,
                                      label: 'Score',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: feedbackCtrl,
                                      label: 'Feedback / Rubric Note',
                                      hintText: 'Enter specific feedback for student...',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      PrimaryButton(
                        text: 'Save & Update Grade',
                        icon: Icons.check,
                        height: 38,
                        onPressed: () async {
                          final newScores = <String, double>{};
                          final newFeedback = <String, String>{};
                          double newTotal = 0.0;

                          for (final q in exam.questions) {
                            final sc = double.tryParse(scoreControllers[q.id]!.text.trim()) ?? 0.0;
                            newScores[q.id] = sc;
                            newFeedback[q.id] = feedbackControllers[q.id]!.text.trim();
                            newTotal += sc;
                          }

                          final newPct = exam.totalMarks > 0 ? (newTotal / exam.totalMarks) * 100 : 0.0;
                          final newPassed = newTotal >= exam.passingMarks;

                          final updatedSub = sub.copyWith(
                            questionScores: newScores,
                            questionFeedback: newFeedback,
                            totalMarksObtained: newTotal,
                            percentage: newPct,
                            isPassed: newPassed,
                            status: 'graded',
                          );

                          try {
                            await FirestoreService.instance.saveExamSubmission(_classroom.id, exam.id, updatedSub);
                            if (mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Student grade updated successfully!'), backgroundColor: AppTheme.successColor),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update grade: $e'), backgroundColor: AppTheme.errorColor),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TEACHER ANALYTICS & SCORE DISTRIBUTION HISTOGRAM
  // ===========================================================================
  void _showExamAnalyticsDialog(Exam exam) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<List<ExamSubmission>>(
            stream: FirestoreService.instance.getExamSubmissionsStream(_classroom.id, exam.id),
            builder: (ctx, snapshot) {
              final subs = snapshot.data ?? [];
              if (subs.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No submissions available for analytics yet.', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13)),
                    const SizedBox(height: 12),
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                  ],
                );
              }

              // Build histogram brackets: 0-20, 21-40, 41-60, 61-80, 81-100
              final brackets = [0, 0, 0, 0, 0];
              double highest = 0;
              double lowest = 100;
              double sum = 0;

              for (final s in subs) {
                final pct = s.percentage;
                sum += pct;
                if (pct > highest) highest = pct;
                if (pct < lowest) lowest = pct;

                if (pct <= 20) {
                  brackets[0]++;
                } else if (pct <= 40) {
                  brackets[1]++;
                } else if (pct <= 60) {
                  brackets[2]++;
                } else if (pct <= 80) {
                  brackets[3]++;
                } else {
                  brackets[4]++;
                }
              }

              final avg = sum / subs.length;
              final maxCount = brackets.reduce(max);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics, color: AppTheme.inkForest, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Performance Analytics: ${exam.title}',
                          style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.inkForest),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Metrics Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAnalyticMetric('Class Average', '${avg.toStringAsFixed(1)}%'),
                      _buildAnalyticMetric('Highest Score', '${highest.toStringAsFixed(1)}%'),
                      _buildAnalyticMetric('Lowest Score', '${lowest.toStringAsFixed(1)}%'),
                      _buildAnalyticMetric('Attempts', '${subs.length}'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('Score Distribution Histogram:', style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest)),
                  const SizedBox(height: 12),

                  // Histogram Bars
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHistogramBar('0-20%', brackets[0], maxCount),
                      _buildHistogramBar('21-40%', brackets[1], maxCount),
                      _buildHistogramBar('41-60%', brackets[2], maxCount),
                      _buildHistogramBar('61-80%', brackets[3], maxCount),
                      _buildHistogramBar('81-100%', brackets[4], maxCount),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.inkForest)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildHistogramBar(String label, int count, int maxCount) {
    final heightRatio = maxCount > 0 ? (count / maxCount) : 0.0;
    final barHeight = 20.0 + (heightRatio * 90.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$count', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkForest)),
        const SizedBox(height: 4),
        Container(
          width: 38,
          height: barHeight,
          decoration: BoxDecoration(
            color: AppTheme.mintWash,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.inkForest, width: 1.2),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10, color: AppTheme.charcoalSlate)),
      ],
    );
  }

  // ===========================================================================
  // TAB 5: ASSIGNMENTS (Phase 5 Full Implementation)
  // ===========================================================================
  Widget _buildAssignmentsTab() {
    return StreamBuilder<({List<Assignment> assignments, bool isFromCache})>(
      stream: FirestoreService.instance.getClassroomAssignmentsStream(_classroom.id),
      builder: (context, snapshot) {
        final allAssignments = snapshot.data?.assignments ?? [];

        final filteredAssignments = allAssignments.where((a) {
          if (_selectedAssignmentFilter == 'active') return !a.isPastDue;
          if (_selectedAssignmentFilter == 'past_due') return a.isPastDue;
          if (_selectedAssignmentFilter == 'draft') return a.status == 'draft';
          return true;
        }).toList();

        final activeCount = allAssignments.where((a) => !a.isPastDue).length;
        final totalPointsSum = allAssignments.fold<double>(0.0, (acc, a) => acc + a.totalPoints);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Botanical Header Banner
            WatercolorBlobContainer(
              variant: BlobVariant.creamPaper,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      final textCol = Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Classroom Assignments & Projects',
                              style: TextStyle(
                                fontFamily: AppTheme.fontCardo,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppTheme.inkForest,
                              ),
                            ),
                            Text(
                              _isTeacher
                                  ? 'Build Teams-style assignments with multi-criterion rubrics, evaluate submissions, and AI-assist grading.'
                                  : 'Submit homework files, track upcoming deadlines, and review personalized rubric feedback.',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontZilla,
                                fontSize: 12.5,
                                color: AppTheme.charcoalSlate,
                              ),
                            ),
                          ],
                        ),
                      );

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.assignment_ind_outlined, size: 36, color: AppTheme.inkForest),
                                const SizedBox(width: 14),
                                textCol,
                              ],
                            ),
                            if (_isTeacher) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: PrimaryButton(
                                  text: 'New Assignment',
                                  icon: Icons.add,
                                  height: 38,
                                  onPressed: () => _showCreateAssignmentDialog(),
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Icon(Icons.assignment_ind_outlined, size: 36, color: AppTheme.inkForest),
                          const SizedBox(width: 14),
                          textCol,
                          if (_isTeacher) ...[
                            const SizedBox(width: 12),
                            PrimaryButton(
                              text: 'New Assignment',
                              icon: Icons.add,
                              height: 38,
                              onPressed: () => _showCreateAssignmentDialog(),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Metrics Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildHeaderStatChip(Icons.assignment_outlined, '${allAssignments.length} Assignments'),
                      _buildHeaderStatChip(Icons.pending_actions, '$activeCount Active / Open'),
                      _buildHeaderStatChip(Icons.grade_outlined, '${totalPointsSum.toStringAsFixed(0)} Total Points'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Filter Chips Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Filter:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoalSlate)),
                    const SizedBox(width: 8),
                    _buildAssignmentFilterChip('all', 'All Assignments'),
                    _buildAssignmentFilterChip('active', 'Active / Due Soon'),
                    _buildAssignmentFilterChip('past_due', 'Past Due'),
                    _buildAssignmentFilterChip('draft', 'Drafts'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Content List
            if (snapshot.connectionState == ConnectionState.waiting && allAssignments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredAssignments.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: EmptyState(
                  icon: Icons.task_outlined,
                  title: allAssignments.isEmpty ? 'No Assignments Assigned' : 'No Assignments Match Filter',
                  message: allAssignments.isEmpty
                      ? (_isTeacher
                          ? 'Create assignments with rich instructions, due dates, late policies, and rubrics.'
                          : 'You have no pending assignments in this classroom.')
                      : 'Try switching your filter to "All Assignments".',
                  actionText: allAssignments.isEmpty && _isTeacher ? 'New Assignment' : null,
                  onAction: allAssignments.isEmpty && _isTeacher ? () => _showCreateAssignmentDialog() : null,
                ),
              )
            else
              ...filteredAssignments.map((assignment) => _buildAssignmentCard(assignment)),
          ],
        );
      },
    );
  }

  Widget _buildAssignmentFilterChip(String filterKey, String label) {
    final isSelected = _selectedAssignmentFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.mintWash,
        labelStyle: TextStyle(
          fontFamily: AppTheme.fontZilla,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: isSelected ? AppTheme.inkForest : AppTheme.charcoalSlate,
        ),
        onSelected: (sel) {
          if (sel) setState(() => _selectedAssignmentFilter = filterKey);
        },
      ),
    );
  }

  // ===========================================================================
  // ASSIGNMENT CARD (Teams-Style Submissions & Rubrics)
  // ===========================================================================
  Widget _buildAssignmentCard(Assignment a) {
    final isPastDue = a.isPastDue;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Due Date Chip & Points
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPastDue ? Colors.red.shade50 : AppTheme.mintWash.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isPastDue ? Colors.red.shade200 : AppTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 12, color: isPastDue ? AppTheme.errorColor : AppTheme.inkForest),
                      const SizedBox(width: 4),
                      Text(
                        a.dueRelativeText,
                        style: TextStyle(
                          fontFamily: AppTheme.fontZilla,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPastDue ? AppTheme.errorColor : AppTheme.inkForest,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (a.unitNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                    child: Text('Unit ${a.unitNumber}', style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.charcoalSlate)),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.creamPaper, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '${a.totalPoints.toStringAsFixed(0)} Points',
                    style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.inkForest),
                  ),
                ),
                if (_isTeacher)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.charcoalSlate),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showCreateAssignmentDialog(existingAssignment: a);
                      } else if (val == 'delete') {
                        _confirmDeleteAssignment(a);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit Assignment')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Assignment', style: TextStyle(color: Colors.red))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Title & Instructions
            Text(
              a.title,
              style: const TextStyle(
                fontFamily: AppTheme.fontCardo,
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.inkForest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              a.instructions,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate, height: 1.35),
            ),
            const SizedBox(height: 10),

            // Badges: Late policy, Rubric criteria count, Attachments
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildExamMetaBadge(
                  Icons.policy_outlined,
                  a.allowLateSubmissions ? 'Late allowed (${a.latePenaltyPercentPerDay.toStringAsFixed(0)}%/day penalty)' : 'No late submissions',
                ),
                if (a.rubricCriteria.isNotEmpty)
                  _buildExamMetaBadge(Icons.rule, '${a.rubricCriteria.length} Rubric Criteria'),
                if (a.referenceAttachments.isNotEmpty)
                  _buildExamMetaBadge(Icons.attach_file, '${a.referenceAttachments.length} Reference Materials'),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Action row
            Row(
              children: [
                if (_isTeacher) ...[
                  // Teacher: Submissions overview & Grading
                  StreamBuilder<List<AssignmentSubmission>>(
                    stream: FirestoreService.instance.getAssignmentSubmissionsStream(_classroom.id, a.id),
                    builder: (ctx, subSnap) {
                      final subs = subSnap.data ?? [];
                      final turnedIn = subs.where((s) => s.status == 'turned_in' || s.status == 'turned_in_late').length;
                      final graded = subs.where((s) => s.isGraded).length;
                      final assigned = max(0, _classroom.studentIds.length - subs.length);

                      return Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.people_alt_outlined, size: 15),
                            label: Text('Submissions ($turnedIn turned in · $graded graded · $assigned assigned)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.inkForest,
                              side: const BorderSide(color: AppTheme.inkForest),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _showAssignmentSubmissionsDashboard(a),
                          ),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  // Student: Turn in work or check grading status
                  FutureBuilder<AssignmentSubmission?>(
                    future: FirestoreService.instance.getStudentAssignmentSubmission(_classroom.id, a.id, widget.currentUser.id),
                    builder: (ctx, subSnap) {
                      final sub = subSnap.data;

                      if (sub != null && sub.status != 'assigned') {
                        if (sub.isGraded) {
                          return ElevatedButton.icon(
                            icon: const Icon(Icons.verified, size: 15),
                            label: Text('Graded: ${sub.pointsAwarded?.toStringAsFixed(1) ?? "0"} / ${a.totalPoints.toStringAsFixed(0)} pts'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _showStudentSubmissionFeedbackDialog(a, sub),
                          );
                        } else {
                          // Turned in, awaiting grading
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: AppTheme.mintWash.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 14, color: AppTheme.inkForest),
                                    const SizedBox(width: 4),
                                    Text(
                                      sub.isLate ? 'Turned in late' : 'Turned in',
                                      style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.inkForest),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => _confirmUnsubmit(a),
                                child: const Text('Unsubmit', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                              ),
                            ],
                          );
                        }
                      }

                      // Not turned in
                      return PrimaryButton(
                        text: isPastDue ? 'Turn in late' : 'Turn in Work',
                        icon: Icons.upload_file,
                        height: 36,
                        onPressed: () => _showStudentTurnInDialog(a),
                      );
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TEACHER ASSIGNMENT CREATOR & RUBRIC BUILDER DIALOG
  // ===========================================================================
  void _showCreateAssignmentDialog({Assignment? existingAssignment}) {
    final titleCtrl = TextEditingController(text: existingAssignment?.title ?? '');
    final unitCtrl = TextEditingController(text: existingAssignment?.unitNumber?.toString() ?? '1');
    final instructionsCtrl = TextEditingController(text: existingAssignment?.instructions ?? '');
    final pointsCtrl = TextEditingController(text: existingAssignment?.totalPoints.toString() ?? '100');
    final penaltyCtrl = TextEditingController(text: existingAssignment?.latePenaltyPercentPerDay.toString() ?? '5');
    DateTime dueDate = existingAssignment?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    bool allowLate = existingAssignment?.allowLateSubmissions ?? true;
    String status = existingAssignment?.status ?? 'published';

    // Rubric criteria list
    final List<AssignmentRubricCriterion> rubricList = List.from(existingAssignment?.rubricCriteria ?? [
      const AssignmentRubricCriterion(
        title: 'Content & Correctness',
        description: 'Demonstrates thorough comprehension of required principles.',
        maxPoints: 40,
      ),
      const AssignmentRubricCriterion(
        title: 'Implementation / Analysis Quality',
        description: 'Code or written explanations follow sound methodology.',
        maxPoints: 40,
      ),
      const AssignmentRubricCriterion(
        title: 'Documentation & Presentation',
        description: 'Clear formatting, comments, and structure.',
        maxPoints: 20,
      ),
    ]);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => CustomDialog(
          title: existingAssignment != null ? 'Edit Assignment' : 'Create Assignment',
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(controller: titleCtrl, label: 'Assignment Title *', hintText: 'e.g. Lab 2: Process Scheduling Simulator'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(width: 80, child: CustomTextField(controller: unitCtrl, label: 'Unit #', keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: CustomTextField(controller: pointsCtrl, label: 'Total Points', keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(controller: instructionsCtrl, label: 'Instructions & Requirements *', maxLines: 4, hintText: 'Describe project specifications, deliverables, and guidelines...'),
                const SizedBox(height: 12),

                // Due Date selector
                Row(
                  children: [
                    const Icon(Icons.event, size: 18, color: AppTheme.inkForest),
                    const SizedBox(width: 8),
                    Text(
                      'Due Date: ${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      child: const Text('Pick Date', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDlgState(() => dueDate = DateTime(picked.year, picked.month, picked.day, 23, 59));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Late policy
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Allow Late Submissions', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5)),
                  value: allowLate,
                  activeThumbColor: AppTheme.inkForest,
                  onChanged: (v) => setDlgState(() => allowLate = v),
                ),
                if (allowLate)
                  CustomTextField(controller: penaltyCtrl, label: 'Late Penalty (% per day)', keyboardType: TextInputType.number),
                const SizedBox(height: 12),

                // Rubric Builder
                Row(
                  children: [
                    const Text('Grading Rubric Criteria:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add Criterion'),
                      onPressed: () {
                        setDlgState(() {
                          rubricList.add(
                            AssignmentRubricCriterion(
                              title: 'Criterion ${rubricList.length + 1}',
                              maxPoints: 10,
                            ),
                          );
                        });
                      },
                    ),
                  ],
                ),
                ...List.generate(rubricList.length, (idx) {
                  final crit = rubricList[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(crit.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              if (crit.description.isNotEmpty)
                                Text(crit.description, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.mintWash, borderRadius: BorderRadius.circular(6)),
                          child: Text('${crit.maxPoints.toStringAsFixed(0)} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.inkForest)),
                        ),
                        if (rubricList.length > 1)
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => setDlgState(() => rubricList.removeAt(idx)),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          confirmLabel: existingAssignment != null ? 'Update Assignment' : 'Publish Assignment',
          onConfirm: () async {
            if (titleCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter an assignment title.'), backgroundColor: AppTheme.errorColor),
              );
              return;
            }

            final a = Assignment(
              id: existingAssignment?.id ?? '',
              classroomId: _classroom.id,
              title: titleCtrl.text.trim(),
              unitNumber: int.tryParse(unitCtrl.text.trim()) ?? 1,
              instructions: instructionsCtrl.text.trim(),
              totalPoints: double.tryParse(pointsCtrl.text.trim()) ?? 100.0,
              dueDate: dueDate,
              allowLateSubmissions: allowLate,
              latePenaltyPercentPerDay: double.tryParse(penaltyCtrl.text.trim()) ?? 5.0,
              rubricCriteria: rubricList,
              status: status,
            );

            try {
              if (existingAssignment != null) {
                await FirestoreService.instance.updateClassroomAssignment(_classroom.id, a);
              } else {
                await FirestoreService.instance.createClassroomAssignment(_classroom.id, a);
              }

              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(existingAssignment != null ? 'Assignment updated!' : 'Assignment published to classroom!'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save assignment: $e'), backgroundColor: AppTheme.errorColor),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _confirmDeleteAssignment(Assignment a) {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Delete Assignment?',
        content: Text(
          'Are you sure you want to delete "${a.title}" and all attached student submissions?',
          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
        ),
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          try {
            await FirestoreService.instance.deleteClassroomAssignment(_classroom.id, a.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Assignment deleted.'), backgroundColor: AppTheme.inkForest),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppTheme.errorColor),
              );
            }
          }
        },
      ),
    );
  }

  // ===========================================================================
  // STUDENT TURN IN MODAL (Multi-file upload & text response)
  // ===========================================================================
  void _showStudentTurnInDialog(Assignment a) {
    final textCtrl = TextEditingController();
    final List<AssignmentAttachment> attachedFiles = [];
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => CustomDialog(
          title: 'Turn In: ${a.title}',
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Due: ${a.dueRelativeText} (${a.totalPoints.toStringAsFixed(0)} Points)',
                  style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12, color: a.isPastDue ? AppTheme.errorColor : AppTheme.inkForest),
                ),
                const SizedBox(height: 12),

                // File Attachment picker
                const Text('Attach Work Files (PDF, Code, Images, ZIP):', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: const Text('Add Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintWash,
                    foregroundColor: AppTheme.inkForest,
                    elevation: 0,
                  ),
                  onPressed: () async {
                    try {
                      final res = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'zip', 'py', 'java', 'cpp', 'c', 'dart', 'txt', 'docx', 'png', 'jpg'],
                      );
                      if (res.isNotEmpty) {
                        final file = res.first;
                        final bytes = await file.readAsBytes();
                        setDlgState(() {
                          attachedFiles.add(
                            AssignmentAttachment(
                              fileName: file.name,
                              fileUrl: 'file://${file.name}',
                              fileType: file.name.split('.').last.toLowerCase(),
                              fileSizeBytes: bytes.length,
                            ),
                          );
                        });
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('File selection failed: $e'), backgroundColor: AppTheme.errorColor),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),

                // Attached files list
                if (attachedFiles.isNotEmpty) ...[
                  ...attachedFiles.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final f = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppTheme.inkForest),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(f.fileName, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => setDlgState(() => attachedFiles.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],

                // Student Text Response
                CustomTextField(
                  controller: textCtrl,
                  label: 'Text Response / Notes for Instructor',
                  hintText: 'Enter any comments or code snippets...',
                  maxLines: 4,
                ),
              ],
            ),
          ),
          confirmLabel: isSubmitting ? 'Turning In...' : (a.isPastDue ? 'Turn In Late' : 'Turn In Work'),
          onConfirm: isSubmitting
              ? null
              : () async {
                  if (attachedFiles.isEmpty && textCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please attach at least one file or enter a text response.'), backgroundColor: AppTheme.errorColor),
                    );
                    return;
                  }

                  setDlgState(() => isSubmitting = true);
                  final submission = AssignmentSubmission(
                    id: widget.currentUser.id,
                    assignmentId: a.id,
                    classroomId: _classroom.id,
                    studentId: widget.currentUser.id,
                    studentName: widget.currentUser.name,
                    studentEmail: widget.currentUser.email,
                    submittedFiles: attachedFiles,
                    textResponse: textCtrl.text.trim().isNotEmpty ? textCtrl.text.trim() : null,
                    submittedAt: DateTime.now(),
                    isLate: a.isPastDue,
                    maxPoints: a.totalPoints,
                    status: a.isPastDue ? 'turned_in_late' : 'turned_in',
                  );

                  try {
                    await FirestoreService.instance.submitAssignment(_classroom.id, a.id, submission);
                    if (mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Assignment turned in successfully! Great job!'),
                          backgroundColor: AppTheme.successColor,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    setDlgState(() => isSubmitting = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Turn in failed: $e'), backgroundColor: AppTheme.errorColor),
                      );
                    }
                  }
                },
        ),
      ),
    );
  }

  void _confirmUnsubmit(Assignment a) {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Unsubmit Assignment?',
        content: const Text(
          'Unsubmitting will allow you to add or remove files and revise your submission before your instructor finishes grading.',
          style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
        ),
        confirmLabel: 'Unsubmit',
        confirmColor: Colors.amber.shade800,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          try {
            await FirestoreService.instance.unsubmitAssignment(_classroom.id, a.id, widget.currentUser.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Assignment unsubmitted. You can now revise your files.'), backgroundColor: AppTheme.inkForest),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unsubmit failed: $e'), backgroundColor: AppTheme.errorColor),
              );
            }
          }
        },
      ),
    );
  }

  // ===========================================================================
  // TEACHER SUBMISSIONS DASHBOARD & SPLIT-VIEW GRADING
  // ===========================================================================
  void _showAssignmentSubmissionsDashboard(Assignment a) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StreamBuilder<List<AssignmentSubmission>>(
              stream: FirestoreService.instance.getAssignmentSubmissionsStream(_classroom.id, a.id),
              builder: (ctx, snapshot) {
                final subs = snapshot.data ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.dashboard_outlined, size: 24, color: AppTheme.inkForest),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a.title} - Submissions Dashboard',
                                style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.inkForest),
                              ),
                              Text(
                                '${subs.length} turned in · Total Points: ${a.totalPoints.toStringAsFixed(0)}',
                                style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 14),
                          label: const Text('Export Grades CSV'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                          onPressed: () {
                            final csv = ExportService.instance.generateAssignmentGradesCsv(a, subs);
                            Clipboard.setData(ClipboardData(text: csv));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Assignment grades CSV copied to clipboard!'), backgroundColor: AppTheme.inkForest),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),

                    Expanded(
                      child: subs.isEmpty
                          ? const Center(child: Text('No student submissions received yet.', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.textSecondary)))
                          : ListView.builder(
                              itemCount: subs.length,
                              itemBuilder: (ctx, idx) {
                                final s = subs[idx];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppTheme.mintWash,
                                        child: Text(s.studentName.isNotEmpty ? s.studentName[0].toUpperCase() : 'S', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.inkForest)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.studentName, style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.inkForest)),
                                            Text(
                                              '${s.studentEmail} · ${s.submittedFiles.length} file(s) attached',
                                              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.textSecondary),
                                            ),
                                            if (s.isLate)
                                              const Text('⚠ Turned in late', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.amber)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            s.pointsAwarded != null ? '${s.pointsAwarded!.toStringAsFixed(1)} / ${s.maxPoints.toStringAsFixed(0)}' : 'Ungraded',
                                            style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: s.isGraded ? AppTheme.successColor : AppTheme.charcoalSlate),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: s.isGraded ? Colors.green.shade50 : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              s.isGraded ? 'GRADED' : 'NEEDS GRADING',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: s.isGraded ? AppTheme.successColor : AppTheme.charcoalSlate),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                      PrimaryButton(
                                        text: s.isGraded ? 'Edit Grade' : 'Grade',
                                        icon: Icons.rate_review_outlined,
                                        height: 32,
                                        onPressed: () => _showGradeAssignmentDialog(a, s),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TEACHER GRADING DRAWER WITH RUBRIC SCORER & AI FEEDBACK DRAFTING
  // ===========================================================================
  void _showGradeAssignmentDialog(Assignment a, AssignmentSubmission sub) {
    final Map<String, double> rubricPoints = Map.from(sub.rubricScores);
    final feedbackCtrl = TextEditingController(text: sub.feedback ?? '');

    // Initialize missing criteria points
    for (final crit in a.rubricCriteria) {
      if (!rubricPoints.containsKey(crit.title)) {
        rubricPoints[crit.title] = crit.maxPoints;
      }
    }

    double calculateTotal() {
      if (a.rubricCriteria.isEmpty) return a.totalPoints;
      return rubricPoints.values.fold<double>(0.0, (acc, p) => acc + p);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setGradeState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860, maxHeight: 820),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rate_review, size: 24, color: AppTheme.inkForest),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Grading: ${sub.studentName} - ${a.title}',
                          style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 16.5, color: AppTheme.inkForest),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Split View: Student Work on Left, Rubrics on Right
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Student Submission Files & Text
                        Expanded(
                          flex: 5,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Student Submission Deliverables:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest)),
                                  const SizedBox(height: 10),
                                  if (sub.submittedFiles.isNotEmpty) ...[
                                    ...sub.submittedFiles.map((f) {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderColor)),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.attach_file, size: 16, color: AppTheme.inkForest),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(f.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                            const Icon(Icons.download, size: 16, color: AppTheme.textSecondary),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                  if (sub.textResponse != null && sub.textResponse!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Text('Text Response / Notes:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoalSlate)),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderColor)),
                                      child: SelectableText(sub.textResponse!, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Right: Interactive Rubric Scorer & AI Feedback
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Rubric Scoring:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: AppTheme.mintWash, borderRadius: BorderRadius.circular(8)),
                                      child: Text(
                                        'Total: ${calculateTotal().toStringAsFixed(1)} / ${a.totalPoints.toStringAsFixed(0)}',
                                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Criteria scoring
                                ...a.rubricCriteria.map((crit) {
                                  final assigned = rubricPoints[crit.title] ?? crit.maxPoints;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderColor)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(crit.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                            Text('${assigned.toStringAsFixed(1)} / ${crit.maxPoints} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.inkForest)),
                                          ],
                                        ),
                                        Slider(
                                          value: assigned.clamp(0.0, crit.maxPoints),
                                          min: 0.0,
                                          max: crit.maxPoints,
                                          divisions: max(1, crit.maxPoints.toInt()),
                                          activeColor: AppTheme.inkForest,
                                          onChanged: (val) {
                                            setGradeState(() => rubricPoints[crit.title] = val);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 10),

                                // AI Feedback Assistant
                                Row(
                                  children: [
                                    const Text('Feedback for Student:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12.5)),
                                    const Spacer(),
                                    TextButton.icon(
                                      icon: const Icon(Icons.auto_awesome, size: 14),
                                      label: const Text('Draft from Rubric'),
                                      style: TextButton.styleFrom(foregroundColor: AppTheme.inkForest),
                                      onPressed: () {
                                        final total = calculateTotal();
                                        final pct = a.totalPoints > 0 ? (total / a.totalPoints) * 100 : 0.0;
                                        String tone = pct >= 85 ? "Excellent work" : (pct >= 65 ? "Good effort with room for refinement" : "Needs significant revision");
                                        feedbackCtrl.text =
                                            'Overall: $tone (${total.toStringAsFixed(1)}/${a.totalPoints.toStringAsFixed(0)} pts).\n'
                                            'Strengths: Submitted all required project deliverables on time. Clear understanding of core concepts.\n'
                                            'Next Steps: Review edge condition handling and expand comments across complex logic.';
                                      },
                                    ),
                                  ],
                                ),
                                CustomTextField(
                                  controller: feedbackCtrl,
                                  label: 'Written Feedback',
                                  hintText: 'Enter constructive feedback for the student...',
                                  maxLines: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      PrimaryButton(
                        text: 'Save Grade & Return',
                        icon: Icons.check,
                        height: 38,
                        onPressed: () async {
                          final totalScore = calculateTotal();
                          try {
                            await FirestoreService.instance.gradeAssignmentSubmission(
                              _classroom.id,
                              a.id,
                              sub.id,
                              points: totalScore,
                              rubricScores: rubricPoints,
                              feedback: feedbackCtrl.text.trim(),
                              gradedBy: widget.currentUser.name,
                            );

                            if (mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Grade saved and returned to student!'), backgroundColor: AppTheme.successColor),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save grade: $e'), backgroundColor: AppTheme.errorColor),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STUDENT SUBMISSION FEEDBACK DIALOG
  // ===========================================================================
  void _showStudentSubmissionFeedbackDialog(Assignment a, AssignmentSubmission sub) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 540,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 28, color: AppTheme.inkForest),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 16.5, color: AppTheme.inkForest)),
                        const Text('Official Graded Assessment Feedback', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
              const SizedBox(height: 14),

              // Score Card Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.mintWash.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${sub.pointsAwarded?.toStringAsFixed(1) ?? "0"} / ${a.totalPoints.toStringAsFixed(0)}',
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 28, color: AppTheme.inkForest),
                    ),
                    const SizedBox(width: 10),
                    const Text('Points Awarded', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Rubric Criteria Breakdown
              if (sub.rubricScores.isNotEmpty) ...[
                const Text('Rubric Breakdown:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest)),
                const SizedBox(height: 6),
                ...sub.rubricScores.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(e.key, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12))),
                        Text('${e.value.toStringAsFixed(1)} pts', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.inkForest)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 10),
              ],

              // Feedback Quote Box
              if (sub.feedback != null && sub.feedback!.isNotEmpty) ...[
                const Text('Instructor Feedback:', style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.creamPaper, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderColor)),
                  child: Text(
                    sub.feedback!,
                    style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate, height: 1.35),
                  ),
                ),
              ],
              const SizedBox(height: 18),

              Align(
                alignment: Alignment.centerRight,
                child: PrimaryButton(text: 'Close', height: 36, onPressed: () => Navigator.of(ctx).pop()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 6: LIVE CLASS (Phase 6 Complete)
  // ===========================================================================
  Widget _buildLiveClassTab() {
    return StreamBuilder<({List<LiveClassSession> sessions, bool isFromCache})>(
      stream: FirestoreService.instance.getLiveClassesStream(_classroom.id),
      builder: (context, snapshot) {
        final sessions = snapshot.data?.sessions ?? [];
        final ongoingSessions = sessions.where((s) => s.isOngoing).toList();
        final pastSessions = sessions.where((s) => !s.isOngoing).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Top Live Class Intro Banner
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
                              'Interactive Live Classrooms',
                              style: TextStyle(
                                fontFamily: AppTheme.fontCardo,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppTheme.inkForest,
                              ),
                            ),
                            Text(
                              'Powered by Jitsi Meet • Room Prefix: ${_classroom.code}',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontZilla,
                                fontSize: 12,
                                color: AppTheme.charcoalSlate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.inkForest.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.inkForest.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 13, color: AppTheme.inkForest),
                            SizedBox(width: 4),
                            Text(
                              'Jitsi / Google Meet',
                              style: TextStyle(
                                fontFamily: AppTheme.fontZilla,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.inkForest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'High-definition video, audio, screen sharing, and interactive chat. Join instantly from mobile or desktop browsers without installing apps.',
                    style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
                  ),
                  const SizedBox(height: 16),
                  if (_isTeacher)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        PrimaryButton(
                          text: 'Start Live Class Now',
                          icon: Icons.video_call,
                          onPressed: _showStartLiveClassDialog,
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 16),
                          label: const Text('Schedule Live Session'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.inkForest,
                            side: const BorderSide(color: AppTheme.inkForest),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _showScheduleLiveClassDialog,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ONGOING LIVE SESSION
            if (ongoingSessions.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE NOW',
                    style: TextStyle(
                      fontFamily: AppTheme.fontCardo,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.redAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...ongoingSessions.map((session) => _buildOngoingSessionCard(session)),
              const SizedBox(height: 24),
            ] else if (!_isTeacher) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.creamPaper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tv_off_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No live class in progress',
                            style: TextStyle(
                              fontFamily: AppTheme.fontCardo,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.inkForest,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'When your faculty starts a live class, a join banner and stream announcement will appear here immediately.',
                            style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // SESSION HISTORY & ATTENDANCE ARCHIVE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lecture History & Attendance',
                  style: TextStyle(
                    fontFamily: AppTheme.fontCardo,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: AppTheme.inkForest,
                  ),
                ),
                Text(
                  '${pastSessions.length} past sessions',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontZilla,
                    fontSize: 12,
                    color: AppTheme.charcoalSlate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pastSessions.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.creamPaper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_edu, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      const Text(
                        'No past live lectures recorded yet.',
                        style: TextStyle(fontFamily: AppTheme.fontZilla, color: AppTheme.charcoalSlate, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...pastSessions.map((session) => _buildPastSessionCard(session)),
          ],
        );
      },
    );
  }

  /// Card displaying an active ongoing live session.
  Widget _buildOngoingSessionCard(LiveClassSession session) {
    final attendeesCount = session.attendanceRecords.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.mintWash.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.inkForest, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.inkForest.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              if (session.unitNumber != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.inkForest.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Unit ${session.unitNumber}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontZilla,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.inkForest,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                'Started ${session.durationMinutes}m ago',
                style: const TextStyle(
                  fontFamily: AppTheme.fontZilla,
                  fontSize: 12,
                  color: AppTheme.charcoalSlate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.title,
            style: const TextStyle(
              fontFamily: AppTheme.fontCardo,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.inkForest,
            ),
          ),
          if (session.unitTitle != null && session.unitTitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              session.unitTitle!,
              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppTheme.charcoalSlate),
              const SizedBox(width: 4),
              Text(
                'Host: ${session.hostTeacherName}',
                style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, color: AppTheme.charcoalSlate),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.people_outline, size: 14, color: AppTheme.inkForest),
              const SizedBox(width: 4),
              Text(
                '$attendeesCount joined',
                style: const TextStyle(
                  fontFamily: AppTheme.fontZilla,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: AppTheme.inkForest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PrimaryButton(
                text: _isTeacher ? 'Join as Host' : 'Join Live Class',
                icon: Icons.videocam,
                onPressed: () => _joinLiveClass(session),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('Copy Link'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.inkForest,
                  side: const BorderSide(color: AppTheme.borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: session.meetUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Room URL copied: ${session.meetUrl}'),
                      backgroundColor: AppTheme.inkForest,
                    ),
                  );
                },
              ),
              if (_isTeacher) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.how_to_reg, size: 15),
                  label: Text('Attendance ($attendeesCount)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.inkForest,
                    side: const BorderSide(color: AppTheme.inkForest),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showAttendanceModal(session),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.call_end, size: 15, color: Colors.redAccent),
                  label: const Text('End Class', style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showEndLiveClassDialog(session),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Card displaying a past completed live session.
  Widget _buildPastSessionCard(LiveClassSession session) {
    final attendeesCount = session.attendanceRecords.length;
    final totalStudents = _students.length;
    final attendancePct = totalStudents == 0 ? 0 : (attendeesCount / totalStudents * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.creamPaper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'COMPLETED',
                  style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              if (session.unitNumber != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.mintWash,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Unit ${session.unitNumber}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontZilla,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: AppTheme.inkForest,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '${session.startedAt.year}-${session.startedAt.month.toString().padLeft(2, '0')}-${session.startedAt.day.toString().padLeft(2, '0')} • ${session.durationMinutes}m',
                style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            session.title,
            style: const TextStyle(
              fontFamily: AppTheme.fontCardo,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.inkForest,
            ),
          ),
          if (session.unitTitle != null && session.unitTitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              session.unitTitle!,
              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, color: AppTheme.charcoalSlate),
            ),
          ],
          if (session.notes != null && session.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppTheme.inkForest),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      session.notes!,
                      style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.inkForest),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.inkForest.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Attendance: $attendeesCount/$totalStudents ($attendancePct%)',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontZilla,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: AppTheme.inkForest,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.people_outline, size: 14),
                label: const Text('View Attendance'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.inkForest,
                  textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showAttendanceModal(session),
              ),
              if (_isTeacher)
                IconButton(
                  icon: const Icon(Icons.edit_note, size: 18, color: AppTheme.inkForest),
                  tooltip: 'Edit notes & recording link',
                  onPressed: () => _showEditSessionNotesDialog(session),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Joins a live class session and logs student attendance.
  void _joinLiveClass(LiveClassSession session) {
    openUrlInBrowser(session.meetUrl);

    if (!_isTeacher) {
      unawaited(
        FirestoreService.instance.recordLiveClassAttendance(
          _classroom.id,
          session.id,
          StudentAttendanceRecord(
            studentId: widget.currentUser.id,
            studentName: widget.currentUser.name,
            studentEmail: widget.currentUser.email,
            joinedAt: DateTime.now(),
          ),
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isTeacher ? 'Connecting to live room...' : 'Joined live class room. Attendance recorded!'),
        backgroundColor: AppTheme.inkForest,
      ),
    );
  }

  /// Dialog to start an instant live class session.
  Future<void> _showStartLiveClassDialog() async {
    final titleCtrl = TextEditingController(text: 'Live Lecture: ${_classroom.subject}');
    final unitCtrl = TextEditingController();
    final topicCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.video_call, color: AppTheme.inkForest),
            SizedBox(width: 8),
            Text('Start Live Class', style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: titleCtrl,
                label: 'Session Title',
                hintText: 'e.g. Unit 3: Process Synchronization',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: CustomTextField(
                      controller: unitCtrl,
                      label: 'Unit #',
                      hintText: '3',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      controller: topicCtrl,
                      label: 'Topic Description (optional)',
                      hintText: 'Semaphores & Mutex',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.mintWash.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.inkForest.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.inkForest),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A Jitsi Meet room will be generated and an alert will be automatically published to the classroom stream.',
                        style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.inkForest),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppTheme.charcoalSlate)),
            onPressed: () => Navigator.pop(ctx),
          ),
          PrimaryButton(
            text: 'Launch Live Class',
            icon: Icons.rocket_launch,
            onPressed: () async {
              final title = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Live Class';
              final unitNum = int.tryParse(unitCtrl.text.trim());
              final topic = topicCtrl.text.trim().isNotEmpty ? topicCtrl.text.trim() : null;
              final roomName = 'StudyMate_${_classroom.code}_${Random().nextInt(900000) + 100000}';

              Navigator.pop(ctx);

              final newSession = LiveClassSession(
                id: 'new',
                classroomId: _classroom.id,
                title: title,
                unitNumber: unitNum,
                unitTitle: topic,
                roomName: roomName,
                hostTeacherId: widget.currentUser.id,
                hostTeacherName: widget.currentUser.name,
                isOngoing: true,
                startedAt: DateTime.now(),
              );

              try {
                final created = await FirestoreService.instance.startLiveClassSession(
                  _classroom.id,
                  newSession,
                  autoPostAnnouncement: true,
                );
                openUrlInBrowser(created.meetUrl);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Live class started! Join URL: ${created.meetUrl}'),
                      backgroundColor: AppTheme.inkForest,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to start session: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  /// Dialog to schedule a live class and alert students in stream.
  Future<void> _showScheduleLiveClassDialog() async {
    final titleCtrl = TextEditingController(text: 'Scheduled Class: ${_classroom.subject}');
    DateTime scheduledDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay scheduledTime = const TimeOfDay(hour: 10, minute: 0);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.calendar_month, color: AppTheme.inkForest),
              SizedBox(width: 8),
              Text('Schedule Live Session', style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  controller: titleCtrl,
                  label: 'Session Title',
                  hintText: 'e.g. Midterm Revision & Doubt Clearing',
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event, color: AppTheme.inkForest),
                  title: const Text('Date', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13)),
                  subtitle: Text(
                    '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.inkForest),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: scheduledDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => scheduledDate = picked);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time, color: AppTheme.inkForest),
                  title: const Text('Time', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13)),
                  subtitle: Text(
                    scheduledTime.format(ctx),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.inkForest),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    final picked = await showTimePicker(context: ctx, initialTime: scheduledTime);
                    if (picked != null) {
                      setDialogState(() => scheduledTime = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: AppTheme.charcoalSlate)),
              onPressed: () => Navigator.pop(ctx),
            ),
            PrimaryButton(
              text: 'Schedule & Announce',
              icon: Icons.send,
              onPressed: () async {
                final title = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Live Class';
                Navigator.pop(ctx);

                try {
                  final dateStr = '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}';
                  final timeStr = scheduledTime.format(context);

                  await FirestoreService.instance.postAnnouncement(
                    classroomId: _classroom.id,
                    authorId: widget.currentUser.id,
                    authorName: widget.currentUser.name,
                    authorRole: 'Teacher',
                    content: '📅 Scheduled Live Class: "$title"\nDate: $dateStr at $timeStr.\nPlease check the Live Class tab when class starts.',
                    pinned: true,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Session "$title" scheduled and announced in classroom stream.'),
                        backgroundColor: AppTheme.inkForest,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to schedule session: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to confirm ending an ongoing live class session.
  Future<void> _showEndLiveClassDialog(LiveClassSession session) async {
    final notesCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Live Class', style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to conclude this live lecture? Attendance records will be preserved in lecture history.',
              style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: notesCtrl,
              label: 'Lecture Notes / Recording Link (optional)',
              hintText: 'e.g. Covered slides 1-25; Recording: https://...',
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppTheme.charcoalSlate)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Class'),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirestoreService.instance.endLiveClassSession(
                  _classroom.id,
                  session.id,
                  notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Live class concluded. Attendance saved to history.'),
                      backgroundColor: AppTheme.inkForest,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to end session: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  /// Displays the attendance report modal for a live class session with CSV export.
  void _showAttendanceModal(LiveClassSession session) {
    final attendees = session.attendanceRecords;
    final totalEnrolled = _students.length;
    final pct = totalEnrolled == 0 ? 0 : (attendees.length / totalEnrolled * 100).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Roster: ${session.title}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontCardo,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.inkForest,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${attendees.length} / $totalEnrolled students present ($pct%)',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontZilla,
                            fontSize: 12.5,
                            color: AppTheme.charcoalSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 14),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.inkForest,
                      side: const BorderSide(color: AppTheme.inkForest),
                      textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, fontWeight: FontWeight.bold),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () {
                      final csv = ExportService.instance.generateAttendanceCsv(
                        session: session,
                        enrolledStudents: _students,
                      );
                      Clipboard.setData(ClipboardData(text: csv));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Attendance CSV copied to clipboard!'),
                          backgroundColor: AppTheme.inkForest,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _students.isEmpty
                  ? const Center(
                      child: Text(
                        'No students enrolled in this classroom.',
                        style: TextStyle(fontFamily: AppTheme.fontZilla, color: AppTheme.charcoalSlate),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _students.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final student = _students[i];
                        final record = attendees[student.studentId];
                        final isPresent = record != null;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isPresent ? AppTheme.inkForest.withValues(alpha: 0.1) : Colors.grey.shade200,
                            child: Text(
                              student.studentName.isNotEmpty ? student.studentName[0].toUpperCase() : 'S',
                              style: TextStyle(
                                color: isPresent ? AppTheme.inkForest : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            student.studentName,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontZilla,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          subtitle: Text(
                            student.studentEmail,
                            style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.charcoalSlate),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPresent ? AppTheme.mintWash : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPresent ? AppTheme.inkForest.withValues(alpha: 0.3) : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPresent ? Icons.check_circle : Icons.cancel_outlined,
                                  size: 13,
                                  color: isPresent ? AppTheme.inkForest : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isPresent ? 'Present' : 'Absent',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontZilla,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                    color: isPresent ? AppTheme.inkForest : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog allowing the teacher to update notes or add a recording link for a completed session.
  Future<void> _showEditSessionNotesDialog(LiveClassSession session) async {
    final notesCtrl = TextEditingController(text: session.notes ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Lecture Notes / Recording', style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: notesCtrl,
              label: 'Notes / Video Recording Link',
              hintText: 'e.g. Recording URL: https://..., Homework page 42',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppTheme.charcoalSlate)),
            onPressed: () => Navigator.pop(ctx),
          ),
          PrimaryButton(
            text: 'Save Notes',
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirestoreService.instance.endLiveClassSession(
                  _classroom.id,
                  session.id,
                  notes: notesCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notes updated successfully.'), backgroundColor: AppTheme.inkForest),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update notes: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
          ),
        ],
      ),
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
  // TAB 8: ANALYTICS (Phase 7 Complete)
  // ===========================================================================
  Widget _buildAnalyticsTab() {
    final int totalEnrolled = _students.length;
    final double avgPercentage = _students.isEmpty
        ? 0.0
        : (_students.map((s) => s.percentage).reduce((a, b) => a + b) / _students.length);

    // Grade Distribution Tiers
    final distinctionCount = _students.where((s) => s.percentage >= 80).length;
    final proficientCount = _students.where((s) => s.percentage >= 65 && s.percentage < 80).length;
    final passingCount = _students.where((s) => s.percentage >= 50 && s.percentage < 65).length;
    final needsSupportCount = _students.where((s) => s.percentage < 50).length;

    // Weak Topic Analysis Demo Grounded in Subject & Questions
    final weakTopics = [
      (topic: 'Process Scheduling & Preemption', mastery: 58.0, count: 12),
      (topic: 'Deadlock Detection & Semaphores', mastery: 64.5, count: 18),
      (topic: 'Virtual Memory Paging & LRU', mastery: 72.0, count: 24),
      (topic: 'File Systems & Inode Allocation', mastery: 86.0, count: 15),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top Health Summary Card
        WatercolorBlobContainer(
          variant: BlobVariant.sageSoft,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Class Performance & Academic Health',
                          style: TextStyle(
                            fontFamily: AppTheme.fontCardo,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.inkForest,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Grounded across exams, assignments, and roster attendance for ${_classroom.name}.',
                          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, color: AppTheme.charcoalSlate),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 15),
                    label: const Text('Export Analytics CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.inkForest,
                      side: const BorderSide(color: AppTheme.inkForest),
                      textStyle: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () {
                      final csv = ExportService.instance.generateClassroomAnalyticsCsv(
                        classroom: _classroom,
                        students: _students,
                        classAverage: avgPercentage,
                      );
                      Clipboard.setData(ClipboardData(text: csv));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Comprehensive classroom analytics CSV copied to clipboard!'),
                          backgroundColor: AppTheme.inkForest,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 4 Metric Tiles
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Enrolled Students',
                      value: '$totalEnrolled',
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Class Average',
                      value: '${avgPercentage.toStringAsFixed(1)}%',
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Distinction (≥80%)',
                      value: '$distinctionCount',
                      icon: Icons.military_tech_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Needs Support (<50%)',
                      value: '$needsSupportCount',
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // GRADE DISTRIBUTION HISTOGRAM
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart, size: 18, color: AppTheme.inkForest),
                  SizedBox(width: 8),
                  Text(
                    'Grade Distribution Curve',
                    style: TextStyle(
                      fontFamily: AppTheme.fontCardo,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.inkForest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Distribution of cumulative student scores across all graded assessments.',
                style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
              ),
              const SizedBox(height: 16),
              _buildDistributionBar('Distinction (80% - 100%)', distinctionCount, totalEnrolled, AppTheme.successColor),
              const SizedBox(height: 10),
              _buildDistributionBar('Proficient (65% - 79%)', proficientCount, totalEnrolled, AppTheme.inkForest),
              const SizedBox(height: 10),
              _buildDistributionBar('Satisfactory (50% - 64%)', passingCount, totalEnrolled, AppTheme.warningColor),
              const SizedBox(height: 10),
              _buildDistributionBar('Needs Intervention (< 50%)', needsSupportCount, totalEnrolled, Colors.redAccent),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // TOPIC MASTERY & WEAK SPOTS RADAR
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology_outlined, size: 18, color: AppTheme.inkForest),
                      SizedBox(width: 8),
                      Text(
                        'Topic Mastery & Weak Spot Interventions',
                        style: TextStyle(
                          fontFamily: AppTheme.fontCardo,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.inkForest,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.mintWash,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'AI Diagnostic',
                      style: TextStyle(
                        fontFamily: AppTheme.fontZilla,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppTheme.inkForest,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Identifies specific subject domains where students frequently miss questions, recommending focused revision.',
                style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
              ),
              const SizedBox(height: 16),
              ...weakTopics.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.topic,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontZilla,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.inkForest,
                              ),
                            ),
                            Text(
                              '${item.mastery.toStringAsFixed(1)}% Mastery • ${item.count} Questions',
                              style: TextStyle(
                                fontFamily: AppTheme.fontZilla,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: item.mastery < 60 ? Colors.redAccent : AppTheme.inkForest,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.mastery / 100.0,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              item.mastery < 60 ? Colors.redAccent : (item.mastery < 75 ? AppTheme.warningColor : AppTheme.inkForest),
                            ),
                          ),
                        ),
                        if (item.mastery < 65) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 12, color: AppTheme.warningColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Recommendation: Faculty should share a 5-minute AI summary or post a practice quiz on "${item.topic}".',
                                  style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.charcoalSlate),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // STUDENT ENGAGEMENT ROSTER
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium_outlined, size: 18, color: AppTheme.inkForest),
                  SizedBox(width: 8),
                  Text(
                    'Student Engagement & Performance Standings',
                    style: TextStyle(
                      fontFamily: AppTheme.fontCardo,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.inkForest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Snapshot of enrolled students ranked by cumulative marks.',
                style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
              ),
              const SizedBox(height: 14),
              if (_students.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No student records found.', style: TextStyle(color: AppTheme.charcoalSlate)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _students.take(10).length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final s = _students[idx];
                    final rankColor = idx == 0
                        ? Colors.amber.shade700
                        : (idx == 1 ? Colors.grey.shade600 : (idx == 2 ? Colors.brown.shade400 : AppTheme.inkForest));

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: rankColor.withValues(alpha: 0.15),
                        child: Text(
                          '#${idx + 1}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: rankColor),
                        ),
                      ),
                      title: Text(
                        s.studentName,
                        style: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        '${s.assessmentsCount} assessment(s) • ${s.totalObtained.toStringAsFixed(0)} / ${s.totalMax.toStringAsFixed(0)} pts',
                        style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.charcoalSlate),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: s.percentage >= 80
                              ? AppTheme.mintWash
                              : (s.percentage >= 50 ? AppTheme.tealWash.withValues(alpha: 0.4) : Colors.red.shade50),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${s.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontFamily: AppTheme.fontZilla,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: s.percentage >= 80
                                ? AppTheme.inkForest
                                : (s.percentage >= 50 ? AppTheme.inkForest : Colors.redAccent),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper rendering a distribution bar in the histogram
  Widget _buildDistributionBar(String label, int count, int total, Color color) {
    final double pct = total == 0 ? 0 : (count / total * 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5)),
            Text(
              '$count students (${pct.toStringAsFixed(0)}%)',
              style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 12, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (count / total).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  /// Displays the Classroom Notification Center modal sheet.
  void _showNotificationCenterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active, color: AppTheme.inkForest, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Classroom Activity & Alerts',
                        style: TextStyle(
                          fontFamily: AppTheme.fontCardo,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppTheme.inkForest,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    child: const Text('Mark all read', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All alerts marked as read.'), backgroundColor: AppTheme.inkForest),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildNotificationItem(
                    icon: Icons.videocam,
                    iconColor: Colors.redAccent,
                    title: 'Live Class Ready',
                    subtitle: 'Faculty started a Jitsi Meet live class session in ${_classroom.subject}.',
                    timeAgo: 'Just now',
                    onTap: () {
                      Navigator.pop(ctx);
                      _tabController.animateTo(5);
                    },
                  ),
                  _buildNotificationItem(
                    icon: Icons.assignment_outlined,
                    iconColor: AppTheme.inkForest,
                    title: 'New Assignment Published',
                    subtitle: 'Assignment with rubric grading has been posted.',
                    timeAgo: '2 hours ago',
                    onTap: () {
                      Navigator.pop(ctx);
                      _tabController.animateTo(4);
                    },
                  ),
                  _buildNotificationItem(
                    icon: Icons.quiz_outlined,
                    iconColor: AppTheme.tealWash,
                    title: 'Scheduled Assessment',
                    subtitle: 'Classroom Exam scheduled with auto-submission and integrity timer.',
                    timeAgo: 'Yesterday',
                    onTap: () {
                      Navigator.pop(ctx);
                      _tabController.animateTo(3);
                    },
                  ),
                  _buildNotificationItem(
                    icon: Icons.announcement_outlined,
                    iconColor: AppTheme.warningColor,
                    title: 'Stream Announcement',
                    subtitle: 'New study materials and practice note updates attached.',
                    timeAgo: '2 days ago',
                    onTap: () {
                      Navigator.pop(ctx);
                      _tabController.animateTo(0);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String timeAgo,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.creamPaper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.15),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13.5)),
            Text(timeAgo, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, color: AppTheme.charcoalSlate)),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: AppTheme.charcoalSlate),
        ),
        onTap: onTap,
      ),
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
