import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/note_model.dart';
import 'package:studymate_classroom/models/summary_model.dart';
import 'package:studymate_classroom/models/topic_map_model.dart';
import 'package:studymate_classroom/services/notes_ai_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/explain_simply_dialog.dart';
import 'package:studymate_classroom/widgets/numbered_three_column_layout.dart';
import 'package:studymate_classroom/widgets/watercolor_blob_container.dart';

/// Full interactive viewer for Smarter Summarization (Workstream A).
/// Includes 7 distinct study formats:
/// - (a) One-line TL;DR
/// - (b) 5-8 bullet Key Points
/// - (c) Detailed section-by-section breakdown
/// - (d) Exam cheat sheet (definitions, formulas, key terms, must remember, common mistakes)
/// - (e) Glossary of terms
/// - (f) Q&A Summary (5 teacher questions)
/// - (g) Visual Mind Map
/// - "Show Source" toggle ([p. X] references)
/// - Controls: "Make shorter", "Add more detail", "Focus on topic"
/// - One-click actions: Summary -> Flashcards, Summary -> Practice Questions/MCQs
class SmartSummaryViewer extends StatefulWidget {
  final Note note;
  final MultiLevelSummary? initialSummary;
  final TopicMap? topicMap;
  final VoidCallback onOpenFlashcards;
  final VoidCallback onOpenQuiz;
  final Function(String newMarkdownContent)? onContentUpdated;

  const SmartSummaryViewer({
    super.key,
    required this.note,
    this.initialSummary,
    this.topicMap,
    required this.onOpenFlashcards,
    required this.onOpenQuiz,
    this.onContentUpdated,
  });

  @override
  State<SmartSummaryViewer> createState() => _SmartSummaryViewerState();
}

enum _SummaryTab { tldr, keyPoints, sections, cheatSheet, glossary, qaSummary, mindMap }

class _SmartSummaryViewerState extends State<SmartSummaryViewer> {
  _SummaryTab _currentTab = _SummaryTab.tldr;
  bool _showSources = true;
  bool _isRegenerating = false;
  late MultiLevelSummary _summary;

