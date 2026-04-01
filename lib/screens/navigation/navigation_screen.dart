import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';
import '../../utils/app_theme.dart';
import '../../utils/animations.dart';
import 'room_mapping_dialog.dart';
import 'waypoint_mapping_dialog.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  bool _showRoomLabels = true;
  int _selectedFloor = 0; // Default to ground floor
  String _searchQuery = '';
  String? _lastShownFloorTransitionPromptKey;
  bool _floorTransitionDialogOpen = false;

  // For smooth animation of the red dot
  Offset _animatedPosition = Offset.zero;
  Offset _targetPosition = Offset.zero;
  bool _hasInitialPosition = false;
  bool _isAnimatingPosition = false;

  // Animation controllers for smooth movement
  late AnimationController _positionAnimationController;
  late AnimationController _headingAnimationController;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _headingAnimation;
  double _currentHeading = 0;
  double _targetHeading = 0;

  // Threshold to avoid micro-animations
  static const double _positionThreshold = 2.0;
  static const double _headingThreshold = 10.0; // Increased to prevent spinning

  // Track auto-calibration state for showing completion message
  bool _wasAutoCalibrationPending = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers - using premium durations for smoother movement
    _positionAnimationController = AnimationController(
      vsync: this,
      duration: AnimationDurations.medium,
    );
    _headingAnimationController = AnimationController(
      vsync: this,
      duration: AnimationDurations.mediumLong, // Slower for stability
    );

    _positionAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _positionAnimationController,
      curve: AnimationCurves
          .emphasizedDecelerate, // Premium Material 3 deceleration
    ));

    _headingAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _headingAnimationController,
      curve: AnimationCurves
          .emphasizedDecelerate, // Premium Material 3 deceleration
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navProvider = context.read<NavigationProvider>();
      setState(() {
        _selectedFloor = navProvider.currentFloor;
      });
      // Enable vibration when on navigation screen
      navProvider.setVibrationEnabled(true);
      navProvider.startSensors();
    });
  }

  void _animateToPosition(Offset newPosition) {
    // Skip if position change is too small
    final distance = (_animatedPosition - newPosition).distance;
    if (distance < _positionThreshold && _hasInitialPosition) {
      return;
    }

    if (!_hasInitialPosition) {
      _animatedPosition = newPosition;
      _targetPosition = newPosition;
      _hasInitialPosition = true;
      _isAnimatingPosition = false;
      return;
    }

    // Avoid starting new animation if one is in progress to same target
    if (_isAnimatingPosition &&
        (_targetPosition - newPosition).distance < _positionThreshold) {
      return;
    }

    _targetPosition = newPosition;
    _isAnimatingPosition = true;

    _positionAnimation = Tween<Offset>(
      begin: _animatedPosition,
      end: newPosition,
    ).animate(CurvedAnimation(
      parent: _positionAnimationController,
      curve: AnimationCurves
          .emphasizedDecelerate, // Premium Material 3 deceleration
    ));

    _positionAnimationController.forward(from: 0).then((_) {
      _animatedPosition = newPosition;
      _isAnimatingPosition = false;
    });
  }

  void _animateToHeading(double newHeading) {
    // Normalize heading difference
    double diff = (newHeading - _currentHeading + 540) % 360 - 180;

    // Only animate if change is significant (prevents spinning)
    if (diff.abs() < _headingThreshold) {
      return;
    }

    // Limit rotation speed to prevent wild spinning
    const maxRotationPerFrame = 30.0;
    if (diff.abs() > maxRotationPerFrame) {
      diff = diff.sign * maxRotationPerFrame;
    }

    // Calculate shortest rotation path
    double targetHeading = _currentHeading + diff;

    _headingAnimation = Tween<double>(
      begin: _currentHeading,
      end: targetHeading,
    ).animate(CurvedAnimation(
      parent: _headingAnimationController,
      curve: AnimationCurves
          .emphasizedDecelerate, // Premium Material 3 deceleration
    ));

    _headingAnimationController.forward(from: 0).then((_) {
      _currentHeading = newHeading;
    });

    _targetHeading = newHeading;
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
      _handleAdminModeTap(x, y, navProvider);
    } else if (!navProvider.positionSet) {
      // Reset animation state before setting new position
      _positionAnimationController.stop();
      _headingAnimationController.stop();
      _isAnimatingPosition = false;

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

      PremiumSnackBar.showSuccess(
        context,
        'Position set! Face forward and start walking.',
      );
    } else {
      // Position is set - check if user tapped on a room or waypoint
      final tappedRoom = navProvider.getRoomAtPosition(
        x,
        y,
        threshold: 25,
        floor: _selectedFloor,
      );
      if (tappedRoom != null) {
        HapticFeedback.lightImpact();
        _showRoomDetailSheet(tappedRoom);
        return;
      }

      final tappedWaypoint = navProvider.getWaypointAtPosition(
        x,
        y,
        threshold: 30,
        floor: _selectedFloor,
      );
      if (tappedWaypoint != null) {
        HapticFeedback.lightImpact();
        _showWaypointDetailPopup(tappedWaypoint);
      }
    }
  }

  void _showRoomDetailSheet(Room room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => _RoomDetailSheet(
        room: room,
        onNavigate: () {
          Navigator.pop(context);
          final navProvider = context.read<NavigationProvider>();
          navProvider.setTargetRoom(room);
        },
      ),
    );
  }

  void _showWaypointDetailPopup(NavigationWaypoint waypoint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => _WaypointDetailSheet(waypoint: waypoint),
    );
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Smart Auto-Calibration Option
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.teal.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.auto_fix_high,
                        color: Colors.green, size: 28),
                    const SizedBox(height: 8),
                    const Text(
                      'Smart Auto-Calibration',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Walk a few steps and the compass will calibrate automatically based on your movement direction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        navProvider.startSmartAutoCalibration();
                        Navigator.of(context).pop();
                        _showSmartCalibrationStarted();
                      },
                      icon: const Icon(Icons.directions_walk, size: 18),
                      label: const Text('Start Smart Calibration'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // Manual Calibration
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.explore, color: Colors.blue, size: 24),
                    SizedBox(height: 8),
                    Text(
                      'Manual Calibration',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Face a known direction and select it below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('I am facing:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
                      navProvider.calibrateToDirection(heading);
                      Navigator.of(context).pop();
                      _showCalibrationSuccess();
                    }
                  },
                ),
              ),
            ],
          ),
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

  void _showSmartCalibrationStarted() {
    PremiumSnackBar.showInfo(
      context,
      'Walk a few steps to auto-calibrate...',
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
        navProvider.calibrateToDirection(heading);
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
    PremiumSnackBar.showSuccess(
      context,
      'Compass calibrated! Navigation is now more accurate.',
    );
  }

  void _showFloorTransitionDialog() {
    if (_floorTransitionDialogOpen) return;

    final navProvider = context.read<NavigationProvider>();
    if (!navProvider.hasPendingFloorTransitionPrompt) return;

    final waypoint = navProvider.pendingFloorTransitionWaypoint;
    final targetFloor = navProvider.pendingFloorTransitionTargetFloor;
    if (targetFloor == null) return;

    final isElevator = waypoint?.waypointType == 'elevator';
    final transitionType = isElevator ? 'elevator' : 'stairs';
    _floorTransitionDialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isElevator ? Icons.elevator : Icons.stairs,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            const Text('Change Floor'),
          ],
        ),
        content: Text(
          'You reached ${waypoint?.name ?? transitionType}.\n'
          'Move to floor $targetFloor and continue navigation?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              navProvider.dismissPendingFloorTransitionPrompt();
              Navigator.of(context).pop();
            },
            child: const Text('Not now'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final changed =
                  navProvider.completePendingFloorTransitionAndRecalibrate();
              Navigator.of(context).pop();

              if (changed && mounted) {
                setState(() {
                  _selectedFloor = navProvider.currentFloor;
                });
                PremiumSnackBar.showInfo(
                  context,
                  'Switched to floor $targetFloor. Recalibrating compass...',
                );
              }
            },
            icon: const Icon(Icons.check_circle_outline),
            label: Text('I reached floor $targetFloor'),
          ),
        ],
      ),
    ).whenComplete(() {
      _floorTransitionDialogOpen = false;
    });
  }

  void _handleAdminModeTap(double x, double y, NavigationProvider navProvider) {
    final editMode = navProvider.adminEditMode;

    // Check if tapped on an existing waypoint
    final tappedWaypoint = navProvider.getWaypointAtPosition(
      x,
      y,
      threshold: 30,
      floor: _selectedFloor,
    );

    switch (editMode) {
      case 'quickAdd':
        // Quickly add a waypoint without dialog
        if (tappedWaypoint != null) {
          // Open edit dialog for existing waypoint
          _showWaypointMappingDialog(x, y);
        } else {
          _quickAddWaypoint(x, y, navProvider);
        }
        break;

      case 'connect':
        if (tappedWaypoint != null) {
          HapticFeedback.lightImpact();
          navProvider.selectWaypointForConnect(tappedWaypoint);
        } else {
          PremiumSnackBar.showWarning(
            context,
            'Tap on a waypoint to connect',
          );
        }
        break;

      case 'delete':
        if (tappedWaypoint != null) {
          _confirmDeleteWaypoint(tappedWaypoint, navProvider);
        } else {
          PremiumSnackBar.showWarning(
            context,
            'Tap on a waypoint to delete',
          );
        }
        break;

      default: // 'normal' mode
        _showAdminOptionsDialog(x, y);
        break;
    }
  }

  Future<void> _quickAddWaypoint(
      double x, double y, NavigationProvider navProvider) async {
    HapticFeedback.mediumImpact();

    // Create a quick waypoint with auto-generated name
    final waypointCount =
        navProvider.waypoints.where((w) => w.floor == _selectedFloor).length;
    final name = 'WP${waypointCount + 1}';

    final waypoint = await navProvider.createWaypoint(
      name: name,
      floor: _selectedFloor,
      x: x,
      y: y,
      waypointType: 'corridor',
    );

    if (mounted) {
      if (waypoint != null) {
        PremiumSnackBar.showSuccess(
          context,
          'Added "$name" - Tap to edit or connect',
        );
      }
    }
  }

  void _confirmDeleteWaypoint(
      NavigationWaypoint waypoint, NavigationProvider navProvider) {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Waypoint',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete "${waypoint.name ?? "Waypoint"}"?',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'All connections to this waypoint will also be removed.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await navProvider.deleteWaypoint(waypoint.id);
              if (mounted && success) {
                PremiumSnackBar.showSuccess(
                  context,
                  'Deleted "${waypoint.name ?? "Waypoint"}"',
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAdminOptionsDialog(double x, double y) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gradientStart.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings,
                  color: AppColors.gradientStart, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Admin Action', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Position: (${x.toInt()}, ${y.toInt()})',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _buildAdminOptionTile(
              icon: Icons.room,
              title: 'Add Room',
              subtitle: 'Create a new room at this location',
              onTap: () {
                Navigator.of(context).pop();
                _showRoomMappingDialog(x, y);
              },
            ),
            const SizedBox(height: 8),
            _buildAdminOptionTile(
              icon: Icons.add_location_alt,
              title: 'Add/Edit Waypoint',
              subtitle: 'Create or edit navigation waypoint',
              onTap: () {
                Navigator.of(context).pop();
                _showWaypointMappingDialog(x, y);
              },
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

  Widget _buildAdminOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _showRoomMappingDialog(double x, double y) {
    showDialog(
      context: context,
      builder: (context) => RoomMappingDialog(x: x, y: y),
    );
  }

  void _showWaypointMappingDialog(double x, double y) {
    showDialog(
      context: context,
      builder: (context) =>
          WaypointMappingDialog(x: x, y: y, floor: _selectedFloor),
    );
  }

  void _showRoomSelector() {
    final navProvider = context.read<NavigationProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  minChildSize: 0.3,
                  maxChildSize: 0.95,
                  expand: false,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28)),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 5,
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, AppColors.accentLight],
                            ).createShader(bounds),
                            child: const Text(
                              'Select Destination',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Search bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: TextField(
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Search rooms...',
                                  hintStyle:
                                      const TextStyle(color: Colors.white38),
                                  prefixIcon: ShaderMask(
                                    shaderCallback: (bounds) => AppGradients
                                        .accent
                                        .createShader(bounds),
                                    child: const Icon(Icons.search,
                                        color: Colors.white),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                                onChanged: (value) {
                                  setSheetState(() {
                                    _searchQuery = value;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Floor filter chips
                          SizedBox(
                            height: 44,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: 5,
                              itemBuilder: (context, index) {
                                final isSelected = _selectedFloor == index;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() {
                                        _selectedFloor = index;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: AnimationDurations.short,
                                      curve:
                                          AnimationCurves.emphasizedDecelerate,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? AppGradients.primary
                                            : null,
                                        color: isSelected
                                            ? null
                                            : Colors.white
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.gradientStart
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        'Floor $index',
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white60,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (filteredRooms.isEmpty)
                            const Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off,
                                        size: 56, color: Colors.white24),
                                    SizedBox(height: 12),
                                    Text(
                                      'No rooms found',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                controller: scrollController,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filteredRooms.length,
                                itemBuilder: (context, index) {
                                  final room = filteredRooms[index];
                                  return _buildRoomTile(room, navProvider);
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoomTile(Room room, NavigationProvider navProvider) {
    final authProvider = context.read<AuthProvider>();
    final isTeacher = authProvider.isTeacher;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            navProvider.navigateToRoom(room);
            Navigator.of(context).pop();
          },
          onLongPress: isTeacher
              ? () {
                  HapticFeedback.heavyImpact();
                  _showRoomOptionsDialog(room, navProvider);
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: _getRoomGradient(room.roomType),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getRoomIcon(room.roomType),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.displayName ?? room.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoomColor(room.roomType)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              room.roomNumber,
                              style: TextStyle(
                                color: _getRoomColor(room.roomType),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.layers,
                              size: 12, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(
                            'Floor ${room.floor}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit button for teachers
                if (isTeacher) ...[
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showRoomOptionsDialog(room, navProvider);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8, bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          size: 16, color: AppColors.warning),
                    ),
                  ),
                ],
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.navigation,
                      size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRoomOptionsDialog(Room room, NavigationProvider navProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardDark.withValues(alpha: 0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: _getRoomGradient(room.roomType),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getRoomIcon(room.roomType),
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
                            room.displayName ?? room.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Room ${room.roomNumber} • Floor ${room.floor}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Navigate option
                _buildOptionTile(
                  icon: Icons.navigation_rounded,
                  label: 'Navigate to Room',
                  subtitle: 'Get directions to this room',
                  gradient: AppGradients.accent,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Close room selector too
                    navProvider.navigateToRoom(room);
                  },
                ),
                const SizedBox(height: 12),
                // Edit option
                _buildOptionTile(
                  icon: Icons.edit_rounded,
                  label: 'Edit Room Details',
                  subtitle: 'Change display name, type, capacity',
                  gradient: AppGradients.warning,
                  onTap: () {
                    Navigator.pop(context);
                    _showEditRoomDialog(room, navProvider);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditRoomDialog(Room room, NavigationProvider navProvider) {
    final displayNameController =
        TextEditingController(text: room.displayName ?? room.name);
    final capacityController =
        TextEditingController(text: room.capacity.toString());
    String selectedRoomType = room.roomType;

    final roomTypes = [
      'classroom',
      'lab',
      'office',
      'faculty',
      'washroom',
      'auditorium',
      'library',
      'cafeteria',
      'stairs',
      'elevator',
      'other'
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppGradients.warning,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Room',
                      style:
                          TextStyle(color: AppColors.textPrimary, fontSize: 18),
                    ),
                    Text(
                      'Room ${room.roomNumber}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: displayNameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    hintText: 'e.g., Computer Lab 1',
                    hintStyle: TextStyle(
                        color: AppColors.textMuted.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: AppColors.glassDark,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.warning),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: roomTypes.contains(selectedRoomType)
                      ? selectedRoomType
                      : roomTypes.first,
                  dropdownColor: AppColors.cardDark,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Room Type',
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.glassDark,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                  ),
                  items: roomTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(_getRoomIcon(type),
                                    size: 18, color: _getRoomColor(type)),
                                const SizedBox(width: 10),
                                Text(type.toUpperCase(),
                                    style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(
                      () => selectedRoomType = value ?? 'classroom'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Capacity',
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    hintText: 'Number of seats',
                    hintStyle: TextStyle(
                        color: AppColors.textMuted.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: AppColors.glassDark,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.warning),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final displayName = displayNameController.text.trim();
                final capacity =
                    int.tryParse(capacityController.text) ?? room.capacity;

                if (displayName.isEmpty) {
                  PremiumSnackBar.showError(
                      context, 'Display name cannot be empty');
                  return;
                }

                try {
                  final updated =
                      await SupabaseService.updateRoomFromMap(room.id, {
                    'display_name': displayName,
                    'room_type': selectedRoomType,
                    'capacity': capacity,
                  });

                  if (updated) {
                    Navigator.pop(dialogContext);
                    // Reload rooms
                    await navProvider.refreshRooms();
                    if (mounted) {
                      PremiumSnackBar.showSuccess(
                          context, 'Room updated successfully!');
                    }
                  } else {
                    PremiumSnackBar.showError(context, 'Failed to update room');
                  }
                } catch (e) {
                  PremiumSnackBar.showError(context, 'Error: $e');
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getRoomGradient(String roomType) {
    switch (roomType) {
      case 'classroom':
        return AppGradients.info;
      case 'lab':
        return AppGradients.success;
      case 'office':
        return AppGradients.warning;
      case 'faculty':
        return AppGradients.primary;
      case 'washroom':
        return LinearGradient(
            colors: [Colors.grey.shade600, Colors.grey.shade800]);
      case 'auditorium':
        return AppGradients.error;
      case 'library':
        return LinearGradient(
            colors: [Colors.brown.shade400, Colors.brown.shade700]);
      case 'cafeteria':
        return LinearGradient(
            colors: [Colors.amber.shade400, Colors.orange.shade600]);
      case 'stairs':
        return AppGradients.secondary;
      case 'elevator':
        return LinearGradient(
            colors: [Colors.indigo.shade400, Colors.indigo.shade700]);
      default:
        return AppGradients.accent;
    }
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
    final visibleNavigationPath =
        navProvider.getNavigationPathForFloor(_selectedFloor);

    // Check for auto-calibration completion
    if (_wasAutoCalibrationPending &&
        !navProvider.autoCalibrationPending &&
        navProvider.isCalibrated) {
      _wasAutoCalibrationPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCalibrationSuccess();
      });
    }
    if (navProvider.autoCalibrationPending && !_wasAutoCalibrationPending) {
      _wasAutoCalibrationPending = true;
    }

    final pendingPromptKey = navProvider.pendingFloorTransitionKey;
    if (navProvider.hasPendingFloorTransitionPrompt &&
        pendingPromptKey != null &&
        !_floorTransitionDialogOpen &&
        _lastShownFloorTransitionPromptKey != pendingPromptKey) {
      _lastShownFloorTransitionPromptKey = pendingPromptKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showFloorTransitionDialog();
        }
      });
    }

    return SafeArea(
      top: false, // Parent handles top padding
      bottom: false, // Parent handles bottom padding
      child: Column(
        children: [
          // Premium Control Bar
          _buildPremiumControlBar(navProvider, authProvider),

          // Admin Mode Indicator Panel
          if (navProvider.isAdminMode) _buildAdminModeIndicator(navProvider),

          // Navigation Info Panel
          if ((navProvider.isNavigating || !navProvider.positionSet) &&
              !navProvider.isAdminMode)
            _buildNavigationInfoPanel(navProvider),

          // Map View
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
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
                        _buildFloorMapBackground(navProvider),
                        // Waypoint paths overlay (RED walkable roads)
                        CustomPaint(
                          size: const Size(
                              AppConstants.mapWidth, AppConstants.mapHeight),
                          painter: WaypointPathsPainter(
                            waypoints: navProvider.waypoints
                                .where((w) => w.floor == _selectedFloor)
                                .toList(),
                            connections: navProvider.waypointConnections,
                            allWaypoints: navProvider.waypoints,
                            isAdminMode: navProvider.isAdminMode,
                          ),
                        ),
                        // Navigation path overlay
                        if (visibleNavigationPath.length >= 2)
                          CustomPaint(
                            size: const Size(
                                AppConstants.mapWidth, AppConstants.mapHeight),
                            painter: NavigationPathPainter(
                              navigationPath: visibleNavigationPath,
                              targetRoom:
                                  navProvider.targetRoom?.floor == _selectedFloor
                                      ? navProvider.targetRoom
                                      : null,
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
                        // Animated current position overlay
                        if (navProvider.positionSet &&
                            navProvider.currentFloor == _selectedFloor)
                          Consumer<NavigationProvider>(
                            builder: (context, nav, _) {
                              final pos = Offset(nav.currentX, nav.currentY);
                              final hdg = nav.heading;

                              if (pos != _targetPosition) {
                                _animateToPosition(pos);
                              }
                              if ((hdg - _targetHeading).abs() > 1) {
                                _animateToHeading(hdg);
                              }

                              return AnimatedBuilder(
                                animation: Listenable.merge([
                                  _positionAnimationController,
                                  _headingAnimationController
                                ]),
                                builder: (context, child) {
                                  final animPos =
                                      _positionAnimationController.isAnimating
                                          ? _positionAnimation.value
                                          : _animatedPosition;
                                  final animHeading =
                                      _headingAnimationController.isAnimating
                                          ? _headingAnimation.value
                                          : _currentHeading;

                                  return CustomPaint(
                                    size: const Size(AppConstants.mapWidth,
                                        AppConstants.mapHeight),
                                    painter: PositionOverlayPainter(
                                      currentPosition: animPos,
                                      heading: animHeading,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        // Premium Floor indicator overlay
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _buildFloorIndicator(),
                        ),
                        // Premium Compass rose
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _buildPremiumCompass(navProvider.heading),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Premium Status Bar
          _buildPremiumStatusBar(navProvider),
        ],
      ),
    );
  }

  Widget _buildPremiumControlBar(
      NavigationProvider navProvider, AuthProvider authProvider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                // Floor selector and destination row
                Row(
                  children: [
                    // Premium Floor Selector
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppGradients.primarySubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedFloor,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white70),
                          items: List.generate(5, (index) {
                            return DropdownMenuItem(
                              value: index,
                              child: Text('F$index'),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedFloor = value;
                              });
                              navProvider.setCurrentFloor(value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showRoomSelector,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                AppColors.surfaceLight.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    AppGradients.accent.createShader(bounds),
                                child: const Icon(Icons.location_searching,
                                    size: 20, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  navProvider.targetRoom?.name ??
                                      'Select Destination',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: navProvider.targetRoom != null
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 14, color: Colors.white38),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (navProvider.isNavigating) ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            navProvider.stopNavigation();
                          },
                          icon: const Icon(Icons.close, color: AppColors.error),
                          tooltip: 'Stop Navigation',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Control buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPremiumControlButton(
                      icon: navProvider.sensorsActive
                          ? Icons.sensors
                          : Icons.sensors_off,
                      label: 'Sensors',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (navProvider.sensorsActive) {
                          navProvider.stopSensors();
                        } else {
                          navProvider.startSensors();
                        }
                      },
                      isActive: navProvider.sensorsActive,
                      gradient: AppGradients.info,
                    ),
                    _buildPremiumControlButton(
                      icon: Icons.explore,
                      label: 'Calibrate',
                      onPressed: navProvider.positionSet
                          ? _showCalibrationDialog
                          : null,
                      isActive: navProvider.isCalibrated,
                      gradient: AppGradients.success,
                    ),
                    _buildPremiumControlButton(
                      icon: Icons.my_location,
                      label: 'Reset',
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        navProvider.resetPosition();
                      },
                      gradient: AppGradients.warning,
                    ),
                    _buildPremiumControlButton(
                      icon: _showRoomLabels ? Icons.label : Icons.label_off,
                      label: 'Labels',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _showRoomLabels = !_showRoomLabels;
                        });
                      },
                      isActive: _showRoomLabels,
                      gradient: AppGradients.accent,
                    ),
                    if (authProvider.isAdmin || authProvider.isTeacher)
                      _buildPremiumControlButton(
                        icon: Icons.edit_location_alt,
                        label: 'Admin',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          navProvider.toggleAdminMode();
                        },
                        isActive: navProvider.isAdminMode,
                        gradient: AppGradients.error,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isActive = false,
    required LinearGradient gradient,
  }) {
    final isDisabled = onPressed == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: AnimationDurations.short,
            curve: AnimationCurves.emphasizedDecelerate,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isActive ? gradient : null,
              color: isActive
                  ? null
                  : (isDisabled
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(14),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.gradientStart.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive
                  ? Colors.white
                  : (isDisabled ? Colors.white24 : Colors.white70),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDisabled ? Colors.white24 : Colors.white60,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminModeIndicator(NavigationProvider navProvider) {
    final waypointCount =
        navProvider.waypoints.where((w) => w.floor == _selectedFloor).length;
    final connectionCount = navProvider.waypointConnections.length;
    final editMode = navProvider.adminEditMode;
    final selectedWp = navProvider.selectedWaypointForConnect;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withValues(alpha: 0.3),
                  Colors.orange.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_road,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Waypoint Editor',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _getEditModeDescription(editMode, selectedWp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => navProvider.toggleAdminMode(),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Exit',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Edit Mode Buttons
                Row(
                  children: [
                    _buildEditModeButton(
                      navProvider,
                      'normal',
                      Icons.touch_app,
                      'Edit',
                      Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    _buildEditModeButton(
                      navProvider,
                      'quickAdd',
                      Icons.add_location,
                      'Add',
                      Colors.green,
                    ),
                    const SizedBox(width: 6),
                    _buildEditModeButton(
                      navProvider,
                      'connect',
                      Icons.link,
                      'Connect',
                      Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    _buildEditModeButton(
                      navProvider,
                      'delete',
                      Icons.delete,
                      'Delete',
                      Colors.red,
                    ),
                  ],
                ),

                // Selected waypoint indicator for connect mode
                if (editMode == 'connect' && selectedWp != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: Colors.orange, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Selected: ${selectedWp.name ?? "Waypoint"} • Tap another to connect',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => navProvider.clearSelectedWaypoint(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildAdminStatChip(
                        Icons.location_on, '$waypointCount', 'Waypoints'),
                    _buildAdminStatChip(
                        Icons.route, '$connectionCount', 'Connections'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers,
                              size: 12, color: Colors.white70),
                          const SizedBox(width: 3),
                          Text('Floor $_selectedFloor',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getEditModeDescription(String mode, NavigationWaypoint? selectedWp) {
    switch (mode) {
      case 'quickAdd':
        return 'Tap anywhere to quickly add a waypoint';
      case 'connect':
        return selectedWp == null
            ? 'Tap a waypoint to start connecting'
            : 'Tap another waypoint to create path';
      case 'delete':
        return 'Tap a waypoint to delete it';
      default:
        return 'Tap waypoints to edit, or map to add';
    }
  }

  Widget _buildEditModeButton(
    NavigationProvider navProvider,
    String mode,
    IconData icon,
    String label,
    Color color,
  ) {
    final isActive = navProvider.adminEditMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          navProvider.setAdminEditMode(mode);
        },
        child: AnimatedContainer(
          duration: AnimationDurations.short,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(colors: [color, color.withValues(alpha: 0.7)])
                : null,
            color: isActive ? null : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? color : Colors.white.withValues(alpha: 0.2),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isActive ? Colors.white : color, size: 16),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.red.shade300),
          const SizedBox(width: 3),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildNavigationInfoPanel(NavigationProvider navProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: AnimationDurations.medium,
            curve: AnimationCurves.emphasizedDecelerate,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: navProvider.hasReachedDestination
                  ? AppGradients.success
                  : LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.3),
                        AppColors.gradientStart.withValues(alpha: 0.2),
                      ],
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    navProvider.hasReachedDestination
                        ? Icons.check_circle
                        : navProvider.positionSet
                            ? Icons.directions_walk
                            : Icons.touch_app,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        navProvider.getNavigationInstructions(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      if (navProvider.isNavigating)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              _buildPremiumNavChip(
                                Icons.straighten,
                                '${navProvider.distanceToTarget.toStringAsFixed(0)} px',
                              ),
                              const SizedBox(width: 8),
                              _buildPremiumNavChip(
                                Icons.timer,
                                navProvider.getEstimatedTime(),
                              ),
                              const SizedBox(width: 8),
                              _buildPremiumNavChip(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.celebration, color: Colors.white, size: 16),
                        SizedBox(width: 6),
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
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumNavChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorIndicator() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppGradients.primarySubtle,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.layers, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Floor $_selectedFloor',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumCompass(double heading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.2), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: CustomPaint(
            painter: PremiumCompassPainter(heading: heading),
          ),
        ),
      ),
    );
  }

  Widget _buildMapFallback() {
    return Container(
      width: AppConstants.mapWidth,
      height: AppConstants.mapHeight,
      color: AppColors.primaryDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported,
                size: 64, color: Colors.white24),
            const SizedBox(height: 8),
            Text('Floor $_selectedFloor map not available',
                style: const TextStyle(color: Colors.white38)),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorMapBackground(NavigationProvider navProvider) {
    if (_selectedFloor == 0) {
      return Image.asset(
        'assets/maps/Floor0.png',
        width: AppConstants.mapWidth,
        height: AppConstants.mapHeight,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildMapFallback();
        },
      );
    }

    if (_selectedFloor >= 1 && _selectedFloor <= 3) {
      return Image.asset(
        'assets/maps/floor_$_selectedFloor.png',
        width: AppConstants.mapWidth,
        height: AppConstants.mapHeight,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildMapFallback();
        },
      );
    }

    return _buildMapPlaceholder(navProvider);
  }

  Widget _buildMapPlaceholder(NavigationProvider navProvider) {
    return Container(
      width: AppConstants.mapWidth,
      height: AppConstants.mapHeight,
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(
        size: const Size(AppConstants.mapWidth, AppConstants.mapHeight),
        painter: FloorMapPainter(
          rooms: navProvider.rooms
              .where((r) => r.floor == _selectedFloor)
              .toList(),
          showLabels: _showRoomLabels,
          currentPosition: null,
          targetRoom: navProvider.targetRoom?.floor == _selectedFloor
              ? navProvider.targetRoom
              : null,
          heading: navProvider.heading,
          navigationPath: navProvider.getNavigationPathForFloor(_selectedFloor),
          currentFloor: _selectedFloor,
        ),
      ),
    );
  }

  Widget _buildPremiumStatusBar(NavigationProvider navProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPremiumStatusItem(
                  Icons.location_on,
                  navProvider.positionSet
                      ? '(${navProvider.currentX.toInt()}, ${navProvider.currentY.toInt()})'
                      : 'Tap to set',
                  'Position',
                  AppColors.info,
                ),
                _buildStatusDivider(),
                _buildPremiumStatusItem(
                  Icons.explore,
                  '${navProvider.heading.toStringAsFixed(0)}°',
                  'Heading',
                  AppColors.accent,
                ),
                _buildStatusDivider(),
                _buildPremiumStatusItem(
                  Icons.directions_walk,
                  '${navProvider.stepCount}',
                  'Steps',
                  AppColors.success,
                ),
                _buildStatusDivider(),
                _buildPremiumStatusItem(
                  navProvider.isCalibrated
                      ? Icons.check_circle
                      : Icons.error_outline,
                  navProvider.isCalibrated ? 'Ready' : 'Needed',
                  'Calibration',
                  navProvider.isCalibrated
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumStatusItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
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
    paint.color = Colors.grey.withValues(alpha: 0.1);
    paint.strokeWidth = 1;
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw quadrangle (central open area) - example college structure
    if (currentFloor == 0) {
      paint.color = Colors.green.withValues(alpha: 0.15);
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
    paint.color = Colors.grey.withValues(alpha: 0.1);
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
        paint.color = roomColor.withValues(alpha: 0.2);
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
              backgroundColor: Colors.white.withValues(alpha: 0.7),
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

    // Draw navigation path (BRIGHT GREEN color to differentiate from red waypoint paths)
    if (navigationPath.length >= 2) {
      final navPath = Path();
      navPath.moveTo(navigationPath[0].dx, navigationPath[0].dy);
      for (int i = 1; i < navigationPath.length; i++) {
        navPath.lineTo(navigationPath[i].dx, navigationPath[i].dy);
      }

      // Layer 1: Outer glow shadow
      paint.color = const Color(0xFF00FF88).withValues(alpha: 0.2);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 24;
      paint.strokeCap = StrokeCap.round;
      paint.strokeJoin = StrokeJoin.round;
      canvas.drawPath(navPath, paint);

      // Layer 2: Medium glow
      paint.color = const Color(0xFF00FF88).withValues(alpha: 0.4);
      paint.strokeWidth = 16;
      canvas.drawPath(navPath, paint);

      // Layer 3: White edge for visibility
      paint.color = Colors.white.withValues(alpha: 0.8);
      paint.strokeWidth = 10;
      canvas.drawPath(navPath, paint);

      // Layer 4: Main bright green path
      paint.color = const Color(0xFF00FF88);
      paint.strokeWidth = 7;
      canvas.drawPath(navPath, paint);

      // Layer 5: Inner highlight
      paint.color = const Color(0xFFAAFFDD);
      paint.strokeWidth = 3;
      canvas.drawPath(navPath, paint);

      // Draw direction arrows along the path
      for (final metric in navPath.computeMetrics()) {
        for (double d = 50; d < metric.length - 30; d += 80) {
          final tangent = metric.getTangentForOffset(d);
          if (tangent != null) {
            final pos = tangent.position;
            final angle = tangent.angle;

            canvas.save();
            canvas.translate(pos.dx, pos.dy);
            canvas.rotate(angle);

            // Draw arrow
            final arrowPath = Path();
            arrowPath.moveTo(-8, -6);
            arrowPath.lineTo(8, 0);
            arrowPath.lineTo(-8, 6);
            arrowPath.close();

            paint.color = Colors.white;
            paint.style = PaintingStyle.fill;
            canvas.drawPath(arrowPath, paint);

            canvas.restore();
          }
        }
      }

      // Draw waypoint dots on destination path (green pulse effect)
      paint.style = PaintingStyle.fill;
      for (int i = 1; i < navigationPath.length - 1; i++) {
        // Outer glow
        paint.color = const Color(0xFF00FF88).withValues(alpha: 0.5);
        canvas.drawCircle(navigationPath[i], 12, paint);
        // White ring
        paint.color = Colors.white;
        canvas.drawCircle(navigationPath[i], 8, paint);
        // Main green
        paint.color = const Color(0xFF00FF88);
        canvas.drawCircle(navigationPath[i], 6, paint);
        // Inner white
        paint.color = Colors.white;
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

/// Premium compass painter with gradient styling
class PremiumCompassPainter extends CustomPainter {
  final double heading;

  PremiumCompassPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final paint = Paint();

    // Outer ring gradient
    paint.shader = const LinearGradient(
      colors: [AppColors.gradientStart, AppColors.gradientEnd],
    ).createShader(Rect.fromCircle(center: center, radius: radius + 4));
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawCircle(center, radius + 2, paint);
    paint.shader = null;

    // Background circle
    paint.color = AppColors.surface;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    // Subtle grid lines
    paint.color = Colors.white.withValues(alpha: 0.1);
    paint.strokeWidth = 0.5;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius + 4),
      Offset(center.dx, center.dy + radius - 4),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - radius + 4, center.dy),
      Offset(center.dx + radius - 4, center.dy),
      paint,
    );

    // Rotate canvas for heading
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * pi / 180);
    canvas.translate(-center.dx, -center.dy);

    // North indicator with gradient
    const northGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.error, Color(0xFFFF6B6B)],
    );
    paint.shader = northGradient.createShader(Rect.fromLTWH(
      center.dx - 8,
      center.dy - radius + 2,
      16,
      radius - 2,
    ));
    paint.style = PaintingStyle.fill;
    final northPath = Path();
    northPath.moveTo(center.dx, center.dy - radius + 6);
    northPath.lineTo(center.dx - 7, center.dy - 2);
    northPath.lineTo(center.dx + 7, center.dy - 2);
    northPath.close();
    canvas.drawPath(northPath, paint);
    paint.shader = null;

    // South indicator
    paint.color = Colors.white.withValues(alpha: 0.4);
    final southPath = Path();
    southPath.moveTo(center.dx, center.dy + radius - 6);
    southPath.lineTo(center.dx - 6, center.dy + 2);
    southPath.lineTo(center.dx + 6, center.dy + 2);
    southPath.close();
    canvas.drawPath(southPath, paint);

    // Center dot
    paint.color = Colors.white;
    canvas.drawCircle(center, 4, paint);
    paint.color = AppColors.accent;
    canvas.drawCircle(center, 2, paint);

    canvas.restore();

    // Direction labels
    final directions = ['N', 'E', 'S', 'W'];
    final angles = [0.0, 90.0, 180.0, 270.0];
    final colors = [
      AppColors.error,
      Colors.white54,
      Colors.white54,
      Colors.white54
    ];

    for (int i = 0; i < 4; i++) {
      final angle = (angles[i] - heading) * pi / 180;
      final labelRadius = radius - 10;
      final x = center.dx + labelRadius * sin(angle);
      final y = center.dy - labelRadius * cos(angle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: TextStyle(
            color: colors[i],
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PremiumCompassPainter oldDelegate) {
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
    paint.color = Colors.red.withValues(alpha: 0.15);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(currentPosition, 40, paint);

    // Accuracy circle
    paint.color = Colors.red.withValues(alpha: 0.1);
    canvas.drawCircle(currentPosition, 30, paint);

    // Direction cone (larger and more visible)
    final headingRad = heading * pi / 180;
    paint.color = Colors.red.withValues(alpha: 0.4);
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

/// Navigation path painter for SVG map overlay - RED PATH with animated waypoints
class NavigationPathPainter extends CustomPainter {
  final List<Offset> navigationPath;
  final Room? targetRoom;

  NavigationPathPainter({
    required this.navigationPath,
    this.targetRoom,
  });

  /// Create a smoothed path using quadratic Bezier curves at corners
  Path _createSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.length < 2) return path;

    if (points.length == 2) {
      path.moveTo(points[0].dx, points[0].dy);
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    // Corner smoothing radius - larger = smoother turns
    const smoothRadius = 25.0;

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];

      // Calculate vectors to adjacent points
      final toPrev = prev - curr;
      final toNext = next - curr;

      // Calculate distances
      final distPrev = toPrev.distance;
      final distNext = toNext.distance;

      // Limit smooth radius to half the shortest segment
      final maxRadius = (distPrev < distNext ? distPrev : distNext) / 2;
      final radius = smoothRadius < maxRadius ? smoothRadius : maxRadius;

      // Calculate start and end points of the curve
      final startPoint = curr + (toPrev / distPrev) * radius;
      final endPoint = curr + (toNext / distNext) * radius;

      // Draw line to curve start
      path.lineTo(startPoint.dx, startPoint.dy);

      // Draw smooth quadratic bezier curve through the corner
      path.quadraticBezierTo(curr.dx, curr.dy, endPoint.dx, endPoint.dy);
    }

    // Draw final segment
    path.lineTo(points.last.dx, points.last.dy);

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (navigationPath.length < 2) return;

    final paint = Paint();

    // BRIGHT GREEN navigation path color
    const pathColor = Color(0xFF00FF88);

    // Create smooth path with rounded corners
    final smoothPath = _createSmoothPath(navigationPath);

    // Draw path shadow (green glow effect)
    paint.color = pathColor.withValues(alpha: 0.25);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 14;
    paint.strokeCap = StrokeCap.round;
    paint.strokeJoin = StrokeJoin.round;
    canvas.drawPath(smoothPath, paint);

    // Draw outer green path
    paint.color = pathColor.withValues(alpha: 0.6);
    paint.strokeWidth = 10;
    canvas.drawPath(smoothPath, paint);

    // Draw main green path with dashed line
    paint.color = pathColor;
    paint.strokeWidth = 6;

    const dashWidth = 18.0;
    const dashSpace = 10.0;
    var distance = 0.0;

    // Use smooth path for dashed line
    final path = smoothPath;

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

    // Draw center white dashed line for road effect
    paint.color = Colors.white.withValues(alpha: 0.7);
    paint.strokeWidth = 2;
    distance = 0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final extractPath = metric.extractPath(
          distance,
          distance + 8,
        );
        canvas.drawPath(extractPath, paint);
        distance += 20;
      }
      distance = 0;
    }

    // Draw waypoint dots on path (green pulsing effect)
    paint.style = PaintingStyle.fill;
    for (int i = 1; i < navigationPath.length - 1; i++) {
      // Outer glow
      paint.color = pathColor.withValues(alpha: 0.3);
      canvas.drawCircle(navigationPath[i], 12, paint);

      // Green circle
      paint.color = const Color(0xFF00CC66);
      canvas.drawCircle(navigationPath[i], 8, paint);

      // White inner
      paint.color = Colors.white;
      canvas.drawCircle(navigationPath[i], 4, paint);

      // Green center
      paint.color = pathColor;
      canvas.drawCircle(navigationPath[i], 2, paint);
    }

    // Draw target marker if exists
    if (targetRoom != null) {
      final targetPos =
          Offset(targetRoom!.xCoordinate, targetRoom!.yCoordinate);

      // Glow effect - green for destination
      paint.color = Colors.green.withValues(alpha: 0.35);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(targetPos, 28, paint);

      // Green ring
      paint.color = Colors.green.withValues(alpha: 0.5);
      canvas.drawCircle(targetPos, 22, paint);

      // Target marker
      paint.color = Colors.green;
      canvas.drawCircle(targetPos, 16, paint);

      paint.color = Colors.white;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3;
      canvas.drawCircle(targetPos, 16, paint);

      // Inner white highlight
      paint.style = PaintingStyle.fill;
      paint.color = Colors.white;
      canvas.drawCircle(targetPos, 6, paint);
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
      paint.color = _getRoomColor(room.roomType).withValues(alpha: 0.8);
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

/// Waypoint paths painter - shows RED walkable roads with premium styling
class WaypointPathsPainter extends CustomPainter {
  final List<NavigationWaypoint> waypoints;
  final List<WaypointConnection> connections;
  final List<NavigationWaypoint> allWaypoints;
  final bool isAdminMode;

  WaypointPathsPainter({
    required this.waypoints,
    required this.connections,
    required this.allWaypoints,
    this.isAdminMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Draw connection paths (RED roads with road-like styling)
    for (final conn in connections) {
      final fromWp = allWaypoints.firstWhere(
        (w) => w.id == conn.fromWaypointId,
        orElse: () =>
            allWaypoints.isNotEmpty ? allWaypoints.first : waypoints.first,
      );
      final toWp = allWaypoints.firstWhere(
        (w) => w.id == conn.toWaypointId,
        orElse: () =>
            allWaypoints.isNotEmpty ? allWaypoints.first : waypoints.first,
      );

      // Only draw if at least one waypoint is on current floor
      if (waypoints.any((w) => w.id == fromWp.id || w.id == toWp.id)) {
        final from = Offset(fromWp.xCoordinate, fromWp.yCoordinate);
        final to = Offset(toWp.xCoordinate, toWp.yCoordinate);

        // Outer glow shadow
        paint.color = Colors.red.withValues(alpha: 0.15);
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = isAdminMode ? 12 : 14;
        paint.strokeCap = StrokeCap.round;
        canvas.drawLine(from, to, paint);

        // Main road (dark red)
        paint.color = Colors.red.shade800.withValues(alpha: 0.8);
        paint.strokeWidth = isAdminMode ? 7 : 8;
        canvas.drawLine(from, to, paint);

        // Center line (lighter red for road effect)
        paint.color = Colors.red.withValues(alpha: 0.7);
        paint.strokeWidth = isAdminMode ? 4 : 5;
        canvas.drawLine(from, to, paint);

        // White dashed center line (road marking)
        paint.color = Colors.white.withValues(alpha: 0.5);
        paint.strokeWidth = 1.5;
        _drawDashedLine(canvas, from, to, paint);
      }
    }

    // Draw waypoint nodes
    for (final wp in waypoints) {
      final pos = Offset(wp.xCoordinate, wp.yCoordinate);

      // Outer glow effect
      paint.color = Colors.red.withValues(alpha: 0.25);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(pos, isAdminMode ? 13 : 14, paint);

      // Red ring
      paint.color = Colors.red.shade700;
      canvas.drawCircle(pos, isAdminMode ? 9 : 9, paint);

      // Inner red
      paint.color = Colors.red.shade400;
      canvas.drawCircle(pos, isAdminMode ? 6 : 6, paint);

      // White center
      paint.color = Colors.white;
      canvas.drawCircle(pos, isAdminMode ? 3 : 3, paint);

      // White border ring
      paint.color = Colors.white;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawCircle(pos, isAdminMode ? 9 : 9, paint);

      // Draw waypoint name in admin mode
      if (isAdminMode && wp.name != null && wp.name!.isNotEmpty) {
        // Background for text
        final textPainter = TextPainter(
          text: TextSpan(
            text: wp.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              shadows: [
                const Shadow(color: Colors.black87, blurRadius: 4),
                Shadow(color: Colors.red.shade800, blurRadius: 8),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Draw background pill
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(pos.dx, pos.dy + 22),
            width: textPainter.width + 10,
            height: textPainter.height + 4,
          ),
          const Radius.circular(6),
        );
        paint.style = PaintingStyle.fill;
        paint.color = Colors.red.shade800.withValues(alpha: 0.9);
        canvas.drawRRect(bgRect, paint);

        textPainter.paint(
          canvas,
          Offset(pos.dx - textPainter.width / 2,
            pos.dy + 18 - textPainter.height / 2),
        );

        // Draw waypoint type icon indicator
        final typeIcon = _getTypeIndicator(wp.waypointType);
        final iconPainter = TextPainter(
          text: TextSpan(
            text: typeIcon,
            style: const TextStyle(fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        );
        iconPainter.layout();
        iconPainter.paint(canvas, Offset(pos.dx - 5, pos.dy - 5));
      }
    }
  }

  String _getTypeIndicator(String type) {
    switch (type) {
      case 'junction':
        return '⬡';
      case 'corner':
        return '↱';
      case 'stairs':
        return '⌇';
      case 'elevator':
        return '⬛';
      case 'entrance':
        return '⬜';
      case 'landmark':
        return '★';
      case 'corridor':
        return '│';
      default:
        return '●';
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 6.0;
    const dashSpace = 8.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final unitX = dx / distance;
    final unitY = dy / distance;

    var drawn = 0.0;
    var isDrawing = true;

    while (drawn < distance) {
      final segmentLength = isDrawing ? dashWidth : dashSpace;
      final endDraw = (drawn + segmentLength).clamp(0.0, distance);

      if (isDrawing) {
        canvas.drawLine(
          Offset(start.dx + unitX * drawn, start.dy + unitY * drawn),
          Offset(start.dx + unitX * endDraw, start.dy + unitY * endDraw),
          paint,
        );
      }

      drawn = endDraw;
      isDrawing = !isDrawing;
    }
  }

  @override
  bool shouldRepaint(covariant WaypointPathsPainter oldDelegate) {
    return oldDelegate.waypoints != waypoints ||
        oldDelegate.connections != connections ||
        oldDelegate.isAdminMode != isAdminMode;
  }
}

// Google Maps-style Waypoint Detail Popup
class _WaypointDetailSheet extends StatefulWidget {
  final NavigationWaypoint waypoint;

  const _WaypointDetailSheet({required this.waypoint});

  @override
  State<_WaypointDetailSheet> createState() => _WaypointDetailSheetState();
}

class _WaypointDetailSheetState extends State<_WaypointDetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getWaypointIcon(String type) {
    switch (type) {
      case 'junction':
        return Icons.hub;
      case 'corner':
        return Icons.turn_right;
      case 'stairs':
        return Icons.stairs;
      case 'elevator':
        return Icons.elevator;
      case 'entrance':
        return Icons.door_front_door;
      case 'landmark':
        return Icons.star;
      case 'corridor':
        return Icons.straighten;
      default:
        return Icons.location_on;
    }
  }

  Color _getWaypointColor(String type) {
    switch (type) {
      case 'junction':
        return const Color(0xFF00FF88); // Bright green to match navigation path
      case 'corner':
        return const Color(0xFFFF9800);
      case 'stairs':
        return const Color(0xFF4CAF50);
      case 'elevator':
        return const Color(0xFF9C27B0);
      case 'entrance':
        return const Color(0xFF2196F3);
      case 'landmark':
        return const Color(0xFFFFD700);
      case 'corridor':
        return const Color(0xFF78909C);
      default:
        return const Color(0xFFD32F2F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final waypointColor = _getWaypointColor(widget.waypoint.waypointType);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 300 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: waypointColor.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 32,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1E1E2E).withValues(alpha: 0.95),
                          const Color(0xFF2D2D44).withValues(alpha: 0.9),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.95),
                          const Color(0xFFF8F9FA).withValues(alpha: 0.9),
                        ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: waypointColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Photo section (if available)
                  if (widget.waypoint.photoUrl != null &&
                      widget.waypoint.photoUrl!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              widget.waypoint.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: waypointColor.withValues(alpha: 0.1),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 48,
                                      color:
                                          waypointColor.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Photo unavailable',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: waypointColor.withValues(alpha: 0.1),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      color: waypointColor,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Gradient overlay
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.3),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Content section
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with icon and name
                        Row(
                          children: [
                            // Animated icon container
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: child,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      waypointColor,
                                      waypointColor.withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          waypointColor.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _getWaypointIcon(
                                      widget.waypoint.waypointType),
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Name and type
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.waypoint.name ?? 'Waypoint',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          waypointColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: waypointColor.withValues(
                                            alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      widget.waypoint.waypointType
                                          .toUpperCase()
                                          .replaceAll('_', ' '),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: waypointColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Close button
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 20,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Info cards
                        Row(
                          children: [
                            // Floor card
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.layers,
                                label: 'Floor',
                                value: 'Floor ${widget.waypoint.floor}',
                                color: const Color(0xFF2196F3),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Coordinates card
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.grid_on,
                                label: 'Position',
                                value:
                                    '(${widget.waypoint.xCoordinate.toInt()}, ${widget.waypoint.yCoordinate.toInt()})',
                                color: const Color(0xFF4CAF50),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),

                        // Description (if available)
                        if (widget.waypoint.description != null &&
                            widget.waypoint.description!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: waypointColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.waypoint.description!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),
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
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// Google Maps-style Room Detail Bottom Sheet
class _RoomDetailSheet extends StatefulWidget {
  final Room room;
  final VoidCallback onNavigate;

  const _RoomDetailSheet({
    required this.room,
    required this.onNavigate,
  });

  @override
  State<_RoomDetailSheet> createState() => _RoomDetailSheetState();
}

class _RoomDetailSheetState extends State<_RoomDetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getRoomIcon(String roomType) {
    switch (roomType) {
      case 'classroom':
        return Icons.class_outlined;
      case 'lab':
        return Icons.science_outlined;
      case 'office':
        return Icons.work_outline;
      case 'faculty':
        return Icons.person_outline;
      case 'washroom':
        return Icons.wc_outlined;
      case 'auditorium':
        return Icons.theater_comedy_outlined;
      case 'library':
        return Icons.local_library_outlined;
      case 'cafeteria':
        return Icons.restaurant_outlined;
      case 'stairs':
        return Icons.stairs_outlined;
      case 'elevator':
        return Icons.elevator_outlined;
      default:
        return Icons.meeting_room_outlined;
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roomColor = _getRoomColor(widget.room.roomType);
    final hasImage =
        widget.room.imageUrl != null && widget.room.imageUrl!.isNotEmpty;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 400 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: roomColor.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 40,
              spreadRadius: -10,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1A1A2E).withValues(alpha: 0.97),
                          const Color(0xFF16213E).withValues(alpha: 0.95),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.97),
                          const Color(0xFFF8F9FA).withValues(alpha: 0.95),
                        ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: roomColor.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            roomColor.withValues(alpha: 0.5),
                            roomColor.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // Image section (if available)
                    if (hasImage)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                widget.room.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: roomColor.withValues(alpha: 0.1),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image_not_supported_outlined,
                                          size: 48,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black26,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Image unavailable',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black26,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: roomColor.withValues(alpha: 0.1),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                        color: roomColor,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Gradient overlay
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 60,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.5),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Content section
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with icon and name
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Room icon
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        roomColor,
                                        roomColor.withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: roomColor.withValues(alpha: 0.4),
                                        blurRadius: 15,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getRoomIcon(widget.room.roomType),
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Room name and type
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.room.effectiveName,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            roomColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        widget.room.roomType.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: roomColor,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Description (if available)
                          if (widget.room.description != null &&
                              widget.room.description!.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Text(
                                widget.room.description!,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Info cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  icon: Icons.tag,
                                  label: 'Room No.',
                                  value: widget.room.roomNumber,
                                  color: roomColor,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  icon: Icons.layers_outlined,
                                  label: 'Floor',
                                  value: 'Floor ${widget.room.floor}',
                                  color: roomColor,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  icon: Icons.people_outline,
                                  label: 'Capacity',
                                  value: '${widget.room.capacity} seats',
                                  color: roomColor,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  icon: Icons.location_on_outlined,
                                  label: 'Coordinates',
                                  value:
                                      '(${widget.room.xCoordinate.toInt()}, ${widget.room.yCoordinate.toInt()})',
                                  color: roomColor,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Navigate button
                          GestureDetector(
                            onTap: widget.onNavigate,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    roomColor,
                                    roomColor.withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: roomColor.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.navigation_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Navigate Here',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
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
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
