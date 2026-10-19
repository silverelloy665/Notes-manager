import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/botanical_decoration.dart';

/// Full-featured Exam Simulation Mode supporting timed testing, question navigation grid,
/// confidence tracking, weak topics diagnostic report, and detailed mistake review with distractor analysis.
class ExamSimulationView extends StatefulWidget {
  final List<Question> availableQuestions;
  final String initialTopic;
  final VoidCallback onExit;

  const ExamSimulationView({
    super.key,
    required this.availableQuestions,
    required this.initialTopic,
    required this.onExit,
  });

  @override
  State<ExamSimulationView> createState() => _ExamSimulationViewState();
}

enum _ExamStage { setup, inProgress, scoreReport }

class _ExamSimulationViewState extends State<ExamSimulationView> {
  _ExamStage _stage = _ExamStage.setup;

  // Setup Parameters
  String _selectedTopic = 'All Topics';
  int _questionCount = 10;
  int _durationMinutes = 10;
  String _questionTypeFilter = 'all'; // 'all', 'mcq'

  // In-Progress State
  List<Question> _examQuestions = [];
  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {}; // qIndex -> optionIndex
  final Map<int, String> _conceptualAnswers = {}; // qIndex -> text
  final Map<int, double> _confidenceLevels = {}; // qIndex -> 0.25 (low), 0.60 (med), 1.0 (high)
  final Set<int> _flaggedIndices = {}; // questions marked for review
  Timer? _examTimer;
  int _secondsRemaining = 0;
  int _totalExamSeconds = 0;

  @override
  void initState() {
    super.initState();
    _selectedTopic = widget.initialTopic;
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    super.dispose();
  }

  List<String> get _topics {
    final set = <String>{'All Topics'};
    for (final q in widget.availableQuestions) {
      if (q.topic.trim().isNotEmpty) set.add(q.topic.trim());
    }
    return set.toList();
  }

