import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate_classroom/models/exam_model.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/explain_simply_dialog.dart';
import 'package:studymate_classroom/widgets/primary_button.dart';
import 'package:studymate_classroom/widgets/watercolor_blob_container.dart';

/// Full-screen, distraction-free student exam runner ("Exam Form").
/// Features:
/// - Sticky countdown timer with auto-submit
/// - Question palette (Answered / Flagged / Unvisited)
/// - Tab switch / blur tracking with warning banners & threshold enforcement
/// - Auto-save every 10s and on answer selection
/// - Instant auto-grading for objective questions (MCQs, T/F)
/// - Background student ID watermark & built-in scratch calculator
class ExamRunnerScreen extends StatefulWidget {
  final Exam exam;
  final User currentUser;
  final String classroomId;

  const ExamRunnerScreen({
    super.key,
    required this.exam,
    required this.currentUser,
    required this.classroomId,
  });

  @override
  State<ExamRunnerScreen> createState() => _ExamRunnerScreenState();
}

class _ExamRunnerScreenState extends State<ExamRunnerScreen> with WidgetsBindingObserver {
  late List<Question> _questions;
  int _currentIndex = 0;

  // Student response state: questionId -> answer
  final Map<String, dynamic> _answers = {};
  final Set<String> _flaggedIds = {};
  final Set<String> _visitedIds = {};

  // Timing
  late int _remainingSeconds;
  Timer? _countdownTimer;
  Timer? _autoSaveTimer;
  DateTime? _startedAt;

  // Integrity tracking
  int _tabSwitchCount = 0;
  final List<DateTime> _tabSwitchLogs = [];
  bool _showIntegrityWarning = false;
  String _integrityWarningMessage = '';

