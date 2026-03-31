import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/announcements_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({super.key});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  bool _showPinnedOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnnouncements();
    });
  }

  Future<void> _loadAnnouncements() async {
    final announcements = context.read<AnnouncementsProvider>();
    final auth = context.read<AuthProvider>();

    final branchId = auth.currentBranchId;
    if (branchId != null && branchId.isNotEmpty) {
      await announcements.loadAnnouncements(
        branchId: branchId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnnouncementsProvider>(
      builder: (context, announcements, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0a0d1a),
          appBar: AppBar(
            title: const Text('Announcements'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              if (announcements.announcements.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Chip(
                      label: Text('${announcements.unreadCount}'),
                      backgroundColor: AppColors.gradientStart,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadAnnouncements,
            child: announcements.isLoading
                ? const Center(child: CircularProgressIndicator())
                : announcements.announcements.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 80,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No announcements yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          // Pinned announcements section
                          if (announcements.pinnedAnnouncements.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.push_pin,
                                          color: AppColors.gradientStart,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Pinned',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...announcements.pinnedAnnouncements
                                      .map((a) => _AnnouncementCard(
                                            announcement: a,
                                            isPinned: true,
                                          )),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          // Recent announcements
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Recent',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => _showPinnedOnly = !_showPinnedOnly);
                                    },
                                    icon: Icon(
                                      _showPinnedOnly
                                          ? Icons.filter_list
                                          : Icons.filter_list_off,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final announcement =
                                    announcements.announcements[index];
                                return _AnnouncementCard(
                                  announcement: announcement,
                                  isPinned: false,
                                );
                              },
                              childCount: announcements.announcements.length,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ],
                      ),
          ),
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final bool isPinned;

  const _AnnouncementCard({
    required this.announcement,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = announcement.createdAt != null
        ? DateFormat('MMM d, h:mm a').format(announcement.createdAt!)
        : 'Unknown';

    return GestureDetector(
      onTap: () {
        _showAnnouncementDetail(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isPinned ? AppColors.gradientStart : Colors.grey[800]!,
            width: isPinned ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.withValues(alpha: 0.05),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: AppColors.gradientStart,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      announcement.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                announcement.content,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    announcement.creatorName ?? 'Admin',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (announcement.expiresAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Expires: ${DateFormat('MMM d, yyyy').format(announcement.expiresAt!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber[300],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f1420),
      builder: (context) {
        return Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Full Announcement'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    announcement.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By ${announcement.creatorName ?? "Admin"}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    announcement.content,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
