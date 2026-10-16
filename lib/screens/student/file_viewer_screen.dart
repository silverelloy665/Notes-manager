import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate_classroom/models/subject_model.dart';
import 'package:studymate_classroom/widgets/empty_state.dart';

/// In-app scrollable monospace text and code viewer for practicals and notes.
class FileViewerScreen extends StatefulWidget {
  final ResourceItem resource;
  final String fullDiskPath;

  const FileViewerScreen({
    super.key,
    required this.resource,
    required this.fullDiskPath,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  String? _content;
  bool _isLoading = true;
  bool _fileMissing = false;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.fullDiskPath);
      if (!await file.exists()) {
        setState(() {
          _fileMissing = true;
          _isLoading = false;
        });
        return;
      }

      final text = await file.readAsString();
      setState(() {
        _content = text;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _fileMissing = true;
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_content == null) return;
    Clipboard.setData(ClipboardData(text: _content!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File content copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.resource.name),
        actions: [
          if (_content != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy all code',
              onPressed: _copyToClipboard,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _fileMissing
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'File Not On This Device',
                        message: 'File not on this device. Re-import the ZIP to restore it.',
                        actionText: 'Back to Library',
                        onAction: () => Navigator.of(context).pop(),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SelectableText(
                        _content ?? '',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF24292E),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
