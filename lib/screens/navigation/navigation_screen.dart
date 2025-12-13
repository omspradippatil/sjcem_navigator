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
  final TransformationController _transformationController = TransformationController();
  bool _showRoomLabels = true;

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
      navProvider.setInitialPosition(x, y);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Initial position set! Start walking to navigate.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
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
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select Destination',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: navProvider.rooms.length,
                    itemBuilder: (context, index) {
                      final room = navProvider.rooms[index];
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
                        subtitle: Text(room.roomNumber),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
      default:
        return Icons.room;
    }
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Column(
      children: [
        // Control Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showRoomSelector,
                      icon: const Icon(Icons.location_searching),
                      label: Text(
                        navProvider.targetRoom?.name ?? 'Select Destination',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (navProvider.isNavigating)
                    IconButton(
                      onPressed: () => navProvider.stopNavigation(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Stop Navigation',
                    ),
                ],
              ),
              const SizedBox(height: 8),
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
                    icon: Icons.my_location,
                    label: 'Reset Pos',
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
        
        // Navigation Info
        if (navProvider.isNavigating)
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.directions_walk,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Navigating to ${navProvider.targetRoom?.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Distance: ${navProvider.distanceToTarget.toStringAsFixed(0)}px | '
                        'Steps: ${navProvider.stepCount}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (navProvider.hasReachedDestination)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Arrived!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                  // Floor Map Image
                  Container(
                    width: 700,
                    height: 650,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey),
                    ),
                    child: CustomPaint(
                      painter: FloorMapPainter(
                        rooms: navProvider.rooms,
                        showLabels: _showRoomLabels,
                        currentPosition: navProvider.positionSet
                            ? Offset(navProvider.currentX, navProvider.currentY)
                            : null,
                        targetRoom: navProvider.targetRoom,
                        heading: navProvider.heading,
                        navigationPath: navProvider.getNavigationPath(),
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
          padding: const EdgeInsets.all(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(
                'Position',
                navProvider.positionSet
                    ? '(${navProvider.currentX.toInt()}, ${navProvider.currentY.toInt()})'
                    : 'Tap to set',
              ),
              _buildStatusItem(
                'Heading',
                '${navProvider.heading.toStringAsFixed(0)}°',
              ),
              _buildStatusItem(
                'Steps',
                '${navProvider.stepCount}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            foregroundColor: isActive
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildStatusItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
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

  FloorMapPainter({
    required this.rooms,
    required this.showLabels,
    this.currentPosition,
    this.targetRoom,
    required this.heading,
    required this.navigationPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Draw floor background
    paint.color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
    
    // Draw quadrangle (central open area)
    paint.color = Colors.green.withOpacity(0.2);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(
      const Rect.fromLTWH(120, 100, 350, 350),
      paint,
    );
    paint.color = Colors.green;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawRect(
      const Rect.fromLTWH(120, 100, 350, 350),
      paint,
    );
    
    // Draw quadrangle label
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Quadrangle-A',
        style: TextStyle(color: Colors.green, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(230, 260));
    
    // Draw rooms
    for (final room in rooms) {
      final isTarget = targetRoom?.id == room.id;
      
      // Room marker
      paint.color = isTarget ? Colors.green : Colors.blue;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(room.xCoordinate, room.yCoordinate),
        isTarget ? 12 : 8,
        paint,
      );
      
      // Room border
      paint.color = Colors.white;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawCircle(
        Offset(room.xCoordinate, room.yCoordinate),
        isTarget ? 12 : 8,
        paint,
      );
      
      // Room label
      if (showLabels) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: room.roomNumber,
            style: TextStyle(
              color: isTarget ? Colors.green : Colors.black87,
              fontSize: isTarget ? 11 : 9,
              fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        labelPainter.layout();
        labelPainter.paint(
          canvas,
          Offset(
            room.xCoordinate - labelPainter.width / 2,
            room.yCoordinate + 14,
          ),
        );
      }
    }
    
    // Draw navigation path
    if (navigationPath.length >= 2) {
      paint.color = Colors.blue;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3;
      
      final path = Path();
      path.moveTo(navigationPath[0].dx, navigationPath[0].dy);
      for (int i = 1; i < navigationPath.length; i++) {
        path.lineTo(navigationPath[i].dx, navigationPath[i].dy);
      }
      
      // Draw dashed line
      const dashWidth = 10.0;
      const dashSpace = 5.0;
      var distance = 0.0;
      
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
    }
    
    // Draw current position (user location)
    if (currentPosition != null) {
      // Direction indicator
      paint.color = Colors.red.withOpacity(0.3);
      paint.style = PaintingStyle.fill;
      
      final headingRad = heading * pi / 180;
      final path = Path();
      path.moveTo(
        currentPosition!.dx + 25 * sin(headingRad),
        currentPosition!.dy - 25 * cos(headingRad),
      );
      path.lineTo(
        currentPosition!.dx + 10 * sin(headingRad + pi / 2),
        currentPosition!.dy - 10 * cos(headingRad + pi / 2),
      );
      path.lineTo(
        currentPosition!.dx + 10 * sin(headingRad - pi / 2),
        currentPosition!.dy - 10 * cos(headingRad - pi / 2),
      );
      path.close();
      canvas.drawPath(path, paint);
      
      // User position dot
      paint.color = Colors.red;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(currentPosition!, 10, paint);
      
      paint.color = Colors.white;
      canvas.drawCircle(currentPosition!, 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant FloorMapPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.targetRoom != targetRoom ||
        oldDelegate.heading != heading ||
        oldDelegate.showLabels != showLabels;
  }
}


