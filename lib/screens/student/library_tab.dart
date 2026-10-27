import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:studymate_classroom/models/subject_model.dart';
import 'package:studymate_classroom/screens/student/subject_units_screen.dart';
import 'package:studymate_classroom/screens/student/zip_preview_screen.dart';
import 'package:studymate_classroom/services/document_processing_service.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/services/notes_ai_service.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/utils/validators.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';
import 'package:studymate_classroom/widgets/watercolor_blob_container.dart';

/// Main Library tab on the Student Home Screen.
class LibraryTab extends StatefulWidget {
  final String userId;

  const LibraryTab({
    super.key,
    required this.userId,
  });

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  StreamSubscription? _subjectsSub;
  List<Subject> _subjects = [];
  bool _isLoading = true;
  bool _isFromCache = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _appDocDirPath;

  @override
  void initState() {
    super.initState();
    _initDocDir();
    _subscribeSubjects();
  }

  Future<void> _initDocDir() async {
    final dir = await getApplicationDocumentsDirectory();
    if (mounted) {
      setState(() => _appDocDirPath = dir.path);
    }
  }

  void _subscribeSubjects() {
    _subjectsSub = FirestoreService.instance.getSubjectsStream(widget.userId).listen((data) {
      if (mounted) {
        setState(() {
          _subjects = data.subjects;
          _isFromCache = data.isFromCache;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subjectsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndImportZip() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result.isEmpty) return;

      final pickedFile = result.first;
      final fileName = pickedFile.name;
      final sizeInBytes = (pickedFile.lengthSync() ?? await pickedFile.length()) ?? 0;

      // Validate ZIP
      final valErr = Validators.validateZipFile(fileName: fileName, sizeInBytes: sizeInBytes);
      if (valErr != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(valErr), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final bytes = await pickedFile.readAsBytes();

      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read ZIP file data.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (!mounted) return;

      // Navigate to PREVIEW screen before saving
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ZipPreviewScreen(
            userId: widget.userId,
            fileName: fileName,
            fileSizeBytes: sizeInBytes,
            zipBytes: bytes,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickAndImportPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty) return;

      final pickedFile = result.first;
      final fileName = pickedFile.name;
      final sizeInBytes = (pickedFile.lengthSync() ?? await pickedFile.length()) ?? 0;
      final bytes = await pickedFile.readAsBytes();

      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read PDF file data.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Extracting PDF & generating practice questions...')),
            ],
          ),
        ),
      );

      final doc = await DocumentProcessingService.instance.processBytes(
        bytes: bytes,
        fileName: fileName,
      );

      final aiResult = await NotesAiService.instance.processDocument(doc);

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
      }

      final parsedQuestions = aiResult.practiceQuestions
          .map((q) => ParsedQuestion(question: q.question, answer: q.answer))
          .toList();

      final parsedFile = ParsedFile(
        name: fileName,
        type: 'note',
        fileType: 'pdf',
        relativePath: '${aiResult.topic}/Unit 1 - ${aiResult.title}/notes/$fileName',
        bytes: bytes,
        sizeBytes: sizeInBytes,
      );

      final parsedUnit = ParsedUnit(
        number: 1,
        title: aiResult.title,
        notes: [parsedFile],
        practicals: [],
        questions: parsedQuestions,
      );

      final parsedSubject = ParsedSubject(
        name: aiResult.topic,
        units: [parsedUnit],
      );

      final parseResult = ZipParseResult(
        subjects: [parsedSubject],
        skippedFiles: [],
        errors: [],
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ZipPreviewScreen(
            userId: widget.userId,
            fileName: fileName,
            fileSizeBytes: sizeInBytes,
            zipBytes: const [],
            preParsedResult: parseResult,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('How to Prepare Your ZIP', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Organize your study material into the following directory structure inside your .zip archive:',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              SelectableText(
                '<Subject Name>/\n'
                '  Unit 1 - <Unit Title>/\n'
                '    notes/        (.pdf, .txt, .md, images)\n'
                '    practicals/   (.java, .cpp, .py, .sql, .c)\n'
                '    questions.json (optional)\n'
                '  Unit 2 - .../',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  backgroundColor: Color(0xFFF1F3F5),
                ),
              ),
              SizedBox(height: 12),
              Text(
                '• Practicals: Any file inside a "practicals" or "lab" folder, or with code extensions (.java, .cpp, .c, .py, .sql) is automatically marked as a Practical.\n'
                '• Questions: Optional questions.json per unit with [{"question": "...", "answer": "..."}] will be added to your Practice Question Bank!\n'
                '• Max Limit: 100 MB and up to 2000 files.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  void _renameSubject(Subject subject) {
    final controller = TextEditingController(text: subject.name);
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Rename Subject',
        content: CustomTextField(
          controller: controller,
          label: 'Subject Name',
          hintText: 'Enter new subject name',
        ),
        confirmText: 'Save',
        onConfirm: () async {
          final newName = controller.text.trim();
          if (newName.isEmpty) return;
          try {
            await FirestoreService.instance.renameSubject(
              widget.userId,
              subject.id,
              newName,
            );
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subject renamed successfully.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  void _deleteSubject(Subject subject) {
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Delete Subject',
        content: Text(
          'Are you sure you want to delete "${subject.name}"? This removes all associated units, files, and local storage data.',
        ),
        confirmText: 'Delete',
        confirmColor: Colors.red,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          try {
            final localPath = _appDocDirPath != null
                ? p.join(_appDocDirPath!, 'library', widget.userId, subject.name)
                : '';
            await FirestoreService.instance.deleteSubject(
              widget.userId,
              subject.id,
              localSubjectPath: localPath,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subject deleted.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final filtered = _subjects.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkSlateBase : AppTheme.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Search and help header that scrolls up
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: isDark ? const Color(0xFFE8F5E9) : AppTheme.charcoalSlate),
                        decoration: InputDecoration(
                          hintText: 'Search subjects or material...',
                          hintStyle: TextStyle(color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textMuted),
                          prefixIcon: Icon(Icons.search, size: 20, color: isDark ? AppTheme.darkLightGreen : AppTheme.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 18, color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.help_outline),
                      tooltip: 'How to prepare your ZIP',
                      onPressed: _showHelpDialog,
                    ),
                  ],
                ),
              ),
            ),
            if (_isFromCache)
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.orange.shade800,
                  child: const Text(
                    'Offline, will sync changes when reconnected',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            // Subjects list or empty state
            if (_isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: isDark ? AppTheme.darkLightGreen : AppTheme.primaryColor)),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: EmptyState(
                    icon: Icons.library_books_outlined,
                    title: _searchQuery.isNotEmpty ? 'No Matching Subjects' : 'Your Library is Empty',
                    message: _searchQuery.isNotEmpty
                        ? 'No subjects matched "$_searchQuery".'
                        : 'Tap "Import ZIP" below to load your lecture notes and practical code archives.',
                    actionText: _searchQuery.isNotEmpty ? 'Clear Search' : 'Import ZIP Archive',
                    onAction: _searchQuery.isNotEmpty
                        ? () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          }
                        : _pickAndImportZip,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final subject = filtered[index];
                    final progress = subject.totalUnits == 0
                        ? 0.0
                        : (subject.completedUnits / subject.totalUnits);

                    return WatercolorBlobContainer(
                      variant: BlobVariant.sageSoft,
                      padding: const EdgeInsets.all(16.0),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SubjectUnitsScreen(
                              userId: widget.userId,
                              subject: subject,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.school_outlined, color: isDark ? AppTheme.darkLightGreen : AppTheme.inkForest),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  subject.name,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontCardo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.5,
                                    color: isDark ? const Color(0xFFE8F5E9) : AppTheme.inkForest,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'rename') _renameSubject(subject);
                                  if (val == 'delete') _deleteSubject(subject);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${subject.totalUnits} Units (${subject.completedUnits} completed)',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontZilla,
                                  fontSize: 12.5,
                                  color: isDark ? const Color(0xFFA5D6A7) : AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontZilla,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.darkLightGreen : AppTheme.inkForest,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: isDark ? const Color(0xFF2E4D38) : AppTheme.mintWash.withValues(alpha: 0.4),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? AppTheme.darkLightGreen : AppTheme.inkForest,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = MediaQuery.of(context).size.width < 500;
          if (isMobile) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'library_pdf_import',
                  tooltip: 'Import PDF',
                  backgroundColor: AppTheme.mintWash,
                  foregroundColor: AppTheme.inkForest,
                  onPressed: _pickAndImportPdf,
                  child: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'library_zip_import',
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Import ZIP'),
                  onPressed: _pickAndImportZip,
                ),
              ],
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: 'library_pdf_import',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Import PDF'),
                backgroundColor: AppTheme.secondaryColor,
                onPressed: _pickAndImportPdf,
              ),
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                heroTag: 'library_zip_import',
                icon: const Icon(Icons.unarchive_outlined),
                label: const Text('Import ZIP'),
                onPressed: _pickAndImportZip,
              ),
            ],
          );
        },
      ),
    );
  }
}