  void _startExam() {
    var pool = widget.availableQuestions.where((q) {
      if (_selectedTopic != 'All Topics' && q.topic.toLowerCase() != _selectedTopic.toLowerCase()) {
        return false;
      }
      if (_questionTypeFilter == 'mcq' && !q.isMcq) return false;
      return true;
    }).toList();

    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No questions available for the selected topic and filters.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    pool.shuffle();
    final count = pool.length < _questionCount ? pool.length : _questionCount;
    _examQuestions = pool.take(count).toList();

    _totalExamSeconds = _durationMinutes * 60;
    _secondsRemaining = _totalExamSeconds;
    _currentIndex = 0;
    _selectedAnswers.clear();
    _conceptualAnswers.clear();
    _confidenceLevels.clear();
    _flaggedIndices.clear();

    _examTimer?.cancel();
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        _submitExam(autoSubmit: true);
      }
    });

    setState(() => _stage = _ExamStage.inProgress);
  }

  void _confirmSubmit() {
    final unanswered = _examQuestions.length - (_selectedAnswers.length + _conceptualAnswers.length);
    if (unanswered > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Unanswered Questions', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          content: Text('You have $unanswered unanswered question(s). Are you sure you want to finish the exam?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Return to Exam'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _submitExam();
              },
              child: const Text('Submit Now'),
            ),
          ],
        ),
      );
    } else {
      _submitExam();
    }
  }

  void _submitExam({bool autoSubmit = false}) {
    _examTimer?.cancel();
    setState(() => _stage = _ExamStage.scoreReport);

    if (autoSubmit && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Time has expired! Your exam was automatically submitted.'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }
  }

  String _formatTimer(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showQuestionGridSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('Question Navigator', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_examQuestions.length, (idx) {
                final isCurrent = idx == _currentIndex;
                final isAnswered = _selectedAnswers.containsKey(idx) || _conceptualAnswers.containsKey(idx);
                final isFlagged = _flaggedIndices.contains(idx);

                Color bg = Colors.grey.shade100;
                Color border = Colors.grey.shade300;
                Color text = Colors.black87;

                if (isFlagged) {
                  bg = const Color(0xFFFFF3E0);
                  border = const Color(0xFFE65100);
                  text = const Color(0xFFE65100);
                } else if (isAnswered) {
                  bg = const Color(0xFFE8F5E9);
                  border = const Color(0xFF2E7D32);
                  text = const Color(0xFF2E7D32);
                }

                if (isCurrent) {
                  border = AppTheme.primaryColor;
                }

                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _currentIndex = idx);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border, width: isCurrent ? 2.0 : 1.0),
                    ),
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: text, fontSize: 13),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BotanicalBackground(
      showButterfly: true,
      showTopVine: true,
      showBottomVine: true,
      opacity: 0.94,
      child: SafeArea(
        child: switch (_stage) {
          _ExamStage.setup => _buildSetupView(),
          _ExamStage.inProgress => _buildInProgressView(),
          _ExamStage.scoreReport => _buildScoreReportView(),
        },
      ),
    );
  }

  // ==========================================
  // 1. SETUP VIEW
  // ==========================================
  Widget _buildSetupView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded, color: AppTheme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exam Simulation Mode',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          'Test your retention under realistic exam conditions',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: widget.onExit,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Filter by Topic
              const Text('Select Target Topic:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _topics.contains(_selectedTopic) ? _selectedTopic : 'All Topics',
                    items: _topics.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13, fontFamily: 'serif')))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTopic = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Question Count
              const Text('Number of Questions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [5, 10, 15, 20].map((count) {
                  final isSelected = _questionCount == count;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _questionCount = count),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Exam Duration
              const Text('Exam Duration (Minutes):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [5, 10, 15, 30].map((mins) {
                  final isSelected = _durationMinutes == mins;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _durationMinutes = mins),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
                          ),
                          child: Text(
                            '${mins}m',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Question Format
              const Text('Question Format:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _questionTypeFilter = 'all'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _questionTypeFilter == 'all' ? AppTheme.primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _questionTypeFilter == 'all' ? AppTheme.primaryColor : AppTheme.borderColor),
                        ),
                        child: Text('Mixed (MCQs & Q&A)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _questionTypeFilter == 'all' ? Colors.white : AppTheme.textPrimary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _questionTypeFilter = 'mcq'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _questionTypeFilter == 'mcq' ? AppTheme.primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _questionTypeFilter == 'mcq' ? AppTheme.primaryColor : AppTheme.borderColor),
                        ),
                        child: Text('MCQs Only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _questionTypeFilter == 'mcq' ? Colors.white : AppTheme.textPrimary)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                      onPressed: widget.onExit,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: const Text('Start Timed Exam', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _startExam,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. IN-PROGRESS EXAM VIEW
  // ==========================================
  Widget _buildInProgressView() {
    final q = _examQuestions[_currentIndex];
    final isMcq = q.isMcq;
    final isFlagged = _flaggedIndices.contains(_currentIndex);
    final isTimerUrgent = _secondsRemaining <= 120; // 2 minutes left

    return Column(
      children: [
        // Top Sticky Exam Status Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            border: const Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1.2)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryColor),
                tooltip: 'Question Grid',
                onPressed: _showQuestionGridSheet,
              ),
              const SizedBox(width: 6),
              Text(
                'Question ${_currentIndex + 1} of ${_examQuestions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.primaryColor),
              ),
              const Spacer(),
              // Countdown Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isTimerUrgent ? const Color(0xFFFFEBEE) : AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isTimerUrgent ? AppTheme.errorColor : AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_rounded, size: 16, color: isTimerUrgent ? AppTheme.errorColor : AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimer(_secondsRemaining),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isTimerUrgent ? AppTheme.errorColor : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Flag for review button
              IconButton(
                icon: Icon(
                  isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
                  color: isFlagged ? const Color(0xFFE65100) : AppTheme.secondaryColor,
                ),
                tooltip: isFlagged ? 'Unflag Question' : 'Flag for Review',
                onPressed: () {
                  setState(() {
                    if (isFlagged) {
                      _flaggedIndices.remove(_currentIndex);
                    } else {
                      _flaggedIndices.add(_currentIndex);
                    }
                  });
                },
              ),
            ],
          ),
        ),

        // Linear Progress bar
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _examQuestions.length,
          minHeight: 4,
          backgroundColor: AppTheme.primaryLight,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),

        // Main Question Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 680),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Topic and Slide Metadata
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                        child: Text(q.topic, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      ),
                      if (q.subtopic != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                          child: Text(q.subtopic!, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                        ),
                      ],
                      const Spacer(),
                      if (isFlagged)
                        const Row(
                          children: [
                            Icon(Icons.flag_rounded, size: 14, color: Color(0xFFE65100)),
                            SizedBox(width: 4),
                            Text('Flagged for Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Question Text in Serif
                  Text(
                    q.question,
                    style: const TextStyle(fontFamily: 'serif', fontSize: 16.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // MCQ Options or Conceptual Typing
                  if (isMcq) ...[
                    ...List.generate(q.options!.length, (optIdx) {
                      final optText = q.options![optIdx];
                      final isSelected = _selectedAnswers[_currentIndex] == optIdx;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => setState(() => _selectedAnswers[_currentIndex] = optIdx),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryLight.withValues(alpha: 0.3) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                                width: isSelected ? 1.6 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primaryColor : AppTheme.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    String.fromCharCode(65 + optIdx),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    optText,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Confidence Slider: "How sure are you?"
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology_outlined, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 6),
                              const Text('Confidence Level (Learning Science):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                              const Spacer(),
                              Text(
                                (_confidenceLevels[_currentIndex] ?? 0.6) >= 0.8
                                    ? '100% Sure'
                                    : (_confidenceLevels[_currentIndex] ?? 0.6) >= 0.4
                                        ? '50/50'
                                        : 'Guessing',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.primaryColor,
                              thumbColor: AppTheme.primaryColor,
                              overlayColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _confidenceLevels[_currentIndex] ?? 0.6,
                              min: 0.25,
                              max: 1.0,
                              divisions: 2,
                              onChanged: (val) => setState(() => _confidenceLevels[_currentIndex] = val),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Conceptual Typing in Exam Mode
                    TextField(
                      maxLines: 5,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Formulate your academic response addressing key concepts and mechanisms...',
                        hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      controller: TextEditingController(text: _conceptualAnswers[_currentIndex] ?? '')
                        ..selection = TextSelection.collapsed(offset: (_conceptualAnswers[_currentIndex] ?? '').length),
                      onChanged: (val) => _conceptualAnswers[_currentIndex] = val,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Navigation Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Previous'),
                onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
                onPressed: _confirmSubmit,
                child: const Text('Submit Exam'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(_currentIndex < _examQuestions.length - 1 ? 'Next' : 'Review'),
                onPressed: _currentIndex < _examQuestions.length - 1
                    ? () => setState(() => _currentIndex++)
                    : _confirmSubmit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. SCORE REPORT & WEAK TOPICS REVIEW VIEW
  // ==========================================
  Widget _buildScoreReportView() {
    int correctCount = 0;
    final Map<String, ({int correct, int total})> topicPerformance = {};

    for (int i = 0; i < _examQuestions.length; i++) {
      final q = _examQuestions[i];
      final isCorrect = q.isMcq
          ? _selectedAnswers[i] == q.correctOptionIndex
          : (_conceptualAnswers[i]?.trim().isNotEmpty == true);

      if (isCorrect) correctCount++;

      final current = topicPerformance[q.topic] ?? (correct: 0, total: 0);
      topicPerformance[q.topic] = (
        correct: current.correct + (isCorrect ? 1 : 0),
        total: current.total + 1,
      );
    }

    final total = _examQuestions.length;
    final percentage = total > 0 ? ((correctCount / total) * 100).round() : 0;
    final timeSpentSecs = _totalExamSeconds - _secondsRemaining;

    final mistakes = <({int index, Question question, int? chosen})>[];
    for (int i = 0; i < _examQuestions.length; i++) {
      final q = _examQuestions[i];
      if (q.isMcq && _selectedAnswers[i] != q.correctOptionIndex) {
        mistakes.add((index: i + 1, question: q, chosen: _selectedAnswers[i]));
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: percentage >= 70 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      percentage >= 70 ? Icons.emoji_events_rounded : Icons.psychology_rounded,
                      size: 36,
                      color: percentage >= 70 ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          percentage >= 70 ? '🎉 Exam Completed with Distinction!' : 'Exam Complete — Diagnostic Review',
                          style: const TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                        Text(
                          'Score: $correctCount / $total ($percentage%) • Time Taken: ${_formatTimer(timeSpentSecs)}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Weak Topics Diagnostic Section
              const Text('Topic Mastery Diagnostic Matrix:', style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
              const SizedBox(height: 10),
              ...topicPerformance.entries.map((entry) {
                final topicAcc = entry.value.total > 0 ? ((entry.value.correct / entry.value.total) * 100).round() : 0;
                final isWeak = topicAcc < 70;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isWeak ? const Color(0xFFFFF7F7) : const Color(0xFFF4F9F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isWeak ? const Color(0xFFFFCDD2) : const Color(0xFFA5D6A7)),
                  ),
                  child: Row(
                    children: [
                      Icon(isWeak ? Icons.warning_amber_rounded : Icons.check_circle_rounded, size: 18, color: isWeak ? AppTheme.errorColor : const Color(0xFF2E7D32)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${entry.value.correct}/${entry.value.total} ($topicAcc%)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isWeak ? AppTheme.errorColor : const Color(0xFF2E7D32)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isWeak ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isWeak ? 'Focus Area' : 'Mastered',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isWeak ? AppTheme.errorColor : const Color(0xFF2E7D32)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),

              // Mistakes and Distractor Analysis
              if (mistakes.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.errorColor),
                    const SizedBox(width: 8),
                    Text('Review of Mistakes (${mistakes.length}):', style: const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
                  ],
                ),
                const SizedBox(height: 10),
                ...mistakes.map((m) {
                  final q = m.question;
                  final chosenOpt = m.chosen != null && m.chosen! < q.options!.length ? q.options![m.chosen!] : 'No Answer Given';
                  final correctOpt = q.options![q.correctOptionIndex!];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q${m.index}: ${q.question}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✗ Your Choice: ', style: TextStyle(fontSize: 12, color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(chosenOpt, style: const TextStyle(fontSize: 12, color: AppTheme.errorColor))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✓ Correct Option: ', style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                            Expanded(child: Text(correctOpt, style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          q.explanation ?? q.answer,
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35),
                        ),
                        if (q.distractorReasoning != null && q.distractorReasoning!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...q.distractorReasoning!.entries.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('• Opt ${e.key}: ${e.value}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                              )),
                        ],
                      ],
                    ),
                  );
                }),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF2E7D32)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Incredible! 100% accuracy — no mistakes recorded for this exam session.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retake Exam'),
                      onPressed: () => setState(() => _stage = _ExamStage.setup),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Finish Review'),
                      onPressed: widget.onExit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

