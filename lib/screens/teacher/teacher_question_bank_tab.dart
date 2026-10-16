import 'package:flutter/material.dart';
import '../../models/question_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_exception.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_dialog.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/empty_state.dart';

/// Tab enabling teachers to view seeded questions and author new questions under any academic topic.
class TeacherQuestionBankTab extends StatefulWidget {
  final User currentUser;

  const TeacherQuestionBankTab({super.key, required this.currentUser});

  @override
  State<TeacherQuestionBankTab> createState() => _TeacherQuestionBankTabState();
}

class _TeacherQuestionBankTabState extends State<TeacherQuestionBankTab> {
  String _selectedTopic = 'All';
  List<Question> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final list = await DatabaseService.instance.getQuestions(
        topic: _selectedTopic == 'All' ? null : _selectedTopic,
      );
      if (mounted) {
        setState(() {
          _questions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load question bank: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showAddQuestionDialog() {
    final formKey = GlobalKey<FormState>();
    final questionController = TextEditingController();
    final answerController = TextEditingController();
    String topic = _selectedTopic == 'All' ? AppConstants.topics.first : _selectedTopic;
    bool dialogLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return CustomDialog(
            title: 'Add Practice Question',
            titleIcon: Icons.add_circle_outline,
            isLoading: dialogLoading,
            confirmLabel: 'Save',
            onConfirm: () async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() => dialogLoading = true);
              final messenger = ScaffoldMessenger.of(context);

              try {
                await DatabaseService.instance.addQuestion(
                  topic: topic,
                  question: questionController.text.trim(),
                  answer: answerController.text.trim(),
                  createdBy: widget.currentUser.id!,
                );

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Question successfully added to question bank!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
                _loadQuestions();
              } on AppException catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.message), backgroundColor: AppTheme.errorColor),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error adding question: $e'), backgroundColor: AppTheme.errorColor),
                  );
                }
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => dialogLoading = false);
                }
              }
            },
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select Topic',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: topic,
                    items: AppConstants.topics.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => topic = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: questionController,
                    label: 'Question',
                    hint: 'Type the practice question here...',
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    validator: (val) => Validators.validateRequired(val, 'Question'),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: answerController,
                    label: 'Verified Answer / Solution',
                    hint: 'Provide the complete explanation and answer...',
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    validator: (val) => Validators.validateRequired(val, 'Answer'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
        onPressed: _showAddQuestionDialog,
      ),
      body: Column(
        children: [
          // Topic Chip Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing, vertical: 12.0),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: const Text('All Topics'),
                      selected: _selectedTopic == 'All',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedTopic = 'All');
                          _loadQuestions();
                        }
                      },
                    ),
                  ),
                  ...AppConstants.topics.map((topic) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(topic),
                        selected: _selectedTopic == topic,
                        onSelected: (selected) {
                          setState(() => _selectedTopic = selected ? topic : 'All');
                          _loadQuestions();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderColor),

          // Questions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                    ? EmptyState(
                        icon: Icons.quiz_outlined,
                        title: 'No Questions Found',
                        message: 'Add questions under "$_selectedTopic" for your students to practice with.',
                        actionLabel: 'Add First Question',
                        onAction: _showAddQuestionDialog,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadQuestions,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppTheme.spacing),
                          itemCount: _questions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final q = _questions[index];
                            return _TeacherQuestionCard(question: q, index: index + 1);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _TeacherQuestionCard extends StatelessWidget {
  final Question question;
  final int index;

  const _TeacherQuestionCard({
    required this.question,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    question.topic,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '#$index',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              question.question,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Answer:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    question.answer,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
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
}
