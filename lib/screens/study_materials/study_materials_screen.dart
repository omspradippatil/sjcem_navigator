import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/study_materials_provider.dart';
import '../../utils/animations.dart';
import 'create_folder_dialog.dart';
import 'upload_file_dialog.dart';

class StudyMaterialsScreen extends StatefulWidget {
  const StudyMaterialsScreen({super.key});

  @override
  State<StudyMaterialsScreen> createState() => _StudyMaterialsScreenState();
}

class _StudyMaterialsScreenState extends State<StudyMaterialsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<StudyFolder> _searchFolders = [];
  List<StudyFile> _searchFiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFolders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadFolders() {
    final authProvider = context.read<AuthProvider>();
    final materialsProvider = context.read<StudyMaterialsProvider>();
    materialsProvider.loadRootFolders(
      branchId: authProvider.currentBranchId,
      semester: authProvider.currentStudent?.semester,
    );
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchFolders = [];
        _searchFiles = [];
      });
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final materialsProvider = context.read<StudyMaterialsProvider>();

    final results = await materialsProvider.search(
      query,
      branchId: authProvider.currentBranchId,
      semester: authProvider.currentStudent?.semester,
    );

    setState(() {
      _isSearching = true;
      _searchFolders = results['folders'] as List<StudyFolder>;
      _searchFiles = results['files'] as List<StudyFile>;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchFolders = [];
      _searchFiles = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final materialsProvider = context.watch<StudyMaterialsProvider>();
    final isTeacher = authProvider.isTeacher;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                onChanged: _search,
              )
            : const Text('Study Materials'),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSearch,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_isSearching) {
                _search(_searchController.text);
              } else {
                materialsProvider.refresh(
                  branchId: authProvider.currentBranchId,
                  semester: authProvider.currentStudent?.semester,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumbs
          if (!_isSearching && materialsProvider.breadcrumbs.isNotEmpty)
            _buildBreadcrumbs(materialsProvider, isDark),

          // Content
          Expanded(
            child: materialsProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSearching
                    ? _buildSearchResults(isDark)
                    : _buildFolderContent(materialsProvider, isTeacher, isDark),
          ),
        ],
      ),
      floatingActionButton: isTeacher && !_isSearching
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (materialsProvider.currentFolderId != null)
                  FloatingActionButton.small(
                    heroTag: 'upload_file',
                    onPressed: () => _showUploadFileDialog(context),
                    child: const Icon(Icons.upload_file),
                  ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'create_folder',
                  onPressed: () => _showCreateFolderDialog(context),
                  child: const Icon(Icons.create_new_folder),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildBreadcrumbs(StudyMaterialsProvider provider, bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => provider.loadRootFolders(),
            child: Row(
              children: [
                Icon(Icons.home,
                    size: 20, color: isDark ? Colors.blue[300] : Colors.blue),
                const SizedBox(width: 4),
                Text(
                  'Home',
                  style: TextStyle(
                    color: isDark ? Colors.blue[300] : Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: provider.breadcrumbs.length,
              itemBuilder: (context, index) {
                final folder = provider.breadcrumbs[index];
                final isLast = index == provider.breadcrumbs.length - 1;
                return Row(
                  children: [
                    Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    InkWell(
                      onTap: isLast
                          ? null
                          : () => provider.navigateToBreadcrumb(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          folder.name,
                          style: TextStyle(
                            color: isLast
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark ? Colors.blue[300] : Colors.blue),
                            fontWeight:
                                isLast ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderContent(
      StudyMaterialsProvider provider, bool isTeacher, bool isDark) {
    final folders = provider.folders;
    final files = provider.files;

    if (folders.isEmpty && files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              provider.isAtRoot
                  ? 'No study materials yet'
                  : 'This folder is empty',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            if (isTeacher) ...[
              const SizedBox(height: 8),
              Text(
                'Tap + to create a folder',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Back button if not at root
          if (!provider.isAtRoot)
            AnimatedListItem(
              index: 0,
              child: _buildBackTile(provider, isDark),
            ),

          // Folders section
          if (folders.isNotEmpty) ...[
            AnimatedListItem(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Folders (${folders.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ),
            ),
            ...folders.asMap().entries.map((entry) => AnimatedListItem(
                  index: entry.key + 1,
                  child: _buildFolderTile(entry.value, isTeacher, isDark),
                )),
            const SizedBox(height: 16),
          ],

          // Files section
          if (files.isNotEmpty) ...[
            AnimatedListItem(
              index: folders.length + 1,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Files (${files.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ),
            ),
            ...files.asMap().entries.map((entry) => AnimatedListItem(
                  index: folders.length + entry.key + 2,
                  child: _buildFileTile(entry.value, isTeacher, isDark),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildBackTile(StudyMaterialsProvider provider, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => provider.goBack(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.arrow_back,
                    color: isDark ? Colors.blue[300] : Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Go back',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.blue[300] : Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderTile(StudyFolder folder, bool isTeacher, bool isDark) {
    final provider = context.read<StudyMaterialsProvider>();

    return Card(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shadowColor: Colors.amber.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => provider.openFolder(folder.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'folder_${folder.id}',
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.shade400,
                        Colors.amber.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.folder, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (folder.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        folder.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              isTeacher
                  ? PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: isDark ? Colors.grey[400] : Colors.grey),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditFolderDialog(context, folder);
                        } else if (value == 'delete') {
                          _showDeleteFolderDialog(context, folder);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.grey[400] : Colors.grey,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileTile(StudyFile file, bool isTeacher, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shadowColor: _getFileColor(file.fileType).withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openFile(file),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // File icon with animated container
              Hero(
                tag: 'file_${file.id}',
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getFileColor(file.fileType).withOpacity(0.8),
                        _getFileColor(file.fileType),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _getFileColor(file.fileType).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getFileIcon(file.fileType),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                _getFileColor(file.fileType).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            file.fileType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getFileColor(file.fileType),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          file.formattedSize,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.visibility_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${file.downloadCount}',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Actions
              isTeacher
                  ? PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: isDark ? Colors.grey[400] : Colors.grey),
                      onSelected: (value) {
                        if (value == 'open') {
                          _openFile(file);
                        } else if (value == 'edit') {
                          _showEditFileDialog(context, file);
                        } else if (value == 'delete') {
                          _showDeleteFileDialog(context, file);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_new, size: 20),
                              SizedBox(width: 8),
                              Text('Open'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Download button
                        InkWell(
                          onTap: () => _downloadFile(file),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.download_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Open button
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.open_in_new,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_searchFolders.isEmpty && _searchFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_searchFolders.isNotEmpty) ...[
          Text(
            'Folders',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          ..._searchFolders.map((f) => _buildFolderTile(f, false, isDark)),
          const SizedBox(height: 16),
        ],
        if (_searchFiles.isNotEmpty) ...[
          Text(
            'Files',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          ..._searchFiles.map((f) => _buildFileTile(f, false, isDark)),
        ],
      ],
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.purple;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.pink;
      case 'mp3':
      case 'wav':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  /// Opens file in external application
  Future<void> _openFile(StudyFile file) async {
    final provider = context.read<StudyMaterialsProvider>();

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text('Opening ${file.name}...',
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Track the download/view
    await provider.trackDownload(file.id);

    final uri = Uri.parse(file.fileUrl);
    debugPrint('Opening file URL: ${file.fileUrl}');

    try {
      // Try to launch in external application first
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback to platform default (usually opens in browser)
        final browserLaunched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );

        if (!browserLaunched && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Could not open file. No app available.'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        // Success - hide the loading snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error opening file: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  /// Downloads file to device storage
  Future<void> _downloadFile(StudyFile file) async {
    final provider = context.read<StudyMaterialsProvider>();

    // Request storage permission
    PermissionStatus status;
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      if (androidInfo >= 33) {
        // Android 13+ uses media permissions
        status = await Permission.photos.request();
      } else if (androidInfo >= 30) {
        // Android 11-12 uses manage external storage or scoped storage
        status = PermissionStatus.granted; // Use app-specific directory
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = PermissionStatus.granted;
    }

    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Storage permission required'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    // Show download progress dialog
    double progress = 0;
    bool downloading = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download_rounded,
                    size: 48, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  downloading ? 'Downloading...' : 'Download Complete!',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  file.name,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (downloading) ...[
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.green),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ] else ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                ],
              ],
            ),
            actions: downloading
                ? null
                : [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('OK'),
                    ),
                  ],
          );
        },
      ),
    );

    try {
      // Get download directory
      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          downloadDir = await getExternalStorageDirectory();
        }
      } else {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      if (downloadDir == null) {
        throw Exception('Could not access download directory');
      }

      final filePath = '${downloadDir.path}/${file.name}';
      debugPrint('Downloading to: $filePath');

      // Download file using Dio
      final dio = Dio();
      await dio.download(
        file.fileUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            progress = received / total;
            // Update dialog
            if (mounted) {
              (context as Element).markNeedsBuild();
            }
          }
        },
      );

      // Track download
      await provider.trackDownload(file.id);

      downloading = false;

      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Downloaded: ${file.name}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Saved to Downloads folder',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Download failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      // Return approximate Android version based on API level
      // This is a simplified check - in production, use device_info_plus
      return 33; // Assume Android 13+ for modern devices
    }
    return 0;
  }

  void _showCreateFolderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateFolderDialog(),
    );
  }

  void _showUploadFileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const UploadFileDialog(),
    );
  }

  void _showEditFolderDialog(BuildContext context, StudyFolder folder) {
    showDialog(
      context: context,
      builder: (context) => CreateFolderDialog(folder: folder),
    );
  }

  void _showDeleteFolderDialog(BuildContext context, StudyFolder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
            'Are you sure you want to delete "${folder.name}"?\nThis will also delete all contents inside.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final provider = context.read<StudyMaterialsProvider>();
              await provider.deleteFolder(folder.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditFileDialog(BuildContext context, StudyFile file) {
    final nameController = TextEditingController(text: file.name);
    final descController = TextEditingController(text: file.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'File Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final provider = context.read<StudyMaterialsProvider>();
              await provider.updateFile(
                file.id,
                name: nameController.text.trim(),
                description: descController.text.trim().isEmpty
                    ? null
                    : descController.text.trim(),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFileDialog(BuildContext context, StudyFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final provider = context.read<StudyMaterialsProvider>();
              await provider.deleteFile(file.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
