import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';

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
            content: Text('Failed to save room. Room number may already exist.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = context.watch<AuthProvider>().branches;

    return AlertDialog(
      title: const Text('Add Room Mapping'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coordinates display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'X Coordinate',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          widget.x.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    Column(
                      children: [
                        const Text(
                          'Y Coordinate',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          widget.y.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Room Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'e.g., IT Lab 1, Faculty Room',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter room name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Room Number
              TextFormField(
                controller: _roomNumberController,
                decoration: const InputDecoration(
                  labelText: 'Room Number',
                  hintText: 'e.g., A-301, LAB-101',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter room number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Room Type
              DropdownButtonFormField<String>(
                initialValue: _selectedRoomType,
                decoration: const InputDecoration(
                  labelText: 'Room Type',
                ),
                items: _roomTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRoomType = value ?? 'classroom';
                  });
                },
              ),
              const SizedBox(height: 16),

              // Floor
              DropdownButtonFormField<int>(
                initialValue: _selectedFloor,
                decoration: const InputDecoration(
                  labelText: 'Floor',
                ),
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
              DropdownButtonFormField<String?>(
                initialValue: _selectedBranchId,
                decoration: const InputDecoration(
                  labelText: 'Branch (Optional)',
                ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveRoom,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Room'),
        ),
      ],
    );
  }
}
