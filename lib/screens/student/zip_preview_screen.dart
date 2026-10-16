import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:studymate_classroom/models/subject_model.dart';
import 'package:studymate_classroom/services/firestore_service.dart';
import 'package:studymate_classroom/services/zip_import_parser.dart';
import 'package:studymate_classroom/utils/app_theme.dart';
import 'package:studymate_classroom/widgets/custom_dialog.dart';
import 'package:studymate_classroom/widgets/custom_text_field.dart';
import 'package:studymate_classroom/widgets/primary_button.dart';

/// Screen displaying a pre-commit preview tree of detected subjects and units from a ZIP.
/// No disk writes or Firestore writes happen until the student confirms.
class ZipPreviewScreen extends StatefulWidget {
  final String userId;
  final String fileName;
  final int fileSizeBytes;
  final List<int> zipBytes;

  const ZipPreviewScreen({
    super.key,
    required this.userId,
    required this.fileName,
    required this.fileSizeBytes,
    required this.zipBytes,
  });

  @override
  State<ZipPreviewScreen> createState() => _ZipPreviewScreenState();
}

class _ZipPreviewScreenState extends State<ZipPreviewScreen> {
  ZipParseResult? _parseResult;
  bool _isParsing = true;
  String? _parseError;

  bool _isSaving = false;
  bool _isReplaceMode = false; // Merge by default

  @override
  void initState() {
    super.initState();
    _runParse();
  }

  Future<void> _runParse() async {
    setState(() {
      _isParsing = true;
      _parseError = null;
    });

    try {
      // Execute pure parser in background isolate
      final result = await compute(_parseInIsolate, widget.zipBytes);
      if (mounted) {
        setState(() {
          _parseResult = result;
          _isParsing = false;
        });

        if (result.requiresSubjectNamePrompt) {
          _promptSubjectName();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _parseError = e.toString();
          _isParsing = false;
        });
      }
    }
  }

  static ZipParseResult _parseInIsolate(List<int> bytes) {
    return ZipImportParser.parse(bytes);
  }

  void _promptSubjectName() {
    final controller = TextEditingController(text: 'General Studies');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CustomDialog(
        title: 'Subject Name Required',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Files were found at the root of the ZIP without a subject folder. Please name the subject for these materials:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: controller,
              label: 'Subject Name',
              hintText: 'e.g. Computer Science',
            ),
          ],
        ),
        confirmText: 'Continue',
        onConfirm: () {
          final name = controller.text.trim();
          if (name.isNotEmpty) {
            Navigator.of(ctx).pop();
            _renameSubjectAt(0, name);
          }
        },
      ),
    );
  }

  void _renameSubjectAt(int index, String newName) {
    if (_parseResult == null) return;
    final updatedList = List<ParsedSubject>.from(_parseResult!.subjects);
    updatedList[index] = updatedList[index].copyWith(name: newName);
    setState(() {
      _parseResult = _parseResult!.copyWith(subjects: updatedList);
    });
  }

  void _showRenameDialog(int index, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Rename Subject',
        content: CustomTextField(
          controller: controller,
          label: 'Subject Name',
          hintText: 'Enter subject name',
        ),
        confirmText: 'Save',
        onConfirm: () {
          final name = controller.text.trim();
          if (name.isNotEmpty) {
            Navigator.of(ctx).pop();
            _renameSubjectAt(index, name);
          }
        },
      ),
    );
  }

  Future<void> _confirmImport() async {
    if (_parseResult == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final summary = await FirestoreService.instance.saveImportedCurriculum(
        userId: widget.userId,
        parseResult: _parseResult!,
        appDocumentsDirectory: docDir.path,
        isReplaceMode: _isReplaceMode,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        _showSuccessDialog(summary);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog(({int notesCount, int practicalsCount, int skippedCount, int subjectsCount, int unitsCount}) summary) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CustomDialog(
        title: 'Import Complete! 🎉',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully imported ${summary.subjectsCount} subjects, ${summary.unitsCount} units, ${summary.notesCount} lecture notes, and ${summary.practicalsCount} practicals.',
              style: const TextStyle(fontSize: 14),
            ),
            if (summary.skippedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '(${summary.skippedCount} existing or unsupported files skipped)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        confirmText: 'View in Library',
        onConfirm: () {
          Navigator.of(ctx).pop(); // Dismiss dialog
          Navigator.of(context).pop(true); // Return to library with success
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizeKb = (widget.fileSizeBytes / 1024).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Preview ZIP Contents'),
      ),
      body: SafeArea(
        child: _isParsing
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing and parsing ZIP archive...', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            : _parseError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          const Text('Failed to parse ZIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(_parseError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                          const SizedBox(height: 20),
                          PrimaryButton(text: 'Close', onPressed: () => Navigator.of(context).pop()),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // File header
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.folder_zip_outlined, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.fileName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$sizeKb KB',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Detected ${_parseResult!.totalSubjects} Subjects, ${_parseResult!.totalUnits} Units, ${_parseResult!.totalNotes} Notes, ${_parseResult!.totalPracticals} Practicals',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                            ),
                            const Divider(height: 20),
                            // Merge vs Replace mode selector
                            Row(
                              children: [
                                const Text('Existing Subjects:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                ChoiceChip(
                                  label: const Text('Merge', style: TextStyle(fontSize: 12)),
                                  selected: !_isReplaceMode,
                                  onSelected: (val) => setState(() => _isReplaceMode = !val),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Replace', style: TextStyle(fontSize: 12)),
                                  selected: _isReplaceMode,
                                  onSelected: (val) => setState(() => _isReplaceMode = val),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Expandable tree
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _parseResult!.subjects.length,
                          itemBuilder: (context, subIdx) {
                            final sub = _parseResult!.subjects[subIdx];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ExpansionTile(
                                leading: const Icon(Icons.school_outlined, color: AppTheme.primaryColor),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sub.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Rename Subject',
                                      onPressed: () => _showRenameDialog(subIdx, sub.name),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${sub.units.length} Units • ${sub.totalNotes} Notes • ${sub.totalPracticals} Practicals',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                children: sub.units.map((unit) {
                                  return ListTile(
                                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                                    leading: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      child: Text(
                                        '${unit.number}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                      ),
                                    ),
                                    title: Text(
                                      'Unit ${unit.number}: ${unit.title}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      '${unit.notes.length} Notes, ${unit.practicals.length} Practicals${unit.questions.isNotEmpty ? ', ${unit.questions.length} Questions' : ''}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                      // Bottom confirmation bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: PrimaryButton(
                                text: _isSaving ? 'Extracting...' : 'Confirm Import',
                                isLoading: _isSaving,
                                icon: Icons.check,
                                onPressed: _confirmImport,
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
