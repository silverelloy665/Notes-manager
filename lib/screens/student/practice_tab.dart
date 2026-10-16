import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/constants.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';

/// Tab enabling students to select academic topics and practice with tap-to-reveal question cards.
class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  String _selectedTopic = AppConstants.academicTopics.first;
  StreamSubscription? _questionsSub;
  List<Question> _questions = [];
  bool _isLoading = true;
  bool _isFromCache = false;

  @override
  void initState() {
    super.initState();
    _subscribeQuestions();
  }

  void _subscribeQuestions() {
    _questionsSub?.cancel();
    setState(() => _isLoading = true);

    _questionsSub = FirestoreService.instance.getQuestionsStream(topic: _selectedTopic).listen(
      (data) {
        if (mounted) {
          setState(() {
            _questions = data.questions;
            _isFromCache = data.isFromCache;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load questions: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _questionsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            if (_isFromCache)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.orange.shade800,
                child: const Text(
                  'Offline, will sync',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            // Topic Selector Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Academic Topic',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTopic,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: AppConstants.academicTopics
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedTopic) {
                        setState(() => _selectedTopic = val);
                        _subscribeQuestions();
                      }
                    },
                  ),
                ],
              ),
            ),
            // Questions Count Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.indigo.shade50,
              child: Row(
                children: [
                  const Icon(Icons.psychology_outlined, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Practice Questions: ${_questions.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
            // Question Cards List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _questions.isEmpty
                      ? Center(
                          child: EmptyState(
                            icon: Icons.quiz_outlined,
                            title: 'No Questions Found',
                            message: 'No practice questions have been authored for $_selectedTopic yet.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _questions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            return _PracticeQuestionItem(
                              index: index + 1,
                              question: _questions[index],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeQuestionItem extends StatefulWidget {
  final int index;
  final Question question;

  const _PracticeQuestionItem({
    required this.index,
    required this.question,
  });

  @override
  State<_PracticeQuestionItem> createState() => _PracticeQuestionItemState();
}

class _PracticeQuestionItemState extends State<_PracticeQuestionItem> {
  bool _isAnswerRevealed = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    '${widget.index}',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.question.question,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isAnswerRevealed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                        SizedBox(width: 6),
                        Text(
                          'Verified Answer:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.question.answer,
                      style: TextStyle(fontSize: 13, color: Colors.green.shade900, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility_off_outlined, size: 16),
                  label: const Text('Hide Answer', style: TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _isAnswerRevealed = false),
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Tap to reveal answer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => setState(() => _isAnswerRevealed = true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
