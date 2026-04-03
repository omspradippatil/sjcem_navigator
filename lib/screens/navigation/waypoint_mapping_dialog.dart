import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/navigation_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/animations.dart';
import '../../utils/constants.dart';

class WaypointMappingDialog extends StatefulWidget {
  final double x;
  final double y;
  final int floor;

  const WaypointMappingDialog({
    super.key,
    required this.x,
    required this.y,
    required this.floor,
  });

  @override
  State<WaypointMappingDialog> createState() => _WaypointMappingDialogState();
}

class _WaypointMappingDialogState extends State<WaypointMappingDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _photoUrlController = TextEditingController();
  String _selectedWaypointType = 'junction';
  int _selectedFloor = 0;
  bool _isLoading = false;
  NavigationWaypoint? _existingWaypoint;

  late TabController _tabController;

  final List<Map<String, dynamic>> _waypointTypes = [
    {
      'value': 'junction',
      'label': 'Junction',
      'icon': Icons.compare_arrows,
      'color': Colors.blue
    },
    {
      'value': 'corner',
      'label': 'Corner',
      'icon': Icons.turn_right,
      'color': Colors.orange
    },
    {
      'value': 'stairs',
      'label': 'Stairs',
      'icon': Icons.stairs,
      'color': Colors.teal
    },
    {
      'value': 'elevator',
      'label': 'Elevator',
      'icon': Icons.elevator,
      'color': Colors.indigo
    },
    {
      'value': 'entrance',
      'label': 'Entrance',
      'icon': Icons.door_front_door,
      'color': Colors.green
    },
    {
      'value': 'landmark',
      'label': 'Landmark',
      'icon': Icons.place,
      'color': Colors.purple
    },
    {
      'value': 'corridor',
      'label': 'Corridor',
      'icon': Icons.straighten,
      'color': Colors.red
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedFloor = widget.floor;

    // Add listener for photo URL changes to update preview
    _photoUrlController.addListener(_onPhotoUrlChanged);

    // Check if there's an existing waypoint at this position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navProvider = context.read<NavigationProvider>();
      _existingWaypoint = navProvider.getWaypointAtPosition(
        widget.x,
        widget.y,
        floor: widget.floor,
      );
      if (_existingWaypoint != null) {
        _nameController.text = _existingWaypoint!.name ?? '';
        _descriptionController.text = _existingWaypoint!.description ?? '';
        _photoUrlController.text = _existingWaypoint!.photoUrl ?? '';
        _selectedWaypointType = _existingWaypoint!.waypointType;
        _selectedFloor = _existingWaypoint!.floor;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _photoUrlController.removeListener(_onPhotoUrlChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _photoUrlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onPhotoUrlChanged() {
    setState(() {});
  }

  Future<void> _saveWaypoint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final navProvider = context.read<NavigationProvider>();
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : null;
    final photoUrl = _photoUrlController.text.trim().isNotEmpty
        ? _photoUrlController.text.trim()
        : null;

    final waypoint = _existingWaypoint != null
        ? await navProvider.updateWaypoint(
            waypointId: _existingWaypoint!.id,
            name: name,
            floor: _selectedFloor,
            x: widget.x,
            y: widget.y,
            waypointType: _selectedWaypointType,
            description: description,
            photoUrl: photoUrl,
          )
        : await navProvider.createWaypoint(
            name: name,
            floor: _selectedFloor,
            x: widget.x,
            y: widget.y,
            waypointType: _selectedWaypointType,
            description: description,
            photoUrl: photoUrl,
          );

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (waypoint != null) {
        Navigator.of(context).pop();
        PremiumSnackBar.showSuccess(
          context,
          _existingWaypoint != null
              ? 'Waypoint "${waypoint.name}" updated successfully!'
              : 'Waypoint "${waypoint.name}" created successfully!',
        );
      } else {
        PremiumSnackBar.showError(
          context,
          _existingWaypoint != null
              ? 'Failed to update waypoint.'
              : 'Failed to create waypoint.',
        );
      }
    }
  }

  Future<void> _deleteWaypoint() async {
    if (_existingWaypoint == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Waypoint'),
        content: Text(
            'Are you sure you want to delete "${_existingWaypoint!.name}"? All connections will also be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    final navProvider = context.read<NavigationProvider>();
    final success = await navProvider.deleteWaypoint(_existingWaypoint!.id);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        PremiumSnackBar.showSuccess(
          context,
          'Waypoint deleted successfully!',
        );
      } else {
        PremiumSnackBar.showError(
          context,
          'Failed to delete waypoint.',
        );
      }
    }
  }

  Future<void> _createConnection(NavigationWaypoint toWaypoint) async {
    if (_existingWaypoint == null) return;
    if (_existingWaypoint!.id == toWaypoint.id) {
      PremiumSnackBar.showWarning(
        context,
        'Cannot connect waypoint to itself.',
      );
      return;
    }

    final fromType = _existingWaypoint!.waypointType.toLowerCase();
    final toType = toWaypoint.waypointType.toLowerCase();
    final isCrossFloor = _existingWaypoint!.floor != toWaypoint.floor;
    final isValidVerticalPair =
        (fromType == 'stairs' || fromType == 'elevator') &&
            fromType == toType;
    if (isCrossFloor && !isValidVerticalPair) {
      PremiumSnackBar.showWarning(
        context,
        'Cross-floor links are allowed only between same-type stairs or elevator waypoints.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final navProvider = context.read<NavigationProvider>();
    final connection = await navProvider.createWaypointConnection(
      fromWaypointId: _existingWaypoint!.id,
      toWaypointId: toWaypoint.id,
      isBidirectional: true,
    );

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (connection != null) {
        PremiumSnackBar.showSuccess(
          context,
          'Connected to "${toWaypoint.name}"!',
        );
      } else {
        PremiumSnackBar.showError(
          context,
          'Failed to create connection. May already exist.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final isVerticalSource = _existingWaypoint != null &&
        _isVerticalConnectorType(_existingWaypoint!.waypointType);
    final nearbyWaypoints = navProvider.waypoints
        .where((w) {
          if (w.id == _existingWaypoint?.id) return false;

          if (!isVerticalSource) {
            return w.floor == _selectedFloor;
          }

          // Stairs/elevator waypoints may connect across floors,
          // but only to the same transition type.
          return _isVerticalConnectorType(w.waypointType) &&
              w.waypointType.toLowerCase() ==
                  _existingWaypoint!.waypointType.toLowerCase();
        })
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceLight.withValues(alpha: 0.95),
                AppColors.surface.withValues(alpha: 0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  _buildHeader(),

                  // Tab Bar
                  if (_existingWaypoint != null) _buildTabBar(),

                  // Content
                  Flexible(
                    child: _existingWaypoint != null
                        ? TabBarView(
                            controller: _tabController,
                            children: [
                              _buildEditForm(),
                              _buildConnectionsList(nearbyWaypoints),
                            ],
                          )
                        : _buildCreateForm(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: AppGradients.primary,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _existingWaypoint != null
                      ? Icons.edit_location_alt
                      : Icons.add_location_alt,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _existingWaypoint != null
                          ? 'Edit Waypoint'
                          : 'Add Waypoint',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Position: (${widget.x.toInt()}, ${widget.y.toInt()}) • Floor $_selectedFloor',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surfaceLight.withValues(alpha: 0.5),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.gradientStart,
        unselectedLabelColor: Colors.white60,
        indicatorColor: AppColors.gradientStart,
        tabs: const [
          Tab(text: 'Details', icon: Icon(Icons.info_outline, size: 18)),
          Tab(text: 'Connections', icon: Icon(Icons.share, size: 18)),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNameField(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 16),
            _buildFloorSelector(),
            const SizedBox(height: 16),
            _buildPhotoUrlField(),
            const SizedBox(height: 20),
            _buildWaypointTypeSelector(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNameField(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 16),
            _buildFloorSelector(),
            const SizedBox(height: 16),
            _buildPhotoUrlField(),
            const SizedBox(height: 20),
            _buildWaypointTypeSelector(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Floor',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedFloor,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              items: AppConstants.supportedFloors
                  .map((floor) => DropdownMenuItem<int>(
                        value: floor,
                        child: Text('Floor $floor'),
                      ))
                  .toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedFloor = value;
                      });
                    },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionsList(List<NavigationWaypoint> nearbyWaypoints) {
    final navProvider = context.watch<NavigationProvider>();
    final supportsCrossFloor = _existingWaypoint != null &&
      _isVerticalConnectorType(_existingWaypoint!.waypointType);
    final connectHint = supportsCrossFloor
      ? 'Tap a ${_existingWaypoint!.waypointType} waypoint on any floor to connect vertical transition paths.'
      : 'Tap a waypoint on this floor to connect. Paths are bidirectional (works both ways).';
    final connections = navProvider.waypointConnections
        .where((c) =>
            c.fromWaypointId == _existingWaypoint?.id ||
            (c.isBidirectional && c.toWaypointId == _existingWaypoint?.id))
        .toList();

    // Sort nearby waypoints by distance
    final sortedWaypoints = List<NavigationWaypoint>.from(nearbyWaypoints);
    sortedWaypoints.sort((a, b) {
      final distA = sqrt(
          pow(a.xCoordinate - widget.x, 2) + pow(a.yCoordinate - widget.y, 2));
      final distB = sqrt(
          pow(b.xCoordinate - widget.x, 2) + pow(b.yCoordinate - widget.y, 2));
      return distA.compareTo(distB);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick connect info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withValues(alpha: 0.15),
                  Colors.orange.withValues(alpha: 0.1)
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.route, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Path Building Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Connect waypoints to create walkable paths. The red dot will follow these paths.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Current connections
          if (connections.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.link, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Connected Paths',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${connections.length} paths',
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...connections.map((conn) {
              final otherWpId = conn.fromWaypointId == _existingWaypoint?.id
                  ? conn.toWaypointId
                  : conn.fromWaypointId;
              final otherWp = navProvider.waypoints.firstWhere(
                (w) => w.id == otherWpId,
                orElse: () => NavigationWaypoint(
                    id: '',
                    name: 'Unknown',
                    floor: 0,
                    xCoordinate: 0,
                    yCoordinate: 0,
                    waypointType: ''),
              );
              return _buildConnectionTile(otherWp, conn);
            }),
            const SizedBox(height: 24),
          ],

          // Available waypoints to connect
          const Row(
            children: [
              Icon(Icons.add_road, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text(
                'Add New Path',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            connectHint,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (sortedWaypoints.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_location_alt,
                        color: Colors.white38, size: 40),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No waypoints nearby',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap other locations on the map while in Admin mode to create more waypoints, then connect them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...sortedWaypoints.map((wp) => _buildWaypointTile(wp)),
        ],
      ),
    );
  }

  Widget _buildConnectionTile(
      NavigationWaypoint waypoint, WaypointConnection connection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waypoint.name ?? 'Unknown',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Distance: ${connection.distance?.toInt() ?? 0} • ${connection.isBidirectional ? 'Bidirectional' : 'One-way'}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoading
                ? null
                : () async {
                    final navProvider = context.read<NavigationProvider>();
                    await navProvider.deleteWaypointConnection(connection.id);
                  },
            icon: const Icon(Icons.link_off, color: Colors.red, size: 20),
            tooltip: 'Remove connection',
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointTile(NavigationWaypoint waypoint) {
    // Calculate distance
    final distance = sqrt(
      pow(waypoint.xCoordinate - widget.x, 2) +
          pow(waypoint.yCoordinate - widget.y, 2),
    );

    // Get color for waypoint type
    final typeInfo = _waypointTypes.firstWhere(
      (t) => t['value'] == waypoint.waypointType,
      orElse: () => {'color': Colors.grey, 'icon': Icons.location_on},
    );
    final typeColor = typeInfo['color'] as Color;

    // Check if already connected
    final navProvider = context.read<NavigationProvider>();
    final isAlreadyConnected = navProvider.waypointConnections.any((c) =>
        (c.fromWaypointId == _existingWaypoint?.id &&
            c.toWaypointId == waypoint.id) ||
        (c.toWaypointId == _existingWaypoint?.id &&
            c.fromWaypointId == waypoint.id));

    return Opacity(
      opacity: isAlreadyConnected ? 0.5 : 1.0,
      child: InkWell(
        onTap: (_isLoading || isAlreadyConnected)
            ? null
            : () => _createConnection(waypoint),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isAlreadyConnected
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  _getWaypointIcon(waypoint.waypointType),
                  color: typeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waypoint.name ?? 'Waypoint',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            waypoint.waypointType,
                            style: TextStyle(
                                color: typeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'F${waypoint.floor}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.straighten,
                            size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          '${distance.toInt()} px',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isAlreadyConnected)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 18),
                )
              else
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Colors.red, Colors.orange]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.add_link, color: Colors.white, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getWaypointIcon(String type) {
    switch (type) {
      case 'junction':
        return Icons.compare_arrows;
      case 'corner':
        return Icons.turn_right;
      case 'stairs':
        return Icons.stairs;
      case 'elevator':
        return Icons.elevator;
      case 'entrance':
        return Icons.door_front_door;
      case 'landmark':
        return Icons.place;
      default:
        return Icons.location_on;
    }
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Waypoint Name',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g., Main Corridor Junction',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.label_outline, color: Colors.white60),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a waypoint name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Description',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add helpful details about this location...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.description_outlined, color: Colors.white60),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Photo URL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _photoUrlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'https://example.com/photo.jpg',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.image_outlined, color: Colors.white60),
          ),
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              final uri = Uri.tryParse(value.trim());
              if (uri == null || !uri.hasAbsolutePath) {
                return 'Please enter a valid URL';
              }
            }
            return null;
          },
        ),
        // Photo preview if URL exists
        if (_photoUrlController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.network(
                _photoUrlController.text,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cannot load image',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: AppColors.gradientStart,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWaypointTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Waypoint Type',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _waypointTypes.map((type) {
            final isSelected = _selectedWaypointType == type['value'];
            final typeColor = type['color'] as Color;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedWaypointType = type['value'];
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: AnimationDurations.short,
                curve: AnimationCurves.emphasizedDecelerate,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [typeColor, typeColor.withValues(alpha: 0.7)])
                      : null,
                  color:
                      isSelected ? null : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.2),
                    width: isSelected ? 0 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: typeColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type['icon'],
                      size: 18,
                      color: isSelected ? Colors.white : typeColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type['label'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Save button
        ElevatedButton(
          onPressed: _isLoading ? null : _saveWaypoint,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: AppColors.gradientStart,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _existingWaypoint != null
                      ? 'Update Waypoint'
                      : 'Create Waypoint',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),

        // Delete button (only for existing waypoints)
        if (_existingWaypoint != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isLoading ? null : _deleteWaypoint,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Colors.red),
              foregroundColor: Colors.red,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, size: 20),
                SizedBox(width: 8),
                Text('Delete Waypoint'),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white60),
          ),
        ),
      ],
    );
  }

  bool _isVerticalConnectorType(String waypointType) {
    final normalized = waypointType.toLowerCase();
    return normalized == 'stairs' || normalized == 'elevator';
  }
}
