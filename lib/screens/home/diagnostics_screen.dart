import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/feature_flags_provider.dart';
import '../../services/action_queue_service.dart';
import '../../services/offline_cache_service.dart';
import '../../services/realtime_coordinator.dart';
import '../../utils/app_theme.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('System Diagnostics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadDiagnostics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final channels = (data['channels'] as List<String>?) ?? <String>[];
          final subscriptions =
              (data['subscriptionStats'] as Map<String, int>?) ?? {};
          final queueStats =
              (data['queueStats'] as Map<String, dynamic>?) ?? {};
          final cacheInfo = (data['cacheInfo'] as Map<String, int>?) ?? {};
          final lastCacheUpdate = data['lastCacheUpdate'] as DateTime?;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionCard(
                title: 'Realtime',
                children: [
                  Text('Active channels: ${channels.length}'),
                  Text(channels.isEmpty ? 'None' : channels.join(', ')),
                  const SizedBox(height: 8),
                  Text('Subscribers: $subscriptions'),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Offline Queue',
                children: [
                  Text('Pending actions: ${queueStats['pending_actions'] ?? 0}'),
                  Text('Last update: ${queueStats['last_update'] ?? 'N/A'}'),
                  Text('Queue size (chars): ${queueStats['queue_size_kb'] ?? 0}'),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Cache',
                children: [
                  Text('Cached items: ${cacheInfo['items'] ?? 0}'),
                  Text('Size bytes: ${cacheInfo['sizeBytes'] ?? 0}'),
                  Text(
                    'Last cache update: ${lastCacheUpdate?.toIso8601String() ?? 'Never'}',
                  ),
                  Text('Connectivity: ${OfflineCacheService.isOnline ? 'Online' : 'Offline'}'),
                ],
              ),
              const SizedBox(height: 12),
              Consumer<FeatureFlagsProvider>(
                builder: (context, flags, _) {
                  final flagStatus = flags.getFlagStatus();
                  return _sectionCard(
                    title: 'Feature Flags (${flags.currentUserRole})',
                    children: flagStatus.entries
                        .map((entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text('${entry.key}: ${entry.value ? 'ON' : 'OFF'}'),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadDiagnostics() async {
    final coordinator = RealtimeCoordinator();
    return {
      'channels': coordinator.getActiveChannels(),
      'subscriptionStats': coordinator.getSubscriptionStats(),
      'queueStats': await ActionQueueService.getQueueStats(),
      'cacheInfo': await OfflineCacheService.getCacheInfo(),
      'lastCacheUpdate': await OfflineCacheService.getLastCacheUpdate(),
    };
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
