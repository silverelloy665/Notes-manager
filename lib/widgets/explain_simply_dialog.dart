import 'package:flutter/material.dart';
import '../models/simple_explanation_model.dart';
import '../services/explain_simply_service.dart';
import '../utils/app_theme.dart';

/// Modal dialog and embedded panel presenting the 7-part "Explain This Simply" framework.
class ExplainSimplyDialog extends StatefulWidget {
  final String topic;
  final String? subtopic;
  final String sourceContext;
  final int? sourcePage;
  final String? wrongOptionChosen;

  const ExplainSimplyDialog({
    super.key,
    required this.topic,
    this.subtopic,
    required this.sourceContext,
    this.sourcePage,
    this.wrongOptionChosen,
  });

  static Future<void> show({
    required BuildContext context,
    required String topic,
    String? subtopic,
    required String sourceContext,
    int? sourcePage,
    String? wrongOptionChosen,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
          child: ExplainSimplyDialog(
            topic: topic,
            subtopic: subtopic,
            sourceContext: sourceContext,
            sourcePage: sourcePage,
            wrongOptionChosen: wrongOptionChosen,
          ),
        ),
      ),
    );
  }

  @override
  State<ExplainSimplyDialog> createState() => _ExplainSimplyDialogState();
}

class _ExplainSimplyDialogState extends State<ExplainSimplyDialog> {
  String _selectedLevel = 'beginner'; // 'like_im_10', 'beginner', 'intermediate', 'exam_ready'
  String _selectedLanguage = 'en'; // 'en', 'hi'
  int _seedVariant = 0;
  bool _isLoading = true;
  SimpleExplanation? _explanation;

  bool _showMcqAnswer = false;
  bool _showShortAnswer = false;

  @override
  void initState() {
    super.initState();
    _loadExplanation();
  }

