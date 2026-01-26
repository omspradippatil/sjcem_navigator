import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/study_materials_provider.dart';
import '../../services/supabase_service.dart';

class CreateFolderDialog extends StatefulWidget {
  final StudyFolder? folder; // For editing

  const CreateFolderDialog({super.key, this.folder});

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedSubjectId;
  String? _selectedBranchId;
  int? _selectedSemester;

  List<Subject> _subjects = [];
  List<Branch> _branches = [];
  bool _isLoading = false;

  bool get isEditing => widget.folder != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.folder!.name;
      _descriptionController.text = widget.folder!.description ?? '';
      _selectedSubjectId = widget.folder!.subjectId;
      _selectedBranchId = widget.folder!.branchId;
      _selectedSemester = widget.folder!.semester;
    }
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();

    final subjects = await SupabaseService.getSubjects(
      branchId: authProvider.currentBranchId,
    );
    final branches = await SupabaseService.getBranches();

    if (mounted) {
      setState(() {
        _subjects = subjects;
        _branches = branches;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final materialsProvider = context.read<StudyMaterialsProvider>();

    if (isEditing) {
      await materialsProvider.updateFolder(
        widget.folder!.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
    } else {
      await materialsProvider.createFolder(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        teacherId: authProvider.currentTeacher!.id,
        subjectId: _selectedSubjectId,
        branchId: _selectedBranchId ?? authProvider.currentBranchId,
        semester: _selectedSemester,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final materialsProvider = context.watch<StudyMaterialsProvider>();
    final isAtRoot = materialsProvider.isAtRoot;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Folder' : 'Create Folder'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Folder Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a folder name';
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

              // Only show these options for root folders and when creating
              if (isAtRoot && !isEditing) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Optional: Link to subject/branch',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),

                // Subject dropdown
                DropdownButtonFormField<String>(
                  value: _selectedSubjectId,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.book),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Subjects')),
                    ..._subjects.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        )),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedSubjectId = value),
                ),
                const SizedBox(height: 12),

                // Branch dropdown
                DropdownButtonFormField<String>(
                  value: _selectedBranchId,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Branches')),
                    ..._branches.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name),
                        )),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedBranchId = value),
                ),
                const SizedBox(height: 12),

                // Semester dropdown
                DropdownButtonFormField<int>(
                  value: _selectedSemester,
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Semesters')),
                    ...List.generate(
                        8,
                        (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('Semester ${i + 1}'),
                            )),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedSemester = value),
                ),
              ],
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
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