  // Regeneration Options
  String _selectedTone = 'academic'; // 'academic', 'simple'
  String _selectedLength = 'detailed'; // 'concise', 'detailed', 'comprehensive'
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    if (widget.initialSummary != null) {
      _summary = widget.initialSummary!;
    } else {
      _summary = _buildInitialFallback(widget.note);
      _loadSmartSummary();
    }
    _selectedTone = _summary.tone;
    _selectedLength = _summary.length;
    _selectedLanguage = _summary.language;
  }

  MultiLevelSummary _buildInitialFallback(Note note) {
    final sentences = note.content.split('\n').where((l) => l.trim().isNotEmpty && !l.startsWith('#')).toList();
    return MultiLevelSummary(
      documentTitle: note.title,
      topic: note.topic,
      tldr: sentences.isNotEmpty
          ? sentences.first
          : 'High-yield academic study review for ${note.title} (${note.topic}).',
      keyPoints: sentences.length >= 5
          ? sentences.take(5).toList()
          : [
              'Detailed conceptual overview of ${note.topic}.',
              'Key algorithmic and theoretical mechanisms.',
              'Core analytical trade-offs and performance criteria.',
              'Critical terms, formulas, and definitions.',
              'High-yield preparation points for exam success.',
            ],
      sections: [
        SectionSummary(
          title: note.title,
          sourcePage: 1,
          content: sentences.isNotEmpty ? sentences.first : 'Overview of ${note.topic}.',
          bulletPoints: sentences.skip(1).take(4).toList(),
        ),
      ],
      cheatSheet: const ExamCheatSheet(),
      glossary: const {},
      mindMapMermaid: 'graph TD\n  Root["${note.topic}: ${note.title}"]',
    );
  }

  Future<void> _loadSmartSummary() async {
    try {
      final summary = await NotesAiService.instance.generateSmartMultiLevelSummary(
        title: widget.note.title,
        topic: widget.note.topic,
        text: widget.note.content,
        topicMap: widget.topicMap,
        tone: _selectedTone,
        length: _selectedLength,
        language: _selectedLanguage,
      );
      if (mounted) {
        setState(() => _summary = summary);
      }
    } catch (_) {}
  }

  Future<void> _regenerateSummary({
    required String length,
    required String tone,
    required String language,
  }) async {
    setState(() => _isRegenerating = true);
    try {
      final updated = await NotesAiService.instance.generateSmartMultiLevelSummary(
        title: widget.note.title,
        topic: widget.note.topic,
        text: widget.note.content,
        topicMap: widget.topicMap,
        tone: tone,
        length: length,
        language: language,
      );

      if (mounted) {
        setState(() {
          _summary = updated;
          _selectedLength = length;
          _selectedTone = tone;
          _selectedLanguage = language;
          _isRegenerating = false;
        });
        widget.onContentUpdated?.call(updated.toMarkdown(includeSources: _showSources));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showRegenerateDialog() {
    String tempLength = _selectedLength;
    String tempTone = _selectedTone;
    String tempLang = _selectedLanguage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.tune_rounded, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  'Customize Summary',
                  style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Summary Depth & Length:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Concise (TL;DR)'),
                      selected: tempLength == 'concise',
                      onSelected: (val) => setModalState(() => tempLength = 'concise'),
                    ),
                    ChoiceChip(
                      label: const Text('Detailed'),
                      selected: tempLength == 'detailed',
                      onSelected: (val) => setModalState(() => tempLength = 'detailed'),
                    ),
                    ChoiceChip(
                      label: const Text('Comprehensive'),
                      selected: tempLength == 'comprehensive',
                      onSelected: (val) => setModalState(() => tempLength = 'comprehensive'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Explanatory Tone:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Academic & Formal'),
                      selected: tempTone == 'academic',
                      onSelected: (val) => setModalState(() => tempTone = 'academic'),
                    ),
                    ChoiceChip(
                      label: const Text('Simple & Intuitive'),
                      selected: tempTone == 'simple',
                      onSelected: (val) => setModalState(() => tempTone = 'simple'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Language:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: tempLang,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English (Original)')),
                    DropdownMenuItem(value: 'es', child: Text('Spanish (Español)')),
                    DropdownMenuItem(value: 'fr', child: Text('French (Français)')),
                    DropdownMenuItem(value: 'de', child: Text('German (Deutsch)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => tempLang = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Apply & Regenerate'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _regenerateSummary(length: tempLength, tone: tempTone, language: tempLang);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRegenerating) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              SizedBox(height: 16),
              Text(
                'Regenerating smart multi-level summary...',
                style: TextStyle(fontFamily: 'serif', fontSize: 14, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Row: One-Click Actions, Source Toggle, Regenerate Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F7F4),
            border: Border(bottom: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.6))),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // One-Click Action Badges
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.style_rounded, size: 14),
                    label: const Text('🎴 Flashcards', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: widget.onOpenFlashcards,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.secondaryColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.quiz_outlined, size: 14),
                    label: const Text('🎓 Quiz / Exam', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: widget.onOpenQuiz,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: _currentTab == _SummaryTab.mindMap ? AppTheme.primaryLight : Colors.white,
                    ),
                    icon: const Icon(Icons.account_tree_outlined, size: 14),
                    label: const Text('🗺️ Mind Map', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: () => setState(() => _currentTab = _SummaryTab.mindMap),
                  ),
                ],
              ),

              // Source Toggle & Customize / Regenerate Options
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show Source references toggle
                  InkWell(
                    onTap: () => setState(() => _showSources = !_showSources),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _showSources ? AppTheme.primaryLight : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _showSources ? AppTheme.primaryColor : AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showSources ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            size: 13,
                            color: _showSources ? AppTheme.primaryColor : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Show Sources [p.]',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _showSources ? FontWeight.bold : FontWeight.normal,
                              color: _showSources ? AppTheme.primaryColor : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Regenerate Button
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 18, color: AppTheme.primaryColor),
                    tooltip: 'Customize & Regenerate Summary',
                    onPressed: _showRegenerateDialog,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Multi-Level Tab Bar (7 formats)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildTabPill('⚡ TL;DR', _SummaryTab.tldr),
              const SizedBox(width: 6),
              _buildTabPill('🔑 Key Points (${_summary.keyPoints.length})', _SummaryTab.keyPoints),
              const SizedBox(width: 6),
              _buildTabPill('📖 Section Deep Dive (${_summary.sections.length})', _SummaryTab.sections),
              const SizedBox(width: 6),
              _buildTabPill('📝 Exam Cheat Sheet', _SummaryTab.cheatSheet),
              const SizedBox(width: 6),
              _buildTabPill('📚 Glossary (${_summary.glossary.length})', _SummaryTab.glossary),
              const SizedBox(width: 6),
              _buildTabPill('❓ Teacher Q&A (${_summary.qaSummary.length})', _SummaryTab.qaSummary),
              const SizedBox(width: 6),
              _buildTabPill('🗺️ Mind Map', _SummaryTab.mindMap),
            ],
          ),
        ),

        // Tab Content
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: _buildCurrentTabContent(),
        ),
      ],
    );
  }

  Widget _buildTabPill(String label, _SummaryTab tab) {
    final isSelected = _currentTab == tab;
    return InkWell(
      onTap: () => setState(() => _currentTab = tab),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentTab) {
      case _SummaryTab.tldr:
        return _buildTldrTab();
      case _SummaryTab.keyPoints:
        return _buildKeyPointsTab();
      case _SummaryTab.sections:
        return _buildSectionsTab();
      case _SummaryTab.cheatSheet:
        return _buildCheatSheetTab();
      case _SummaryTab.glossary:
        return _buildGlossaryTab();
      case _SummaryTab.qaSummary:
        return _buildQaSummaryTab();
      case _SummaryTab.mindMap:
        return _buildMindMapTab();
    }
  }

  // (a) One-line TL;DR
  Widget _buildTldrTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WatercolorBlobContainer(
          variant: BlobVariant.creamPaper,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 20, color: AppTheme.inkForest),
                  SizedBox(width: 8),
                  Text(
                    '⚡ One-Line TL;DR Synthesis',
                    style: TextStyle(
                      fontFamily: AppTheme.fontCardo,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.inkForest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _summary.tldr,
                style: const TextStyle(
                  fontFamily: AppTheme.fontZilla,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.charcoalSlate,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (_summary.keyPoints.length >= 3) ...[
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.auto_stories_rounded, size: 16, color: AppTheme.inkForest),
              SizedBox(width: 6),
              Text(
                'Core Takeaways',
                style: TextStyle(
                  fontFamily: AppTheme.fontCardo,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.inkForest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          NumberedThreeColumnLayout(
            items: [
              NumberedColumnItem(
                stepNumber: '1',
                title: 'Core Idea',
                description: _summary.keyPoints[0],
              ),
              NumberedColumnItem(
                stepNumber: '2',
                title: 'Mechanism',
                description: _summary.keyPoints[1],
              ),
              NumberedColumnItem(
                stepNumber: '3',
                title: 'Outcome',
                description: _summary.keyPoints[2],
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.inkForest,
            side: const BorderSide(color: AppTheme.inkForest, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          icon: const Icon(Icons.psychology_outlined, size: 16),
          label: Text('💡 Explain "${widget.note.topic}" Simply (Analogy + Steps)', style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 12.5, fontWeight: FontWeight.bold)),
          onPressed: () {
            ExplainSimplyDialog.show(
              context: context,
              topic: widget.note.topic,
              sourceContext: '${_summary.tldr}\n${_summary.keyPoints.join("\n")}',
            );
          },
        ),
      ],
    );
  }

  // (b) 5-8 Bullet Key Points
  Widget _buildKeyPointsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.key_rounded, size: 18, color: AppTheme.inkForest),
            SizedBox(width: 6),
            Text(
              '🔑 High-Yield Key Points',
              style: TextStyle(
                fontFamily: AppTheme.fontCardo,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.inkForest,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._summary.keyPoints.asMap().entries.map((e) {
          return WatercolorBlobContainer(
            variant: BlobVariant.creamPaper,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.sageBlob.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.inkForest.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '${e.key + 1}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontCardo,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.inkForest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontZilla,
                      fontSize: 13.5,
                      color: AppTheme.charcoalSlate,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // (f) Teacher Q&A Summary
  Widget _buildQaSummaryTab() {
    if (_summary.qaSummary.isEmpty) {
      return const Text('No teacher Q&A summary available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.school_rounded, size: 18, color: AppTheme.primaryColor),
            SizedBox(width: 6),
            Text(
              '❓ 5 Questions a Teacher Would Most Likely Ask',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._summary.qaSummary.asMap().entries.map((e) {
          final idx = e.key;
          final qa = e.value;
          return _TeacherQuestionTile(
            index: idx + 1,
            teacherQuestion: qa,
            showSources: _showSources,
          );
        }),
      ],
    );
  }

  // (c) Detailed Section-by-Section Summary
  Widget _buildSectionsTab() {
    if (_summary.sections.isEmpty) {
      return const Text('No section breakdown available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._summary.sections.asMap().entries.map((e) {
          final idx = e.key;
          final sec = e.value;
          return WatercolorBlobContainer(
            variant: BlobVariant.creamPaper,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 16, color: AppTheme.inkForest),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${idx + 1}. ${sec.title}',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontCardo,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.inkForest,
                        ),
                      ),
                    ),
                    if (_showSources && sec.sourcePage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.sageBlob.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.inkForest.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '🍃 p. ${sec.sourcePage}',
                          style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.inkForest),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  sec.content,
                  style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13.5, color: AppTheme.charcoalSlate, height: 1.45),
                ),
                if (sec.bulletPoints.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...sec.bulletPoints.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🌱 ', style: TextStyle(fontSize: 11)),
                        Expanded(
                          child: Text(b, style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 13, color: AppTheme.textSecondary, height: 1.35)),
                        ),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.inkForest,
                      side: const BorderSide(color: AppTheme.inkForest, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 14),
                    label: const Text('Explain Simply', style: TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      ExplainSimplyDialog.show(
                        context: context,
                        topic: widget.note.topic,
                        subtopic: sec.title,
                        sourceContext: '${sec.title}\n${sec.content}\n${sec.bulletPoints.join("\n")}',
                        sourcePage: sec.sourcePage,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // (d) Exam Cheat Sheet
  Widget _buildCheatSheetTab() {
    final cs = _summary.cheatSheet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Definitions section
        if (cs.definitions.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.bookmark_added_rounded, size: 16, color: AppTheme.primaryColor),
              SizedBox(width: 6),
              Text(
                '📌 Essential Exam Definitions',
                style: TextStyle(fontFamily: 'serif', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...cs.definitions.map((d) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.4),
                        children: [
                          TextSpan(text: '${d.term}: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          TextSpan(text: d.definition),
                        ],
                      ),
                    ),
                  ),
                  if (_showSources && d.page != null) ...[
                    const SizedBox(width: 6),
                    Text('[p. ${d.page}]', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Formulas & Rules
        if (cs.formulasOrRules.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.functions_rounded, size: 16, color: Color(0xFFC2185B)),
              SizedBox(width: 6),
              Text(
                '💡 Formulas, Rules & Invariants',
                style: TextStyle(fontFamily: 'serif', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC2185B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...cs.formulasOrRules.map((f) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF48FB1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        f.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFC2185B)),
                      ),
                      const Spacer(),
                      if (_showSources && f.page != null)
                        Text('[p. ${f.page}]', style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      f.formulaOrRule,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // High Yield Tips
        if (cs.highYieldTips.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFFF57F17)),
              SizedBox(width: 6),
              Text(
                '🎯 High-Yield Exam Gotchas & Tips',
                style: TextStyle(fontFamily: 'serif', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF57F17)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...cs.highYieldTips.map((tip) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚡ ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(tip, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.35)),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // (e) Glossary
  Widget _buildGlossaryTab() {
    if (_summary.glossary.isEmpty) {
      return const Text('No glossary terms available.');
    }

    final sortedEntries = _summary.glossary.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.library_books_rounded, size: 16, color: AppTheme.primaryColor),
            SizedBox(width: 6),
            Text(
              '📚 Alphabetical Glossary of Terms',
              style: TextStyle(fontFamily: 'serif', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...sortedEntries.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    e.key,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.value,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.35),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Mind Map Visual Node Representation
  Widget _buildMindMapTab() {
    final mermaid = _summary.mindMapMermaid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.account_tree_rounded, size: 16, color: AppTheme.primaryColor),
            SizedBox(width: 6),
            Text(
              '🗺️ Interactive Topic & Concept Hierarchy',
              style: TextStyle(fontFamily: 'serif', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Visual Node Tree
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FBF9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Root node
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_summary.topic}: ${_summary.documentTitle}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              // Topic and Subtopic Nodes
              ..._summary.sections.take(8).map((sec) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('└── ', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Text(
                            '${sec.title}${_showSources && sec.sourcePage != null ? " [p. ${sec.sourcePage}]" : ""}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Mermaid Syntax Code Block
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF263238),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mermaid Graph Code:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF80CBC4)),
              ),
              const SizedBox(height: 6),
              Text(
                mermaid,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFECEFF1), height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeacherQuestionTile extends StatefulWidget {
  final int index;
  final TeacherQuestion teacherQuestion;
  final bool showSources;

  const _TeacherQuestionTile({
    required this.index,
    required this.teacherQuestion,
    required this.showSources,
  });

  @override
  State<_TeacherQuestionTile> createState() => _TeacherQuestionTileState();
}

class _TeacherQuestionTileState extends State<_TeacherQuestionTile> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final tq = widget.teacherQuestion;
    return WatercolorBlobContainer(
      variant: BlobVariant.sageSoft,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.inkForest,
                  shape: BoxShape.circle,
                ),
                child: Text('Q${widget.index}', style: const TextStyle(fontFamily: AppTheme.fontCardo, fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.creamPaper)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tq.question,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontCardo,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.inkForest,
                    height: 1.35,
                  ),
                ),
              ),
              if (widget.showSources && tq.sourcePage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.mintWash.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.inkForest.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '🍃 p. ${tq.sourcePage}',
                    style: const TextStyle(fontFamily: AppTheme.fontZilla, fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.inkForest),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (tq.expectedKeyPoints.isNotEmpty) ...[
            const Text('Expected Points to Cover:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
            const SizedBox(height: 4),
            Text(tq.expectedKeyPoints, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 8),
          if (_revealed) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Text(
                tq.answer,
                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.35),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _revealed = false),
                child: const Text('Hide Answer', style: TextStyle(fontSize: 11)),
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.borderColor),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.visibility_outlined, size: 14),
              label: const Text('Reveal Model Answer', style: TextStyle(fontSize: 11)),
              onPressed: () => setState(() => _revealed = true),
            ),
          ],
        ],
      ),
    );
  }
}
