import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/study_materials_provider.dart';

class UploadFileDialog extends StatefulWidget {
  const UploadFileDialog({super.key});

  @override
  State<UploadFileDialog> createState() => _UploadFileDialogState();
}

class _UploadFileDialogState extends State<UploadFileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();

  PlatformFile? _selectedFile;
  bool _isLoading = false;
  bool _useUrl = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'mp4',
          'mp3',
          'zip',
          'rar',
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          if (_nameController.text.isEmpty) {
            _nameController.text = _selectedFile!.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  String _getFileType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ext;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_useUrl && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final materialsProvider = context.read<StudyMaterialsProvider>();

    try {
      dynamic result;

      if (_useUrl) {
        // Create file record with URL
        final url = _urlController.text.trim();
        final name = _nameController.text.trim();
        final fileType = _getFileType(name);

        result = await materialsProvider.createFileWithUrl(
          name: name,
          fileUrl: url,
          fileType: fileType,
          fileSize: 0, // Unknown size for URL
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          teacherId: authProvider.currentTeacher!.id,
        );
      } else {
        // Upload file
        result = await materialsProvider.uploadFile(
          name: _nameController.text.trim(),
          filePath: _selectedFile!.path!,
          fileType: _getFileType(_selectedFile!.name),
          fileSize: _selectedFile!.size,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          teacherId: authProvider.currentTeacher!.id,
        );
      }

      if (mounted) {
        if (result != null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final error = materialsProvider.error ??
              'Failed to add file. Please try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Add File'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle between file upload and URL
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Upload File'),
                    selected: !_useUrl,
                    onSelected: (selected) {
                      if (selected) setState(() => _useUrl = false);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Add URL'),
                    selected: _useUrl,
                    onSelected: (selected) {
                      if (selected) setState(() => _useUrl = true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!_useUrl) ...[
                // File picker
                InkWell(
                  onTap: _pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _selectedFile != null
                              ? Icons.check_circle
                              : Icons.cloud_upload,
                          size: 48,
                          color: _selectedFile != null
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFile != null
                              ? _selectedFile!.name
                              : 'Tap to select a file',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedFile != null
                                ? (isDark ? Colors.white : Colors.black87)
                                : Colors.grey,
                          ),
                        ),
                        if (_selectedFile != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatFileSize(_selectedFile!.size),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // URL input
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'File URL *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                    hintText: 'https://...',
                  ),
                  validator: (value) {
                    if (_useUrl && (value == null || value.trim().isEmpty)) {
                      return 'Please enter a URL';
                    }
                    if (_useUrl && !Uri.tryParse(value!)!.hasAbsolutePath) {
                      return 'Please enter a valid URL';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'File Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.insert_drive_file),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a file name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