  Future<void> _loadExplanation() async {
    setState(() => _isLoading = true);
    final result = await ExplainSimplyService.instance.generateExplanation(
      topic: widget.topic,
      subtopic: widget.subtopic,
      sourceContext: widget.sourceContext,
      sourcePage: widget.sourcePage,
      targetAudience: _selectedLevel,
      language: _selectedLanguage,
      wrongOptionChosen: widget.wrongOptionChosen,
      seedVariant: _seedVariant,
    );
    if (mounted) {
      setState(() {
        _explanation = result;
        _isLoading = false;
        _showMcqAnswer = false;
        _showShortAnswer = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.subtopic != null ? '${widget.topic} • ${widget.subtopic}' : widget.topic;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Scaffold(
        backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FBF9),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        leading: const Icon(Icons.psychology_rounded, color: AppTheme.primaryColor),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💡 Explain This Simply',
              style: TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Bar: Level Selector, Language Toggle, Explain Differently
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFDFB),
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Level selector
                Wrap(
                  spacing: 6,
                  children: [
                    _buildLevelPill('🧒 Like I\'m 10', 'like_im_10'),
                    _buildLevelPill('🌱 Beginner', 'beginner'),
                    _buildLevelPill('🌿 Intermediate', 'intermediate'),
                    _buildLevelPill('🎓 Exam-Ready', 'exam_ready'),
                  ],
                ),

                // Controls: Hinglish & Explain Differently
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() => _selectedLanguage = _selectedLanguage == 'en' ? 'hi' : 'en');
                        _loadExplanation();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _selectedLanguage == 'hi' ? AppTheme.primaryLight : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _selectedLanguage == 'hi' ? AppTheme.primaryColor : AppTheme.borderColor),
                        ),
                        child: Text(
                          _selectedLanguage == 'hi' ? '🇮🇳 Hinglish Active' : 'English',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _selectedLanguage == 'hi' ? AppTheme.primaryColor : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('New Analogy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() => _seedVariant++);
                        _loadExplanation();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Explanation Scroll View
          Expanded(
            child: _isLoading || _explanation == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryColor),
                        SizedBox(height: 12),
                        Text('Crafting simplified grounded explanation...', style: TextStyle(fontFamily: 'serif', fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Inline tailored mistake banner (if triggered by a wrong answer in practice)
                        if (_explanation!.tailoredMistakeNote != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFFD54F)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.tips_and_updates_outlined, size: 18, color: Color(0xFFF57F17)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _explanation!.tailoredMistakeNote!,
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF4E342E), height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Part 1: The Idea in One Plain Sentence
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7F4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFB8D7C2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.bolt_rounded, size: 18, color: AppTheme.primaryColor),
                                  SizedBox(width: 6),
                                  Text(
                                    '1. The Big Idea in Plain Words',
                                    style: TextStyle(fontFamily: 'serif', fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _explanation!.plainIdea,
                                style: const TextStyle(fontFamily: 'serif', fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Part 2: Real-Life Analogy
                        _buildSectionCard(
                          title: '2. Real-Life School Analogy',
                          icon: Icons.auto_stories_rounded,
                          accentColor: const Color(0xFF00796B),
                          content: Text(
                            _explanation!.analogy,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.45),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Part 3: Step-by-Step Breakdown
                        _buildSectionCard(
                          title: '3. Step-by-Step Breakdown',
                          icon: Icons.format_list_numbered_rounded,
                          accentColor: AppTheme.primaryColor,
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _explanation!.stepByStep.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                  Expanded(
                                    child: Text(s, style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.4)),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Part 4: Tiny Worked Example
                        _buildSectionCard(
                          title: '4. Concrete Worked Example / Scenario',
                          icon: Icons.terminal_rounded,
                          accentColor: const Color(0xFF5E35B1),
                          content: Text(
                            _explanation!.workedExample,
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Part 5: Common Confusion
                        _buildSectionCard(
                          title: '5. Common Mistakes Students Make',
                          icon: Icons.warning_amber_rounded,
                          accentColor: const Color(0xFFC62828),
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _explanation!.commonConfusions.map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('⚠️ $c', style: const TextStyle(fontSize: 12.5, color: Color(0xFFB71C1C), height: 1.35)),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Part 6: Memory Trick / Mnemonic
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E5F5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCE93D8)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.psychology_alt_rounded, size: 20, color: Color(0xFF6A1B9A)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '6. Remember It Like This: ${_explanation!.mnemonic}',
                                  style: const TextStyle(fontFamily: 'serif', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4A148C)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Part 7: Two-Question Mini Check
                        const Row(
                          children: [
                            Icon(Icons.quiz_rounded, size: 18, color: AppTheme.primaryColor),
                            SizedBox(width: 6),
                            Text(
                              '7. Quick Check: Did you get it?',
                              style: TextStyle(fontFamily: 'serif', fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Mini-Check 1 (MCQ)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Q1 (MCQ): ${_explanation!.miniCheckMcq.question}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              if (_explanation!.miniCheckMcq.options != null) ...[
                                const SizedBox(height: 6),
                                ..._explanation!.miniCheckMcq.options!.asMap().entries.map((opt) {
                                  final letter = String.fromCharCode(65 + opt.key);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text('  $letter) ${opt.value}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  );
                                }),
                              ],
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => setState(() => _showMcqAnswer = !_showMcqAnswer),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _showMcqAnswer ? AppTheme.primaryLight : const Color(0xFFF0F4F2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _showMcqAnswer ? 'Hide Answer: ${_explanation!.miniCheckMcq.answer}' : '👁️ Tap to Reveal Answer',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Mini-Check 2 (Short Question)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Q2 (Short): ${_explanation!.miniCheckShort.question}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => setState(() => _showShortAnswer = !_showShortAnswer),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _showShortAnswer ? AppTheme.primaryLight : const Color(0xFFF0F4F2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _showShortAnswer ? 'Hide Answer: ${_explanation!.miniCheckShort.answer}' : '👁️ Tap to Reveal Answer',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Grounding Source Tag
                        if (_explanation!.sourcePage != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Grounded in uploaded material [Page ${_explanation!.sourcePage}]',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontFamily: 'serif', fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildLevelPill(String label, String level) {
    final isSelected = _selectedLevel == level;
    return InkWell(
      onTap: () {
        setState(() => _selectedLevel = level);
        _loadExplanation();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
