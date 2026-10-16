import 'dart:async';
import 'package:flutter/material.dart';
import 'package:studymate_classroom/models/question_model.dart';
import 'package:studymate_classroom/models/user_model.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/utils/constants.dart';
import 'package:studymate_classroom/utils/validators.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';

/// Tab enabling teachers to view questions and author new questions under any topic.
class TeacherQuestionBankTab extends StatefulWidget {
  final User currentUser;

  const TeacherQuestionBankTab({super.key, required this.currentUser});

  @override
  State<TeacherQuestionBankTab> createState() => _TeacherQuestionBankTabState();
}

class _TeacherQuestionBankTabState extends State<TeacherQuestionBankTab> {
  String _selectedTopic = 'All Topics';
  StreamSubscription? _questionsSub;
  List<Question> _questions = [];
  bool _isLoading = true;
  bool _isFromCache = false;

  @override
  void initState() {
    super.initState();
    _seedAndSubscribe();
  }

  Future<void> _seedAndSubscribe() async {
    await FirestoreService.instance.seedInitialQuestions(widget.currentUser.id);
    _subscribeQuestions();
  }

  void _subscribeQuestions() {
    _questionsSub?.cancel();
    setState(() => _isLoading = true);

    _questionsSub = FirestoreService.instance
        .getQuestionsStream(topic: _selectedTopic == 'All Topics' ? null : _selectedTopic)
        .listen(
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

  void _showAddQuestionDialog() {
    final formKey = GlobalKey<FormState>();
    final questionController = TextEditingController();
    final answerController = TextEditingController();
    String topic = AppConstants.academicTopics.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => CustomDialog(
          title: 'Author New Question',
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Topic',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: topic,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: AppConstants.academicTopics
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => topic = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: questionController,
                    label: 'Question',
                    hintText: 'Type the practice question here...',
                    maxLines: 3,
                    validator: (v) => Validators.validateRequired(v, 'Question'),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: answerController,
                    label: 'Verified Answer / Solution',
                    hintText: 'Provide the complete explanation and answer...',
                    maxLines: 5,
                    validator: (v) => Validators.validateRequired(v, 'Answer'),
                  ),
                ],
              ),
            ),
          ),
          confirmText: 'Publish Question',
          onConfirm: () async {
            if (!formKey.currentState!.validate()) return;
            final messenger = ScaffoldMessenger.of(context);
            try {
              await FirestoreService.instance.createQuestion(
                topic: topic,
                question: questionController.text,
                answer: answerController.text,
                createdBy: widget.currentUser.id,
              );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Question published successfully!'), backgroundColor: Colors.green),
                );
              }
            } catch (e) {
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorColor),
                );
              }
            }
          },
        ),
      ),
    );
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
            // Topic Filter Selector
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter by Topic', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTopic,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: ['All Topics', ...AppConstants.academicTopics]
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.indigo.shade50,
              child: Text(
                'Total Questions: ${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
              ),
            ),
            // Questions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _questions.isEmpty
                      ? Center(
                          child: EmptyState(
                            icon: Icons.quiz_outlined,
                            title: 'No Questions Found',
                            message: 'Tap "Add Question" below to publish practice problems for students.',
                            actionText: 'Add Question',
                            onAction: _showAddQuestionDialog,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _questions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final q = _questions[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        q.topic,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo.shade900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      q.question,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Text(
                                        q.answer,
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
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
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
        onPressed: _showAddQuestionDialog,
      ),
    );
  }
}