  bool _isSubmitting = false;
  bool _isSubmitted = false;
  ExamSubmission? _resultSubmission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeExamSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isSubmitted) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _handleIntegrityViolation('Tab switch or app unfocus detected');
    }
  }

  void _handleIntegrityViolation(String reason) {
    if (_isSubmitted) return;
    final now = DateTime.now();
    _tabSwitchCount++;
    _tabSwitchLogs.add(now);

    final limit = widget.exam.tabSwitchLimit;
    if (limit > 0 && _tabSwitchCount >= limit) {
      _autoSubmitExam(violation: 'Maximum allowed tab switches ($limit) exceeded. Exam automatically submitted.');
    } else {
      setState(() {
        _showIntegrityWarning = true;
        _integrityWarningMessage = 'Warning: Window switch detected (${_tabSwitchCount} of $limit allowed). Stay inside the exam window.';
      });
    }
  }

  Future<void> _initializeExamSession() async {
    // 1. Prepare questions (apply shuffling if configured)
    final qList = List<Question>.from(widget.exam.questions);
    if (widget.exam.shuffleQuestions) {
      qList.shuffle(Random(widget.currentUser.id.hashCode));
    }
    _questions = qList;

    if (_questions.isNotEmpty) {
      _visitedIds.add(_questions.first.id);
    }

    _startedAt = DateTime.now();
    _remainingSeconds = widget.exam.durationMinutes * 60;

    // 2. Check existing in-progress submission to resume
    try {
      final existing = await FirestoreService.instance.getStudentExamSubmission(
        widget.classroomId,
        widget.exam.id,
        widget.currentUser.id,
      );
      if (existing != null) {
        if (existing.status == 'submitted' || existing.status == 'graded' || existing.status == 'released') {
          setState(() {
            _isSubmitted = true;
            _resultSubmission = existing;
          });
          return;
        }

        // Resume state
        _answers.addAll(existing.answers);
        _flaggedIds.addAll(existing.flaggedQuestionIds);
        _tabSwitchCount = existing.tabSwitchCount;
        _tabSwitchLogs.addAll(existing.tabSwitchLogs);

        if (existing.startedAt != null) {
          _startedAt = existing.startedAt;
          final elapsed = DateTime.now().difference(existing.startedAt!).inSeconds;
          _remainingSeconds = max(0, (widget.exam.durationMinutes * 60) - elapsed);
        }
      }
    } catch (_) {}

    // 3. Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _autoSubmitExam(violation: 'Time limit reached.');
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });

    // 4. Start auto-save periodic timer (every 10s)
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _persistCurrentProgress();
    });
  }

  Future<void> _persistCurrentProgress() async {
    if (_isSubmitted || !mounted) return;
    try {
      final sub = ExamSubmission(
        id: widget.currentUser.id,
        examId: widget.exam.id,
        classroomId: widget.classroomId,
        studentId: widget.currentUser.id,
        studentName: widget.currentUser.name,
        studentEmail: widget.currentUser.email,
        answers: _answers,
        flaggedQuestionIds: _flaggedIds.toList(),
        tabSwitchCount: _tabSwitchCount,
        tabSwitchLogs: _tabSwitchLogs,
        startedAt: _startedAt,
        status: 'in_progress',
      );
      await FirestoreService.instance.saveExamSubmission(widget.classroomId, widget.exam.id, sub);
    } catch (_) {}
  }

  void _onAnswerSelected(String questionId, dynamic answer) {
    setState(() {
      _answers[questionId] = answer;
    });
    _persistCurrentProgress();
  }

  void _toggleFlag(String questionId) {
    setState(() {
      if (_flaggedIds.contains(questionId)) {
        _flaggedIds.remove(questionId);
      } else {
        _flaggedIds.add(questionId);
      }
    });
  }

  void _goToQuestion(int index) {
    if (index >= 0 && index < _questions.length) {
      setState(() {
        _currentIndex = index;
        _visitedIds.add(_questions[index].id);
      });
    }
  }

  Future<void> _autoSubmitExam({String? violation}) async {
    if (_isSubmitted) return;
    _countdownTimer?.cancel();
    _autoSaveTimer?.cancel();
    if (violation != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(violation), backgroundColor: AppTheme.errorColor, duration: const Duration(seconds: 4)),
      );
    }
    await _executeSubmission();
  }

  Future<void> _confirmAndSubmit() async {
    final answeredCount = _answers.keys.length;
    final flaggedCount = _flaggedIds.length;
    final unansweredCount = _questions.length - answeredCount;

    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Submit Exam Assessment?',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please review your attempt summary before final submission:',
              style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow('Total Questions:', '${_questions.length}'),
            _buildSummaryRow('Answered:', '$answeredCount', color: AppTheme.successColor),
            _buildSummaryRow('Unanswered:', '$unansweredCount', color: unansweredCount > 0 ? AppTheme.errorColor : AppTheme.charcoalSlate),
            _buildSummaryRow('Flagged for Review:', '$flaggedCount', color: AppTheme.accentPeach),
            const SizedBox(height: 12),
            const Text(
              'Once submitted, your answers will be locked for grading.',
              style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
            ),
          ],
        ),
        confirmLabel: 'Confirm & Submit',
        confirmColor: AppTheme.inkForest,
        onConfirm: () {
          Navigator.of(ctx).pop();
          _executeSubmission();
        },
      ),
    );
  }

  Future<void> _executeSubmission() async {
    if (_isSubmitted) return;
    setState(() => _isSubmitting = true);

    try {
      // 1. Auto-grade objective questions (MCQs & True/False)
      double totalObtained = 0.0;
      final Map<String, double> scores = {};
      final Map<String, String> feedback = {};
      bool hasSubjectiveQuestions = false;

      for (final q in _questions) {
        final studentAns = _answers[q.id];

        if (q.questionType == 'mcq' || q.questionType == 'multi_mcq' || q.questionType == 'true_false') {
          bool isCorrect = false;
          if (q.questionType == 'true_false') {
            final expected = q.answer.trim().toLowerCase();
            final actual = studentAns?.toString().trim().toLowerCase();
            isCorrect = (expected == actual);
          } else {
            // MCQ index check
            if (studentAns != null && q.correctOptionIndex != null) {
              final studentIdx = int.tryParse(studentAns.toString());
              isCorrect = (studentIdx == q.correctOptionIndex);
            }
          }

          if (isCorrect) {
            scores[q.id] = q.marks;
            totalObtained += q.marks;
            feedback[q.id] = 'Correct! Full marks awarded.';
          } else {
            final penalty = q.negativeMarks > 0 ? -q.negativeMarks : 0.0;
            scores[q.id] = penalty;
            totalObtained += penalty;
            feedback[q.id] = q.explanation ?? 'Incorrect answer.';
          }
        } else {
          // Subjective / Short / Long / Numerical / Code
          hasSubjectiveQuestions = true;
          // Initial heuristic award or awaiting teacher rubric grading
          scores[q.id] = 0.0;
          feedback[q.id] = 'Awaiting faculty rubric evaluation.';
        }
      }

      totalObtained = max(0.0, totalObtained);
      final maxMarks = widget.exam.totalMarks > 0
          ? widget.exam.totalMarks
          : _questions.fold<double>(0.0, (acc, q) => acc + q.marks);
      final percentage = maxMarks > 0 ? (totalObtained / maxMarks) * 100 : 0.0;
      final isPassed = totalObtained >= widget.exam.passingMarks;

      final submissionStatus = widget.exam.releaseScoresImmediately
          ? 'released'
          : (hasSubjectiveQuestions ? 'submitted' : 'graded');

      final submission = ExamSubmission(
        id: widget.currentUser.id,
        examId: widget.exam.id,
        classroomId: widget.classroomId,
        studentId: widget.currentUser.id,
        studentName: widget.currentUser.name,
        studentEmail: widget.currentUser.email,
        answers: _answers,
        questionScores: scores,
        questionFeedback: feedback,
        flaggedQuestionIds: _flaggedIds.toList(),
        tabSwitchCount: _tabSwitchCount,
        tabSwitchLogs: _tabSwitchLogs,
        startedAt: _startedAt,
        submittedAt: DateTime.now(),
        totalMarksObtained: totalObtained,
        maxMarks: maxMarks,
        percentage: percentage,
        isPassed: isPassed,
        status: submissionStatus,
      );

      await FirestoreService.instance.saveExamSubmission(widget.classroomId, widget.exam.id, submission);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmitted = true;
          _resultSubmission = submission;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13)),
          Text(value, style: TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13.5, color: color ?? AppTheme.inkForest)),
        ],
      ),
    );
  }

  // ===========================================================================
  // SCRATCH CALCULATOR DIALOG
  // ===========================================================================
  void _openCalculatorDialog() {
    final displayCtrl = TextEditingController(text: '0');
    double firstOperand = 0.0;
    String operator = '';
    bool shouldReset = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setCalcState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calculate, color: AppTheme.inkForest, size: 20),
                    const SizedBox(width: 8),
                    const Text('Scratch Calculator', style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.inkForest)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.of(ctx).pop()),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.creamPaper, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderColor)),
                  child: Text(
                    displayCtrl.text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.inkForest),
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: [
                    _calcBtn('C', () {
                      setCalcState(() {
                        displayCtrl.text = '0';
                        firstOperand = 0;
                        operator = '';
                      });
                    }, color: Colors.red.shade100, textColor: Colors.red.shade900),
                    _calcBtn('√', () {
                      final val = double.tryParse(displayCtrl.text) ?? 0;
                      setCalcState(() => displayCtrl.text = (val >= 0 ? sqrt(val).toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '') : 'Error'));
                    }),
                    _calcBtn('^', () {
                      firstOperand = double.tryParse(displayCtrl.text) ?? 0;
                      operator = '^';
                      shouldReset = true;
                    }),
                    _calcBtn('÷', () {
                      firstOperand = double.tryParse(displayCtrl.text) ?? 0;
                      operator = '÷';
                      shouldReset = true;
                    }, color: AppTheme.mintWash),
                    ...['7', '8', '9'].map((n) => _calcBtn(n, () => _calcNum(n, displayCtrl, shouldReset, setCalcState))),
                    _calcBtn('×', () {
                      firstOperand = double.tryParse(displayCtrl.text) ?? 0;
                      operator = '×';
                      shouldReset = true;
                    }, color: AppTheme.mintWash),
                    ...['4', '5', '6'].map((n) => _calcBtn(n, () => _calcNum(n, displayCtrl, shouldReset, setCalcState))),
                    _calcBtn('-', () {
                      firstOperand = double.tryParse(displayCtrl.text) ?? 0;
                      operator = '-';
                      shouldReset = true;
                    }, color: AppTheme.mintWash),
                    ...['1', '2', '3'].map((n) => _calcBtn(n, () => _calcNum(n, displayCtrl, shouldReset, setCalcState))),
                    _calcBtn('+', () {
                      firstOperand = double.tryParse(displayCtrl.text) ?? 0;
                      operator = '+';
                      shouldReset = true;
                    }, color: AppTheme.mintWash),
                    _calcBtn('0', () => _calcNum('0', displayCtrl, shouldReset, setCalcState)),
                    _calcBtn('.', () {
                      if (!displayCtrl.text.contains('.')) {
                        setCalcState(() => displayCtrl.text += '.');
                      }
                    }),
                    _calcBtn('=', () {
                      final second = double.tryParse(displayCtrl.text) ?? 0;
                      double res = 0;
                      if (operator == '+') res = firstOperand + second;
                      if (operator == '-') res = firstOperand - second;
                      if (operator == '×') res = firstOperand * second;
                      if (operator == '÷') res = second != 0 ? firstOperand / second : 0;
                      if (operator == '^') res = pow(firstOperand, second).toDouble();
                      setCalcState(() {
                        displayCtrl.text = res.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');
                        operator = '';
                        shouldReset = true;
                      });
                    }, color: AppTheme.inkForest, textColor: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _calcNum(String n, TextEditingController ctrl, bool shouldReset, StateSetter setCalcState) {
    setCalcState(() {
      if (ctrl.text == '0' || shouldReset) {
        ctrl.text = n;
      } else {
        ctrl.text += n;
      }
    });
  }

  Widget _calcBtn(String label, VoidCallback onTap, {Color? color, Color? textColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color ?? Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16, color: textColor ?? AppTheme.charcoalSlate)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted && _resultSubmission != null) {
      return _buildScoreCardScreen(_resultSubmission!);
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.exam.title)),
        body: const Center(child: Text('This exam has no questions configured.')),
      );
    }

    final currentQ = _questions[_currentIndex];
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final isLowTime = _remainingSeconds < 300; // < 5 mins
    final isCriticalTime = _remainingSeconds < 60; // < 1 min

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmAndSubmit();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.creamPaper,
        body: Stack(
          children: [
            // Student ID Watermark across the background
            if (widget.exam.watermarkStudentId)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.04,
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.35,
                        child: Text(
                          '${widget.currentUser.name} · ${widget.currentUser.id}\n${widget.exam.title}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            SafeArea(
              child: Column(
                children: [
                  // Top Sticky Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.exam.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.inkForest),
                              ),
                              Text(
                                '${widget.exam.subject} · Unit ${widget.exam.unitNumber ?? 1} · Question ${_currentIndex + 1} of ${_questions.length}',
                                style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (widget.exam.allowCalculator)
                          IconButton(
                            icon: const Icon(Icons.calculate_outlined, color: AppTheme.inkForest),
                            tooltip: 'Scratch Calculator',
                            onPressed: _openCalculatorDialog,
                          ),
                        const SizedBox(width: 8),

                        // Timer badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCriticalTime
                                ? Colors.red.shade100
                                : (isLowTime ? Colors.amber.shade100 : AppTheme.mintWash.withValues(alpha: 0.6)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isCriticalTime ? Colors.red : (isLowTime ? Colors.amber.shade800 : AppTheme.inkForest),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer,
                                size: 16,
                                color: isCriticalTime ? Colors.red.shade900 : (isLowTime ? Colors.amber.shade900 : AppTheme.inkForest),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isCriticalTime ? Colors.red.shade900 : (isLowTime ? Colors.amber.shade900 : AppTheme.inkForest),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        PrimaryButton(
                          text: 'Submit',
                          icon: Icons.check,
                          height: 36,
                          onPressed: _isSubmitting ? null : _confirmAndSubmit,
                        ),
                      ],
                    ),
                  ),

                  // Integrity Warning Banner if user blurred window
                  if (_showIntegrityWarning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.amber.shade100,
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.brown, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _integrityWarningMessage,
                              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.brown),
                            onPressed: () => setState(() => _showIntegrityWarning = false),
                          ),
                        ],
                      ),
                    ),

                  // Main Assessment Body: Palette + Question Pane
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Question Palette Drawer / Sidebar
                        Container(
                          width: 220,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(right: BorderSide(color: AppTheme.borderColor)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Question Palette', style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.inkForest)),
                                    const SizedBox(height: 8),
                                    _buildPaletteLegend(),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 1.0,
                                  ),
                                  itemCount: _questions.length,
                                  itemBuilder: (ctx, idx) {
                                    final q = _questions[idx];
                                    final isCurrent = idx == _currentIndex;
                                    final isAnswered = _answers.containsKey(q.id);
                                    final isFlagged = _flaggedIds.contains(q.id);

                                    Color bg = Colors.grey.shade100;
                                    Color fg = AppTheme.charcoalSlate;
                                    Color border = Colors.transparent;

                                    if (isAnswered) {
                                      bg = AppTheme.mintWash.withValues(alpha: 0.8);
                                      fg = AppTheme.inkForest;
                                    }
                                    if (isFlagged) {
                                      bg = AppTheme.accentPeach.withValues(alpha: 0.7);
                                      fg = Colors.black87;
                                    }
                                    if (isCurrent) {
                                      border = AppTheme.inkForest;
                                    }

                                    return InkWell(
                                      onTap: () => _goToQuestion(idx),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: bg,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: border, width: isCurrent ? 2.0 : 1.0),
                                        ),
                                        child: Text(
                                          '${idx + 1}',
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontZilla,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            color: fg,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Center Question Display Pane
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Question Header (Type, Marks, Flag toggle)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: AppTheme.mintWash.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
                                      child: Text(
                                        'Question ${_currentIndex + 1} of ${_questions.length}',
                                        style: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                      child: Text(
                                        '+${currentQ.marks.toStringAsFixed(1)} marks',
                                        style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.charcoalSlate),
                                      ),
                                    ),
                                    const Spacer(),
                                    OutlinedButton.icon(
                                      icon: Icon(
                                        _flaggedIds.contains(currentQ.id) ? Icons.flag : Icons.flag_outlined,
                                        size: 16,
                                        color: _flaggedIds.contains(currentQ.id) ? AppTheme.accentPeach : AppTheme.charcoalSlate,
                                      ),
                                      label: Text(
                                        _flaggedIds.contains(currentQ.id) ? 'Flagged' : 'Flag for Review',
                                        style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12, color: _flaggedIds.contains(currentQ.id) ? AppTheme.accentPeach : AppTheme.charcoalSlate),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: _flaggedIds.contains(currentQ.id) ? AppTheme.accentPeach : AppTheme.borderColor),
                                      ),
                                      onPressed: () => _toggleFlag(currentQ.id),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Prompt Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.borderColor),
                                  ),
                                  child: SelectableText(
                                    currentQ.question,
                                    style: const TextStyle(fontFamily: AppTheme.fontCardo, fontSize: 17, color: AppTheme.inkForest, height: 1.4),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Interactive Answer Area
                                _buildInteractiveAnswerArea(currentQ),
                                const SizedBox(height: 30),

                                // Bottom Navigation buttons
                                Row(
                                  children: [
                                    if (_currentIndex > 0)
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.arrow_back, size: 16),
                                        label: const Text('Previous'),
                                        onPressed: () => _goToQuestion(_currentIndex - 1),
                                      ),
                                    const SizedBox(width: 12),
                                    if (_answers.containsKey(currentQ.id))
                                      TextButton(
                                        onPressed: () {
                                          setState(() => _answers.remove(currentQ.id));
                                          _persistCurrentProgress();
                                        },
                                        child: const Text('Clear Response', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                      ),
                                    const Spacer(),
                                    if (_currentIndex < _questions.length - 1)
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.arrow_forward, size: 16),
                                        label: const Text('Save & Next'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.inkForest,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        ),
                                        onPressed: () => _goToQuestion(_currentIndex + 1),
                                      )
                                    else
                                      PrimaryButton(
                                        text: 'Review & Submit Exam',
                                        icon: Icons.check,
                                        height: 42,
                                        onPressed: _confirmAndSubmit,
                                      ),
                                  ],
                                ),
                              ],
                            ),
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

  Widget _buildInteractiveAnswerArea(Question q) {
    final selectedVal = _answers[q.id];

    if (q.questionType == 'mcq' || q.questionType == 'multi_mcq') {
      final options = q.options ?? [];
      return Column(
        children: List.generate(options.length, (optIdx) {
          final isSelected = selectedVal?.toString() == optIdx.toString();
          return InkWell(
            onTap: () => _onAnswerSelected(q.id, optIdx),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.mintWash.withValues(alpha: 0.5) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? AppTheme.inkForest : AppTheme.borderColor, width: isSelected ? 1.8 : 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppTheme.inkForest : Colors.grey.shade100,
                    ),
                    child: Text(
                      String.fromCharCode(65 + optIdx),
                      style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : AppTheme.charcoalSlate),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      options[optIdx],
                      style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 14, color: AppTheme.charcoalSlate),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    } else if (q.questionType == 'true_false') {
      return Row(
        children: [
          Expanded(
            child: _buildTfChoiceCard('True', selectedVal == 'True', () => _onAnswerSelected(q.id, 'True')),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildTfChoiceCard('False', selectedVal == 'False', () => _onAnswerSelected(q.id, 'False')),
          ),
        ],
      );
    } else {
      // Short / Long / Numerical / Code Input
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q.questionType == 'numerical' ? 'Enter numerical answer (units if applicable):' : 'Type your detailed answer below:',
              style: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.inkForest),
            ),
            const SizedBox(height: 10),
            CustomTextField(
              controller: TextEditingController(text: selectedVal?.toString() ?? ''),
              label: 'Your Answer',
              hintText: 'Enter your comprehensive answer...',
              maxLines: q.questionType == 'long' ? 8 : (q.questionType == 'numerical' ? 1 : 4),
              onChanged: (val) => _onAnswerSelected(q.id, val),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTfChoiceCard(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.mintWash.withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.inkForest : AppTheme.borderColor, width: isSelected ? 2.0 : 1.0),
        ),
        child: Text(
          label,
          style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? AppTheme.inkForest : AppTheme.charcoalSlate),
        ),
      ),
    );
  }

  Widget _buildPaletteLegend() {
    return Column(
      children: [
        _legendItem(AppTheme.mintWash, 'Answered'),
        const SizedBox(height: 4),
        _legendItem(AppTheme.accentPeach, 'Flagged for Review'),
        const SizedBox(height: 4),
        _legendItem(Colors.grey.shade100, 'Unvisited'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), border: Border.all(color: AppTheme.borderColor))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, color: AppTheme.charcoalSlate)),
      ],
    );
  }

  // ===========================================================================
  // SCORECARD & RESULT SCREEN
  // ===========================================================================
  Widget _buildScoreCardScreen(ExamSubmission submission) {
    final isReleased = submission.isReleased;

    return Scaffold(
      backgroundColor: AppTheme.creamPaper,
      appBar: AppBar(
        title: Text('${widget.exam.title} - Scorecard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                WatercolorBlobContainer(
                  variant: isReleased && submission.isPassed ? BlobVariant.mintWash : BlobVariant.sageSoft,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        isReleased
                            ? (submission.isPassed ? Icons.emoji_events : Icons.assignment_turned_in)
                            : Icons.hourglass_top,
                        size: 54,
                        color: AppTheme.inkForest,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isReleased
                            ? (submission.isPassed ? 'Exam Passed!' : 'Exam Completed')
                            : 'Submission Received!',
                        style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 22, color: AppTheme.inkForest),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isReleased
                            ? 'Your official evaluation is released by instructor.'
                            : 'Objective questions graded. Awaiting instructor review for subjective items.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.charcoalSlate),
                      ),
                      const SizedBox(height: 16),
                      if (isReleased) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${submission.totalMarksObtained.toStringAsFixed(1)} / ${submission.maxMarks.toStringAsFixed(1)}',
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 32, color: AppTheme.inkForest),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: submission.isPassed ? AppTheme.successColor : AppTheme.errorColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${submission.percentage.toStringAsFixed(1)}%',
                                style: const TextStyle(fontFamily: AppTheme.fontZilla, fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Question by Question breakdown if released
                if (isReleased) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Detailed Question Review & Explanations:',
                      style: TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.inkForest),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...widget.exam.questions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final q = entry.value;
                    final studentAns = submission.answers[q.id];
                    final marksAwarded = submission.questionScores[q.id] ?? 0.0;
                    final isFullMarks = marksAwarded >= q.marks;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
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
                              Text('Q${idx + 1}. ', style: const TextStyle(fontFamily: AppTheme.fontCardo, fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.inkForest)),
                              Expanded(
                                child: Text(q.question, style: const TextStyle(fontFamily: AppTheme.fontCardo, fontSize: 14, color: AppTheme.charcoalSlate)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isFullMarks ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${marksAwarded.toStringAsFixed(1)} / ${q.marks}',
                                  style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: isFullMarks ? AppTheme.successColor : AppTheme.errorColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Your Answer: ${studentAns != null ? (q.options != null && studentAns is int && studentAns < q.options!.length ? q.options![studentAns] : studentAns) : "(unanswered)"}', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, color: isFullMarks ? AppTheme.successColor : AppTheme.errorColor)),
                          Text('Correct / Model Answer: ${q.answer}', style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, color: AppTheme.charcoalSlate)),
                          if (q.explanation != null) ...[
                            const SizedBox(height: 6),
                            Text('Explanation: ${q.explanation}', style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, color: AppTheme.textSecondary)),
                          ],
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              icon: const Icon(Icons.lightbulb_outline, size: 14),
                              label: const Text('Explain Simply'),
                              onPressed: () {
                                ExplainSimplyDialog.show(
                                  context: context,
                                  topic: q.topic,
                                  subtopic: q.subtopic,
                                  sourceContext: '${q.question}\n\nModel Answer: ${q.answer}',
                                  sourcePage: q.sourcePage,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  text: 'Back to Classroom',
                  icon: Icons.school,
                  height: 42,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
