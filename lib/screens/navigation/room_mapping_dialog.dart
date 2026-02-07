import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../utils/app_theme.dart';

class RoomMappingDialog extends StatefulWidget {
  final double x;
  final double y;

  const RoomMappingDialog({
    super.key,
    required this.x,
    required this.y,
  });

  @override
  State<RoomMappingDialog> createState() => _RoomMappingDialogState();
}

class _RoomMappingDialogState extends State<RoomMappingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roomNumberController = TextEditingController();
  String _selectedRoomType = 'classroom';
  String? _selectedBranchId;
  int _selectedFloor = 3;
  bool _isLoading = false;

  final List<String> _roomTypes = [
    'classroom',
    'lab',
    'office',
    'faculty',
    'washroom',
    'auditorium',
    'library',
    'canteen',
    'other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _roomNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final navProvider = context.read<NavigationProvider>();
    final room = await navProvider.saveRoomCoordinates(
      name: _nameController.text.trim(),
      roomNumber: _roomNumberController.text.trim(),
      x: widget.x,
      y: widget.y,
      roomType: _selectedRoomType,
      branchId: _selectedBranchId,
      floor: _selectedFloor,
    );

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (room != null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Room "${room.name}" saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Failed to save room. Room number may already exist.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = context.watch<AuthProvider>().branches;

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
                                  gradient: AppGradients.info,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.info.withValues(alpha:0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_location_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add Room Mapping',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Map this location to a room',
                                      style: TextStyle(
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
                                  // Coordinates display
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: AppGradients.primarySubtle,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: AppColors.glassBorder),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Column(
                                          children: [
                                            const Text(
                                              'X Coordinate',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ShaderMask(
                                              shaderCallback: (bounds) =>
                                                  AppGradients.primary
                                                      .createShader(bounds),
                                              child: Text(
                                                widget.x.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 22,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          width: 1,
                                          height: 40,
                                          color: AppColors.glassBorder,
                                        ),
                                        Column(
                                          children: [
                                            const Text(
                                              'Y Coordinate',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ShaderMask(
                                              shaderCallback: (bounds) =>
                                                  AppGradients.accent
                                                      .createShader(bounds),
                                              child: Text(
                                                widget.y.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 22,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Room Name
                                  _buildPremiumTextField(
                                    controller: _nameController,
                                    label: 'Room Name',
                                    hint: 'e.g., IT Lab 1, Faculty Room',
                                    icon: Icons.meeting_room_rounded,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter room name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Room Number
                                  _buildPremiumTextField(
                                    controller: _roomNumberController,
                                    label: 'Room Number',
                                    hint: 'e.g., A-301, LAB-101',
                                    icon: Icons.tag_rounded,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter room number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Room Type
                                  _buildPremiumDropdown<String>(
                                    value: _selectedRoomType,
                                    label: 'Room Type',
                                    icon: Icons.category_rounded,
                                    items: _roomTypes.map((type) {
                                      return DropdownMenuItem(
                                        value: type,
                                        child: Text(type.toUpperCase()),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedRoomType =
                                            value ?? 'classroom';
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Floor
                                  _buildPremiumDropdown<int>(
                                    value: _selectedFloor,
                                    label: 'Floor',
                                    icon: Icons.layers_rounded,
                                    items: List.generate(5, (index) {
                                      return DropdownMenuItem(
                                        value: index + 1,
                                        child: Text('Floor ${index + 1}'),
                                      );
                                    }),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedFloor = value ?? 1;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Branch (optional)
                                  _buildPremiumDropdown<String?>(
                                    value: _selectedBranchId,
                                    label: 'Branch (Optional)',
                                    icon: Icons.school_rounded,
                                    items: [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('No specific branch'),
                                      ),
                                      ...branches.map((branch) {
                                        return DropdownMenuItem(
                                          value: branch.id,
                                          child: Text(branch.code),
                                        );
                                      }),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedBranchId = value;
                                      });
                                    },
                                  ),
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
                                          _saveRoom();
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient:
                                          _isLoading ? null : AppGradients.info,
                                      color: _isLoading
                                          ? AppColors.glassDark
                                          : null,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: _isLoading
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: AppColors.info
                                                    .withValues(alpha:0.4),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
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
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.save_rounded,
                                                    color: Colors.white,
                                                    size: 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Save Room',
                                                  style: TextStyle(
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
    String? Function(String?)? validator,
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
          child: TextFormField(
            controller: controller,
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
            initialValue: value,
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
