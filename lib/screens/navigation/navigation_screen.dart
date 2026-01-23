import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../utils/constants.dart';
import 'room_mapping_dialog.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with TickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  bool _showRoomLabels = true;
  int _selectedFloor = 3; // Default to floor 3
  String _searchQuery = '';

  // For smooth animation of the red dot
  Offset _animatedPosition = Offset.zero;
  Offset _targetPosition = Offset.zero;
  bool _hasInitialPosition = false;
  
  // Animation controllers for smooth movement
  late AnimationController _positionAnimationController;
  late AnimationController _headingAnimationController;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _headingAnimation;
  double _currentHeading = 0;
  double _targetHeading = 0;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _positionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _headingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    
    _positionAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _positionAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _headingAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _headingAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NavigationProvider>().startSensors();
    });
  }
  
  void _animateToPosition(Offset newPosition) {
    if (!_hasInitialPosition) {
      _animatedPosition = newPosition;
      _targetPosition = newPosition;
      _hasInitialPosition = true;
      setState(() {});
      return;
    }
    
    _positionAnimation = Tween<Offset>(
      begin: _animatedPosition,
      end: newPosition,
    ).animate(CurvedAnimation(
      parent: _positionAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _positionAnimationController.forward(from: 0).then((_) {
      _animatedPosition = newPosition;
    });
    
    _targetPosition = newPosition;
    setState(() {});
  }
  
  void _animateToHeading(double newHeading) {
    _headingAnimation = Tween<double>(
      begin: _currentHeading,
      end: newHeading,
    ).animate(CurvedAnimation(
      parent: _headingAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _headingAnimationController.forward(from: 0).then((_) {
      _currentHeading = newHeading;
    });
    
    _targetHeading = newHeading;
    setState(() {});
  }

  @override
  void dispose() {
    _positionAnimationController.dispose();
    _headingAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onMapTap(TapUpDetails details) {
    final navProvider = context.read<NavigationProvider>();

    // Get tap coordinates relative to the map (localPosition is already in map coordinates)
    final double x = details.localPosition.dx;
    final double y = details.localPosition.dy;

    // Log tap coordinates for debugging
    debugPrint('🗺️ Map tapped at: ($x, $y)');

    if (navProvider.isAdminMode) {
      _showRoomMappingDialog(x, y);
    } else if (!navProvider.positionSet) {
      navProvider.setInitialPosition(x, y, floor: _selectedFloor);
      // Initialize animated position immediately
      _animatedPosition = Offset(x, y);
      _targetPosition = Offset(x, y);
      _hasInitialPosition = true;
      _currentHeading = navProvider.heading;
      _targetHeading = navProvider.heading;
      
      // Perform enhanced auto-calibration
      navProvider.performEnhancedCalibration();
      
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Position set!', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      'Face forward and start walking. The red dot shows your direction.',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
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
          child: InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            minScale: 0.3,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(200),
            child: GestureDetector(
              onTapUp: _onMapTap,
              child: SizedBox(
                width: AppConstants.mapWidth,
                height: AppConstants.mapHeight,
                child: Stack(
                  children: [
                    // Floor Map Background - Use PNG for floors 1, 2, 3
                    if (_selectedFloor >= 1 && _selectedFloor <= 3)
                      Image.asset(
                        'assets/maps/floor_$_selectedFloor.png',
                        width: AppConstants.mapWidth,
                        height: AppConstants.mapHeight,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: AppConstants.mapWidth,
                            height: AppConstants.mapHeight,
                            color: Colors.grey[100],
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.image_not_supported, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text('Floor $_selectedFloor map not available', style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        width: AppConstants.mapWidth,
                        height: AppConstants.mapHeight,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: CustomPaint(
                          size: const Size(
                              AppConstants.mapWidth, AppConstants.mapHeight),
                          painter: FloorMapPainter(
                            rooms: navProvider.rooms
                                .where((r) => r.floor == _selectedFloor)
                                .toList(),
                            showLabels: _showRoomLabels,
                            currentPosition: null,
                            targetRoom: navProvider.targetRoom,
                            heading: navProvider.heading,
                            navigationPath: navProvider.getNavigationPath(),
                            currentFloor: _selectedFloor,
                          ),
                        ),
                      ),
                    // Navigation path overlay
                    if (navProvider.getNavigationPath().length >= 2)
                      CustomPaint(
                        size: const Size(
                            AppConstants.mapWidth, AppConstants.mapHeight),
                        painter: NavigationPathPainter(
                          navigationPath: navProvider.getNavigationPath(),
                          targetRoom: navProvider.targetRoom,
                        ),
                      ),
                    // Room markers overlay
                    if (_showRoomLabels)
                      CustomPaint(
                        size: const Size(
                            AppConstants.mapWidth, AppConstants.mapHeight),
                        painter: RoomMarkersOverlayPainter(
                          rooms: navProvider.rooms
                              .where((r) => r.floor == _selectedFloor)
                              .toList(),
                          targetRoom: navProvider.targetRoom,
                        ),
                      ),
                    // Animated current position overlay - watches provider directly
                    if (navProvider.positionSet)
                      Consumer<NavigationProvider>(
                        builder: (context, nav, _) {
                          final pos = Offset(nav.currentX, nav.currentY);
                          final hdg = nav.heading;
                          
                          // Trigger smooth animation on position change
                          if (pos != _targetPosition) {
                            _animateToPosition(pos);
                          }
                          if ((hdg - _targetHeading).abs() > 1) {
                            _animateToHeading(hdg);
                          }
                          
                          return AnimatedBuilder(
                            animation: Listenable.merge([_positionAnimationController, _headingAnimationController]),
                            builder: (context, child) {
                              final animPos = _positionAnimationController.isAnimating
                                  ? _positionAnimation.value
                                  : _animatedPosition;
                              final animHeading = _headingAnimationController.isAnimating
                                  ? _headingAnimation.value
                                  : _currentHeading;
                              
                              return CustomPaint(
                                size: const Size(AppConstants.mapWidth, AppConstants.mapHeight),
                                painter: PositionOverlayPainter(
                                  currentPosition: animPos,
                                  heading: animHeading,
                                ),
                              );
                            },
                          );
                        },
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

    // Draw floor background with grid
    paint.color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    // Draw grid lines
    paint.color = Colors.grey.withOpacity(0.1);
    paint.strokeWidth = 1;
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw quadrangle (central open area) - example college structure
    if (currentFloor == 0) {
      paint.color = Colors.green.withOpacity(0.15);
      paint.style = PaintingStyle.fill;
      canvas.drawRect(
        const Rect.fromLTWH(150, 150, 300, 250),
        paint,
      );
      paint.color = Colors.green.shade400;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawRect(
        const Rect.fromLTWH(150, 150, 300, 250),
        paint,
      );

      // Quadrangle label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '🌳 Quadrangle',
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(240, 265));
    }

    // Draw corridors
    paint.color = Colors.grey.withOpacity(0.1);
    paint.style = PaintingStyle.fill;

    // Horizontal corridors
    canvas.drawRect(const Rect.fromLTWH(50, 100, 600, 40), paint);
    canvas.drawRect(const Rect.fromLTWH(50, 410, 600, 40), paint);

    // Vertical corridors
    canvas.drawRect(const Rect.fromLTWH(100, 100, 40, 350), paint);
    canvas.drawRect(const Rect.fromLTWH(460, 100, 40, 350), paint);

    // Draw rooms
    for (final room in rooms) {
      final isTarget = targetRoom?.id == room.id;

      // Room background circle
      final roomColor = _getRoomColor(room.roomType);

      // Glow effect for target
      if (isTarget) {
        paint.color = roomColor.withOpacity(0.2);
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(room.xCoordinate, room.yCoordinate),
          20,
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

      // Room icon in center
      final iconPainter = TextPainter(
        text: TextSpan(
          text: _getRoomEmoji(room.roomType),
          style: const TextStyle(fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(
          room.xCoordinate - iconPainter.width / 2,
          room.yCoordinate - iconPainter.height / 2,
        ),
      );

      // Room label
      if (showLabels) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: room.roomNumber,
            style: TextStyle(
              color: isTarget ? Colors.green.shade800 : Colors.black87,
              fontSize: isTarget ? 12 : 10,
              fontWeight: isTarget ? FontWeight.bold : FontWeight.w500,
              backgroundColor: Colors.white.withOpacity(0.7),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        labelPainter.layout();
        labelPainter.paint(
          canvas,
          Offset(
            room.xCoordinate - labelPainter.width / 2,
            room.yCoordinate + 16,
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

    // Note: Current position is now drawn separately by PositionOverlayPainter
    // for smooth animation support
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

  String _getRoomEmoji(String roomType) {
    switch (roomType) {
      case 'classroom':
        return '📚';
      case 'lab':
        return '🔬';
      case 'office':
        return '💼';
      case 'faculty':
        return '👨‍🏫';
      case 'washroom':
        return '🚻';
      case 'auditorium':
        return '🎭';
      case 'library':
        return '📖';
      case 'cafeteria':
        return '☕';
      case 'stairs':
        return '🔼';
      case 'elevator':
        return '🛗';
      default:
        return '📍';
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

/// Position overlay painter for smooth animated red dot movement
class PositionOverlayPainter extends CustomPainter {
  final Offset currentPosition;
  final double heading;

  PositionOverlayPainter({
    required this.currentPosition,
    required this.heading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Outer glow effect for visibility
    paint.color = Colors.red.withOpacity(0.15);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(currentPosition, 40, paint);

    // Accuracy circle
    paint.color = Colors.red.withOpacity(0.1);
    canvas.drawCircle(currentPosition, 30, paint);

    // Direction cone (larger and more visible)
    final headingRad = heading * pi / 180;
    paint.color = Colors.red.withOpacity(0.4);
    final conePath = Path();
    conePath.moveTo(
      currentPosition.dx + 50 * sin(headingRad),
      currentPosition.dy - 50 * cos(headingRad),
    );
    conePath.lineTo(
      currentPosition.dx + 16 * sin(headingRad + pi / 2),
      currentPosition.dy - 16 * cos(headingRad + pi / 2),
    );
    conePath.lineTo(
      currentPosition.dx + 16 * sin(headingRad - pi / 2),
      currentPosition.dy - 16 * cos(headingRad - pi / 2),
    );
    conePath.close();
    canvas.drawPath(conePath, paint);

    // Outer white ring (border)
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(currentPosition, 18, paint);

    // Main red dot (larger)
    paint.color = Colors.red;
    canvas.drawCircle(currentPosition, 15, paint);

    // Inner white highlight
    paint.color = Colors.white;
    canvas.drawCircle(currentPosition, 6, paint);

    // Direction arrow inside dot
    paint.color = Colors.white;
    final arrowPath = Path();
    arrowPath.moveTo(
      currentPosition.dx + 10 * sin(headingRad),
      currentPosition.dy - 10 * cos(headingRad),
    );
    arrowPath.lineTo(
      currentPosition.dx + 4 * sin(headingRad + 2.5),
      currentPosition.dy - 4 * cos(headingRad + 2.5),
    );
    arrowPath.lineTo(
      currentPosition.dx + 4 * sin(headingRad - 2.5),
      currentPosition.dy - 4 * cos(headingRad - 2.5),
    );
    arrowPath.close();
    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(covariant PositionOverlayPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.heading != heading;
  }
}

/// Navigation path painter for SVG map overlay
class NavigationPathPainter extends CustomPainter {
  final List<Offset> navigationPath;
  final Room? targetRoom;

  NavigationPathPainter({
    required this.navigationPath,
    this.targetRoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (navigationPath.length < 2) return;

    final paint = Paint();

    // Draw path shadow
    paint.color = Colors.blue.withOpacity(0.3);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 10;
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
    paint.strokeWidth = 5;

    const dashWidth = 15.0;
    const dashSpace = 8.0;
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

    // Draw target marker if exists
    if (targetRoom != null) {
      final targetPos =
          Offset(targetRoom!.xCoordinate, targetRoom!.yCoordinate);

      // Glow effect
      paint.color = Colors.green.withOpacity(0.3);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(targetPos, 25, paint);

      // Target marker
      paint.color = Colors.green;
      canvas.drawCircle(targetPos, 15, paint);

      paint.color = Colors.white;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3;
      canvas.drawCircle(targetPos, 15, paint);
    }
  }

  @override
  bool shouldRepaint(covariant NavigationPathPainter oldDelegate) {
    return oldDelegate.navigationPath != navigationPath ||
        oldDelegate.targetRoom != targetRoom;
  }
}

/// Room markers overlay painter for SVG map
class RoomMarkersOverlayPainter extends CustomPainter {
  final List<Room> rooms;
  final Room? targetRoom;

  RoomMarkersOverlayPainter({
    required this.rooms,
    this.targetRoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final room in rooms) {
      final isTarget = targetRoom?.id == room.id;

      // Skip if it's the target (drawn by NavigationPathPainter)
      if (isTarget) continue;

      // Small marker for each room from database
      paint.color = _getRoomColor(room.roomType).withOpacity(0.8);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(room.xCoordinate, room.yCoordinate),
        8,
        paint,
      );

      paint.color = Colors.white;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      canvas.drawCircle(
        Offset(room.xCoordinate, room.yCoordinate),
        8,
        paint,
      );
    }
  }

  Color _getRoomColor(String roomType) {
    switch (roomType) {
      case 'classroom':
        return Colors.blue;
      case 'lab':
        return const Color(0xFF00FF9D);
      case 'office':
        return Colors.orange;
      case 'faculty':
        return Colors.purple;
      case 'washroom':
        return const Color(0xFFEB5757);
      case 'auditorium':
        return const Color(0xFFBB6BD9);
      case 'library':
        return Colors.brown;
      case 'cafeteria':
        return Colors.amber;
      case 'stairs':
        return Colors.teal;
      case 'elevator':
        return const Color(0xFFEB5757);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  bool shouldRepaint(covariant RoomMarkersOverlayPainter oldDelegate) {
    return oldDelegate.rooms != rooms || oldDelegate.targetRoom != targetRoom;
  }
}
