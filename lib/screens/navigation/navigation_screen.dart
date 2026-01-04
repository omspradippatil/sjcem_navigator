import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import 'room_mapping_dialog.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final TransformationController _transformationController =
      TransformationController();
  bool _showRoomLabels = true;
  int _selectedFloor = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavigationProvider>().startSensors();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _onMapTap(TapDownDetails details) {
    final navProvider = context.read<NavigationProvider>();
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);

    // Account for transformation
    final Matrix4 matrix = _transformationController.value;
    final Matrix4 inverseMatrix = Matrix4.inverted(matrix);
    final Vector3 transformedPoint = inverseMatrix.transform3(
      Vector3(localPosition.dx, localPosition.dy, 0),
    );

    final double x = transformedPoint.x;
    final double y = transformedPoint.y;

    if (navProvider.isAdminMode) {
      _showRoomMappingDialog(x, y);
    } else if (!navProvider.positionSet) {
      navProvider.setInitialPosition(x, y, floor: _selectedFloor);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Position set! Tap calibrate and face a known direction.'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Calibrate',
            textColor: Colors.white,
            onPressed: _showCalibrationDialog,
          ),
        ),
      );
    }
  }

  void _showCalibrationDialog() {
    final navProvider = context.read<NavigationProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.explore, color: Colors.blue),
            SizedBox(width: 8),
            Text('Compass Calibration'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Face a known direction (e.g., entrance door) and select it below. '
                    'This will improve navigation accuracy.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('I am facing:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCalibrationButton(context, 'North', 0, navProvider),
                _buildCalibrationButton(context, 'East', 90, navProvider),
                _buildCalibrationButton(context, 'South', 180, navProvider),
                _buildCalibrationButton(context, 'West', 270, navProvider),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Or enter custom heading:',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Degrees',
                  suffixText: '°',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (value) {
                  final heading = double.tryParse(value);
                  if (heading != null) {
                    navProvider.setCalibrationHeading(heading);
                    Navigator.of(context).pop();
                    _showCalibrationSuccess();
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationButton(
    BuildContext context,
    String label,
    double heading,
    NavigationProvider navProvider,
  ) {
    return ElevatedButton(
      onPressed: () {
        navProvider.setCalibrationHeading(heading);
        Navigator.of(context).pop();
        _showCalibrationSuccess();
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }

  void _showCalibrationSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Compass calibrated! Navigation is now more accurate.'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRoomMappingDialog(double x, double y) {
    showDialog(
      context: context,
      builder: (context) => RoomMappingDialog(x: x, y: y),
    );
  }

  void _showRoomSelector() {
    final navProvider = context.read<NavigationProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredRooms = navProvider.rooms.where((room) {
              final matchesSearch = _searchQuery.isEmpty ||
                  room.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                  room.roomNumber
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
              final matchesFloor = room.floor == _selectedFloor;
              return matchesSearch && matchesFloor;
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.3,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Select Destination',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search rooms...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    // Floor filter chips
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(5, (index) {
                            final isSelected = _selectedFloor == index;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text('Floor $index'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setSheetState(() {
                                    _selectedFloor = index;
                                  });
                                },
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    if (filteredRooms.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No rooms found',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filteredRooms.length,
                          itemBuilder: (context, index) {
                            final room = filteredRooms[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getRoomColor(room.roomType),
                                child: Icon(
                                  _getRoomIcon(room.roomType),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(room.name),
                              subtitle: Text(
                                  '${room.roomNumber} • Floor ${room.floor}'),
                              trailing: const Icon(Icons.navigation, size: 20),
                              onTap: () {
                                navProvider.navigateToRoom(room);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Color _getRoomColor(String roomType) {
    switch (roomType) {
      case 'classroom':
        return Colors.blue;
      case 'lab':
        return Colors.green;
      case 'office':
        return Colors.orange;
      case 'faculty':
        return Colors.purple;
      case 'washroom':
        return Colors.grey;
      case 'auditorium':
        return Colors.red;
      case 'library':
        return Colors.brown;
      case 'cafeteria':
        return Colors.amber;
      case 'stairs':
        return Colors.teal;
      case 'elevator':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getRoomIcon(String roomType) {
    switch (roomType) {
      case 'classroom':
        return Icons.class_;
      case 'lab':
        return Icons.science;
      case 'office':
        return Icons.work;
      case 'faculty':
        return Icons.people;
      case 'washroom':
        return Icons.wc;
      case 'auditorium':
        return Icons.theater_comedy;
      case 'library':
        return Icons.local_library;
      case 'cafeteria':
        return Icons.restaurant;
      case 'stairs':
        return Icons.stairs;
      case 'elevator':
        return Icons.elevator;
      default:
        return Icons.room;
    }
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Column(
      children: [
        // Control Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Floor selector and destination row
              Row(
                children: [
                  // Floor Selector
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedFloor,
                        items: List.generate(5, (index) {
                          return DropdownMenuItem(
                            value: index,
                            child: Text('F$index'),
                          );
                        }),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedFloor = value;
                            });
                            navProvider.setCurrentFloor(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showRoomSelector,
                      icon: const Icon(Icons.location_searching, size: 18),
                      label: Text(
                        navProvider.targetRoom?.name ?? 'Select Destination',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (navProvider.isNavigating)
                    IconButton(
                      onPressed: () => navProvider.stopNavigation(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Stop Navigation',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Control buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: navProvider.sensorsActive
                        ? Icons.sensors
                        : Icons.sensors_off,
                    label: 'Sensors',
                    onPressed: () {
                      if (navProvider.sensorsActive) {
                        navProvider.stopSensors();
                      } else {
                        navProvider.startSensors();
                      }
                    },
                    isActive: navProvider.sensorsActive,
                  ),
                  _buildControlButton(
                    icon: Icons.explore,
                    label: 'Calibrate',
                    onPressed:
                        navProvider.positionSet ? _showCalibrationDialog : null,
                    isActive: navProvider.isCalibrated,
                  ),
                  _buildControlButton(
                    icon: Icons.my_location,
                    label: 'Reset',
                    onPressed: () => navProvider.resetPosition(),
                  ),
                  _buildControlButton(
                    icon: _showRoomLabels ? Icons.label : Icons.label_off,
                    label: 'Labels',
                    onPressed: () {
                      setState(() {
                        _showRoomLabels = !_showRoomLabels;
                      });
                    },
                    isActive: _showRoomLabels,
                  ),
                  if (authProvider.isAdmin || authProvider.isTeacher)
                    _buildControlButton(
                      icon: Icons.edit_location_alt,
                      label: 'Admin',
                      onPressed: () => navProvider.toggleAdminMode(),
                      isActive: navProvider.isAdminMode,
                    ),
                ],
              ),
            ],
          ),
        ),

        // Navigation Info Panel
        if (navProvider.isNavigating || !navProvider.positionSet)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: navProvider.hasReachedDestination
                    ? [Colors.green.shade300, Colors.green.shade400]
                    : [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.primary.withOpacity(0.2)
                      ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        navProvider.hasReachedDestination
                            ? Icons.check_circle
                            : navProvider.positionSet
                                ? Icons.directions_walk
                                : Icons.touch_app,
                        color: navProvider.hasReachedDestination
                            ? Colors.green.shade800
                            : theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            navProvider.getNavigationInstructions(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: navProvider.hasReachedDestination
                                  ? Colors.green.shade900
                                  : null,
                            ),
                          ),
                          if (navProvider.isNavigating)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  _buildNavInfoChip(
                                    Icons.straighten,
                                    '${navProvider.distanceToTarget.toStringAsFixed(0)} px',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildNavInfoChip(
                                    Icons.timer,
                                    navProvider.getEstimatedTime(),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildNavInfoChip(
                                    Icons.directions_walk,
                                    '${navProvider.stepCount}',
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (navProvider.hasReachedDestination)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.celebration,
                                color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Arrived!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

        // Map View
        Expanded(
          child: GestureDetector(
            onTapDown: _onMapTap,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(100),
              child: Stack(
                children: [
                  // Floor Map Background
                  Container(
                    width: 700,
                    height: 650,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: CustomPaint(
                      painter: FloorMapPainter(
                        rooms: navProvider.rooms
                            .where((r) => r.floor == _selectedFloor)
                            .toList(),
                        showLabels: _showRoomLabels,
                        currentPosition: navProvider.positionSet
                            ? Offset(navProvider.currentX, navProvider.currentY)
                            : null,
                        targetRoom: navProvider.targetRoom,
                        heading: navProvider.heading,
                        navigationPath: navProvider.getNavigationPath(),
                        currentFloor: _selectedFloor,
                      ),
                    ),
                  ),
                  // Floor indicator overlay
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Floor $_selectedFloor',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Compass rose
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: CompassPainter(heading: navProvider.heading),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Status Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(
                Icons.location_on,
                navProvider.positionSet
                    ? '(${navProvider.currentX.toInt()}, ${navProvider.currentY.toInt()})'
                    : 'Tap to set',
                'Position',
              ),
              Container(height: 24, width: 1, color: Colors.grey.shade400),
              _buildStatusItem(
                Icons.explore,
                '${navProvider.heading.toStringAsFixed(0)}°',
                'Heading',
              ),
              Container(height: 24, width: 1, color: Colors.grey.shade400),
              _buildStatusItem(
                Icons.directions_walk,
                '${navProvider.stepCount}',
                'Steps',
              ),
              Container(height: 24, width: 1, color: Colors.grey.shade400),
              _buildStatusItem(
                navProvider.isCalibrated
                    ? Icons.check_circle
                    : Icons.error_outline,
                navProvider.isCalibrated ? 'Ready' : 'Needed',
                'Calibration',
                isWarning: !navProvider.isCalibrated && navProvider.positionSet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isActive = false,
  }) {
    final isDisabled = onPressed == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : isDisabled
                    ? Colors.grey.shade200
                    : null,
            foregroundColor: isActive
                ? Theme.of(context).colorScheme.primary
                : isDisabled
                    ? Colors.grey
                    : null,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDisabled ? Colors.grey : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(
    IconData icon,
    String value,
    String label, {
    bool isWarning = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isWarning ? Colors.orange : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isWarning ? Colors.orange : null,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class FloorMapPainter extends CustomPainter {
  final List<Room> rooms;
  final bool showLabels;
  final Offset? currentPosition;
  final Room? targetRoom;
  final double heading;
  final List<Offset> navigationPath;
  final int currentFloor;

  FloorMapPainter({
    required this.rooms,
    required this.showLabels,
    this.currentPosition,
    this.targetRoom,
    required this.heading,
    required this.navigationPath,
    required this.currentFloor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Draw floor background
    paint.color = const Color(0xFFFAFAFA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw grid lines
    paint.color = Colors.grey.withOpacity(0.1);
    paint.strokeWidth = 1;
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw 3rd Floor Layout (SJCEM)
    _draw3rdFloorLayout(canvas, size, paint);

    // Draw rooms from database
    for (final room in rooms) {
      final isTarget = targetRoom?.id == room.id;
      final roomColor = _getRoomColor(room.roomType);

      // Glow effect for target
      if (isTarget) {
        paint.color = roomColor.withOpacity(0.3);
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(room.xCoordinate, room.yCoordinate),
          25,
          paint,
        );
      }

      // Room marker
      paint.color = isTarget ? Colors.green : roomColor;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(room.xCoordinate, room.yCoordinate),
        isTarget ? 14 : 10,
        paint,
      );

      // Room border
      paint.color = Colors.white;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawCircle(
        Offset(room.xCoordinate, room.yCoordinate),
        isTarget ? 14 : 10,
        paint,
      );

      // Room labels
      if (showLabels) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: room.roomNumber,
            style: TextStyle(
              color: isTarget ? Colors.green.shade800 : Colors.grey.shade700,
              fontSize: isTarget ? 11 : 9,
              fontWeight: isTarget ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            room.xCoordinate - textPainter.width / 2,
            room.yCoordinate + 15,
          ),
        );
      }
    }

    // Draw navigation path
    if (navigationPath.length >= 2) {
      // Draw path shadow
      paint.color = Colors.blue.withOpacity(0.2);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 8;
      paint.strokeCap = StrokeCap.round;
      paint.strokeJoin = StrokeJoin.round;

      final shadowPath = Path();
      shadowPath.moveTo(navigationPath[0].dx, navigationPath[0].dy);
      for (int i = 1; i < navigationPath.length; i++) {
        shadowPath.lineTo(navigationPath[i].dx, navigationPath[i].dy);
      }
      canvas.drawPath(shadowPath, paint);

      // Draw main path with dashed line
      paint.color = Colors.blue;
      paint.strokeWidth = 4;

      const dashWidth = 12.0;
      const dashSpace = 6.0;
      var distance = 0.0;

      final path = Path();
      path.moveTo(navigationPath[0].dx, navigationPath[0].dy);
      for (int i = 1; i < navigationPath.length; i++) {
        path.lineTo(navigationPath[i].dx, navigationPath[i].dy);
      }

      for (final metric in path.computeMetrics()) {
        while (distance < metric.length) {
          final extractPath = metric.extractPath(
            distance,
            distance + dashWidth,
          );
          canvas.drawPath(extractPath, paint);
          distance += dashWidth + dashSpace;
        }
        distance = 0;
      }

      // Draw waypoint dots on path
      paint.style = PaintingStyle.fill;
      for (int i = 1; i < navigationPath.length - 1; i++) {
        paint.color = Colors.blue.shade200;
        canvas.drawCircle(navigationPath[i], 5, paint);
        paint.color = Colors.blue;
        canvas.drawCircle(navigationPath[i], 3, paint);
      }
    }

    // Draw current position (user location)
    if (currentPosition != null) {
      // Accuracy circle
      paint.color = Colors.red.withOpacity(0.1);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(currentPosition!, 30, paint);

      // Direction cone
      paint.color = Colors.red.withOpacity(0.3);
      paint.style = PaintingStyle.fill;

      final headingRad = heading * pi / 180;
      final path = Path();
      path.moveTo(
        currentPosition!.dx + 35 * sin(headingRad),
        currentPosition!.dy - 35 * cos(headingRad),
      );
      path.lineTo(
        currentPosition!.dx + 12 * sin(headingRad + pi / 2),
        currentPosition!.dy - 12 * cos(headingRad + pi / 2),
      );
      path.lineTo(
        currentPosition!.dx + 12 * sin(headingRad - pi / 2),
        currentPosition!.dy - 12 * cos(headingRad - pi / 2),
      );
      path.close();
      canvas.drawPath(path, paint);

      // User position outer ring
      paint.color = Colors.white;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(currentPosition!, 14, paint);

      // User position dot
      paint.color = Colors.red;
      canvas.drawCircle(currentPosition!, 12, paint);

      // Inner white dot
      paint.color = Colors.white;
      canvas.drawCircle(currentPosition!, 5, paint);

      // Direction indicator (small arrow)
      paint.color = Colors.white;
      paint.style = PaintingStyle.fill;
      final arrowPath = Path();
      arrowPath.moveTo(
        currentPosition!.dx + 8 * sin(headingRad),
        currentPosition!.dy - 8 * cos(headingRad),
      );
      arrowPath.lineTo(
        currentPosition!.dx + 3 * sin(headingRad + 2.5),
        currentPosition!.dy - 3 * cos(headingRad + 2.5),
      );
      arrowPath.lineTo(
        currentPosition!.dx + 3 * sin(headingRad - 2.5),
        currentPosition!.dy - 3 * cos(headingRad - 2.5),
      );
      arrowPath.close();
      canvas.drawPath(arrowPath, paint);
    }
  }

  // Draw SJCEM 3rd Floor Layout based on floor plan
  void _draw3rdFloorLayout(Canvas canvas, Size size, Paint paint) {
    // B-Wing (Top section)
    paint.color = const Color(0xFFE3F2FD);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(20, 20, 300, 120), paint);
    paint.color = const Color(0xFF1976D2);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawRect(const Rect.fromLTWH(20, 20, 300, 120), paint);

    // B-Wing Label
    _drawLabel(
        canvas, 'B-WING', const Offset(145, 75), Colors.blue.shade800, 14);

    // A-Wing Data Science Labs (Left vertical section)
    paint.color = const Color(0xFFE8F5E9);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(20, 170, 140, 280), paint);
    paint.color = const Color(0xFF388E3C);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawRect(const Rect.fromLTWH(20, 170, 140, 280), paint);

    // Data Science Labs Label
    _drawLabel(
        canvas, 'DS LABS', const Offset(55, 300), Colors.green.shade800, 11);

    // A-Wing IT Labs (Right vertical section)
    paint.color = const Color(0xFFE8F5E9);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(540, 170, 140, 280), paint);
    paint.color = const Color(0xFF388E3C);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawRect(const Rect.fromLTWH(540, 170, 140, 280), paint);

    // IT Labs Label
    _drawLabel(
        canvas, 'IT LABS', const Offset(580, 300), Colors.green.shade800, 11);

    // Auditorium (Bottom center - largest section)
    paint.color = const Color(0xFFFCE4EC);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(190, 470, 320, 120), paint);
    paint.color = const Color(0xFFC2185B);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawRect(const Rect.fromLTWH(190, 470, 320, 120), paint);

    // Auditorium Label
    _drawLabel(canvas, 'AUDITORIUM (A-307)', const Offset(280, 530),
        Colors.pink.shade800, 12);

    // Open Courtyards
    paint.color = const Color(0xFFC8E6C9).withOpacity(0.6);
    paint.style = PaintingStyle.fill;
    // Left courtyard
    canvas.drawRect(const Rect.fromLTWH(190, 170, 140, 130), paint);
    // Right courtyard
    canvas.drawRect(const Rect.fromLTWH(370, 170, 140, 130), paint);

    paint.color = Colors.green.shade400;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawRect(const Rect.fromLTWH(190, 170, 140, 130), paint);
    canvas.drawRect(const Rect.fromLTWH(370, 170, 140, 130), paint);

    _drawLabel(
        canvas, 'COURTYARD', const Offset(210, 230), Colors.green.shade700, 9);
    _drawLabel(
        canvas, 'COURTYARD', const Offset(390, 230), Colors.green.shade700, 9);

    // Main Corridors
    paint.color = const Color(0xFFEEEEEE);
    paint.style = PaintingStyle.fill;

    // Horizontal corridor connecting wings (top)
    canvas.drawRect(const Rect.fromLTWH(20, 145, 660, 20), paint);

    // Vertical corridors
    canvas.drawRect(const Rect.fromLTWH(165, 165, 20, 300), paint);
    canvas.drawRect(const Rect.fromLTWH(515, 165, 20, 300), paint);

    // Bottom corridor
    canvas.drawRect(const Rect.fromLTWH(165, 450, 370, 20), paint);

    paint.color = Colors.grey.shade400;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    canvas.drawRect(const Rect.fromLTWH(20, 145, 660, 20), paint);
    canvas.drawRect(const Rect.fromLTWH(165, 165, 20, 300), paint);
    canvas.drawRect(const Rect.fromLTWH(515, 165, 20, 300), paint);
    canvas.drawRect(const Rect.fromLTWH(165, 450, 370, 20), paint);

    // Draw Staircases
    _drawStaircase(canvas, paint, 340, 20, 'STAIR-1');
    _drawStaircase(canvas, paint, 20, 460, 'STAIR-2');
    _drawStaircase(canvas, paint, 590, 460, 'STAIR-3');

    // Draw Washrooms
    _drawWashroom(canvas, paint, 400, 20, 'WC-M');
    _drawWashroom(canvas, paint, 450, 20, 'WC-F');

    // Draw Offices
    _drawOffice(canvas, paint, 20, 460, 'HOD');
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color,
      double fontSize) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  void _drawStaircase(
      Canvas canvas, Paint paint, double x, double y, String label) {
    paint.color = const Color(0xFF80DEEA);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(x, y, 50, 40), paint);
    paint.color = const Color(0xFF00838F);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(x, y, 50, 40), paint);

    // Draw stairs lines
    for (double i = 5; i < 40; i += 8) {
      canvas.drawLine(Offset(x + 5, y + i), Offset(x + 45, y + i), paint);
    }
  }

  void _drawWashroom(
      Canvas canvas, Paint paint, double x, double y, String label) {
    paint.color = const Color(0xFFE1BEE7);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(x, y, 40, 35), paint);
    paint.color = const Color(0xFF7B1FA2);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(x, y, 40, 35), paint);
  }

  void _drawOffice(
      Canvas canvas, Paint paint, double x, double y, String label) {
    paint.color = const Color(0xFFFFE0B2);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(x, y, 60, 45), paint);
    paint.color = const Color(0xFFE65100);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(x, y, 60, 45), paint);
  }

  Color _getRoomColor(String roomType) {
    switch (roomType) {
      case 'classroom':
        return Colors.blue;
      case 'lab':
        return Colors.green;
      case 'office':
        return Colors.orange;
      case 'faculty':
        return Colors.purple;
      case 'washroom':
        return Colors.grey;
      case 'auditorium':
        return Colors.red;
      case 'library':
        return Colors.brown;
      case 'cafeteria':
        return Colors.amber;
      case 'stairs':
        return Colors.teal;
      case 'elevator':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  bool shouldRepaint(covariant FloorMapPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.targetRoom != targetRoom ||
        oldDelegate.heading != heading ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.navigationPath != navigationPath ||
        oldDelegate.currentFloor != currentFloor ||
        oldDelegate.rooms != rooms;
  }
}

/// Compass painter for the mini compass rose
class CompassPainter extends CustomPainter {
  final double heading;

  CompassPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint();

    // Background circle
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    // Border
    paint.color = Colors.grey.shade300;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    canvas.drawCircle(center, radius, paint);

    // Rotate canvas for heading
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * pi / 180);
    canvas.translate(-center.dx, -center.dy);

    // North indicator (red triangle)
    paint.color = Colors.red;
    paint.style = PaintingStyle.fill;
    final northPath = Path();
    northPath.moveTo(center.dx, center.dy - radius + 4);
    northPath.lineTo(center.dx - 6, center.dy);
    northPath.lineTo(center.dx + 6, center.dy);
    northPath.close();
    canvas.drawPath(northPath, paint);

    // South indicator (grey triangle)
    paint.color = Colors.grey;
    final southPath = Path();
    southPath.moveTo(center.dx, center.dy + radius - 4);
    southPath.lineTo(center.dx - 6, center.dy);
    southPath.lineTo(center.dx + 6, center.dy);
    southPath.close();
    canvas.drawPath(southPath, paint);

    canvas.restore();

    // N label (fixed position)
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.red,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, 2),
    );
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) {
    return oldDelegate.heading != heading;
  }
}
