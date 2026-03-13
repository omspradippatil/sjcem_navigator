import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/study_materials_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';

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
    final materialsProvider = context.watch<StudyMaterialsProvider>();
    final isAtRoot = materialsProvider.isAtRoot;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (value * 0.2),
            child: Opacity(
              opacity: value,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark.withValues(alpha:0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryLight.withValues(alpha:0.1),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            gradient: AppGradients.primarySubtle,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: AppGradients.warning,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.warning.withValues(alpha:0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isEditing
                                      ? Icons.edit_rounded
                                      : Icons.create_new_folder_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEditing
                                          ? 'Edit Folder'
                                          : 'Create Folder',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isEditing
                                          ? 'Update folder details'
                                          : 'Organize your study materials',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                },
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.glassDark,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppColors.glassBorder),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Form Content
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPremiumTextField(
                                    controller: _nameController,
                                    label: 'Folder Name',
                                    hint: 'Enter folder name',
                                    icon: Icons.folder_rounded,
                                    isRequired: true,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter a folder name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPremiumTextField(
                                    controller: _descriptionController,
                                    label: 'Description',
                                    hint: 'Add a description (optional)',
                                    icon: Icons.description_rounded,
                                    maxLines: 2,
                                  ),

                                  // Only show these options for root folders and when creating
                                  if (isAtRoot && !isEditing) ...[
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.info.withValues(alpha:0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: AppColors.info
                                                .withValues(alpha:0.3)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.info_outline_rounded,
                                              size: 18, color: AppColors.info),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Optional: Link to subject/branch',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.info,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Subject dropdown
                                    _buildPremiumDropdown<String>(
                                      value: _selectedSubjectId,
                                      label: 'Subject',
                                      icon: Icons.book_rounded,
                                      items: [
                                        const DropdownMenuItem(
                                            value: null,
                                            child: Text('All Subjects')),
                                        ..._subjects
                                            .map((s) => DropdownMenuItem(
                                                  value: s.id,
                                                  child: Text(s.name),
                                                )),
                                      ],
                                      onChanged: (value) => setState(
                                          () => _selectedSubjectId = value),
                                    ),
                                    const SizedBox(height: 12),

                                    // Branch dropdown
                                    _buildPremiumDropdown<String>(
                                      value: _selectedBranchId,
                                      label: 'Branch',
                                      icon: Icons.school_rounded,
                                      items: [
                                        const DropdownMenuItem(
                                            value: null,
                                            child: Text('All Branches')),
                                        ..._branches
                                            .map((b) => DropdownMenuItem(
                                                  value: b.id,
                                                  child: Text(b.name),
                                                )),
                                      ],
                                      onChanged: (value) => setState(
                                          () => _selectedBranchId = value),
                                    ),
                                    const SizedBox(height: 12),

                                    // Semester dropdown
                                    _buildPremiumDropdown<int>(
                                      value: _selectedSemester,
                                      label: 'Semester',
                                      icon: Icons.calendar_today_rounded,
                                      items: [
                                        const DropdownMenuItem(
                                            value: null,
                                            child: Text('All Semesters')),
                                        ...List.generate(
                                            8,
                                            (i) => DropdownMenuItem(
                                                  value: i + 1,
                                                  child:
                                                      Text('Semester ${i + 1}'),
                                                )),
                                      ],
                                      onChanged: (value) => setState(
                                          () => _selectedSemester = value),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Actions
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.glassDark,
                            border: Border(
                              top: BorderSide(color: AppColors.glassBorder),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: AppColors.glassDark,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AppColors.glassBorder),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () {
                                          HapticFeedback.mediumImpact();
                                          _submit();
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: _isLoading
                                          ? null
                                          : AppGradients.primary,
                                      color: _isLoading
                                          ? AppColors.glassDark
                                          : null,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: _isLoading
                                          ? null
                                          : [AppShadows.glowPrimary],
                                    ),
                                    child: Center(
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.textPrimary,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isEditing
                                                      ? Icons.save_rounded
                                                      : Icons.add_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isEditing
                                                      ? 'Save Changes'
                                                      : 'Create Folder',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.glassDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.primary.createShader(bounds),
                child: Icon(icon, color: Colors.white),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.glassDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: DropdownButtonFormField<T>(
            initialValue: items.isEmpty || !items.any((item) => item.value == value) ? null : value,
            dropdownColor: AppColors.cardDark,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              prefixIcon: ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.primary.createShader(bounds),
                child: Icon(icon, color: Colors.white),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
