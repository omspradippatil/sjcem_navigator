import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class StudyMaterialsProvider extends ChangeNotifier {
  List<StudyFolder> _folders = [];
  List<StudyFile> _files = [];
  List<StudyFolder> _breadcrumbs = [];
  String? _currentFolderId;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<StudyFolder> get folders => _folders;
  List<StudyFile> get files => _files;
  List<StudyFolder> get breadcrumbs => _breadcrumbs;
  String? get currentFolderId => _currentFolderId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAtRoot => _currentFolderId == null;

  /// Load root folders
  Future<void> loadRootFolders({String? branchId, int? semester}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _folders = await SupabaseService.getRootFolders(
        branchId: branchId,
        semester: semester,
      );
      _files = [];
      _currentFolderId = null;
      _breadcrumbs = [];
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load folders: $e';
      _isLoading = false;
      debugPrint('Error loading root folders: $e');
      notifyListeners();
    }
  }

  /// Navigate into a folder
  Future<void> openFolder(String folderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load subfolders and files in parallel
      final results = await Future.wait([
        SupabaseService.getSubfolders(folderId),
        SupabaseService.getFilesInFolder(folderId),
        SupabaseService.getFolderPath(folderId),
      ]);

      _folders = results[0] as List<StudyFolder>;
      _files = results[1] as List<StudyFile>;
      _breadcrumbs = results[2] as List<StudyFolder>;
      _currentFolderId = folderId;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load folder contents: $e';
      _isLoading = false;
      debugPrint('Error opening folder: $e');
      notifyListeners();
    }
  }

  /// Go back to parent folder
  Future<void> goBack() async {
    if (_breadcrumbs.isEmpty) {
      await loadRootFolders();
      return;
    }

    if (_breadcrumbs.length == 1) {
      await loadRootFolders();
      return;
    }

    // Go to parent folder
    final parentIndex = _breadcrumbs.length - 2;
    final parentFolder = _breadcrumbs[parentIndex];
    await openFolder(parentFolder.id);
  }

  /// Navigate to a specific breadcrumb
  Future<void> navigateToBreadcrumb(int index) async {
    if (index < 0 || index >= _breadcrumbs.length) {
      await loadRootFolders();
      return;
    }

    await openFolder(_breadcrumbs[index].id);
  }

  /// Create a new folder (Teacher only)
  Future<StudyFolder?> createFolder({
    required String name,
    String? description,
    required String teacherId,
    String? subjectId,
    String? branchId,
    int? semester,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final folder = await SupabaseService.createFolder(
        name: name,
        description: description,
        parentId: _currentFolderId,
        createdBy: teacherId,
        subjectId: subjectId,
        branchId: branchId,
        semester: semester,
      );

      if (folder != null) {
        _folders.add(folder);
        _folders.sort((a, b) => a.name.compareTo(b.name));
      }

      _isLoading = false;
      notifyListeners();
      return folder;
    } catch (e) {
      _error = 'Failed to create folder: $e';
      _isLoading = false;
      debugPrint('Error creating folder: $e');
      notifyListeners();
      return null;
    }
  }

  /// Update a folder (Teacher only)
  Future<bool> updateFolder(String folderId,
      {String? name, String? description}) async {
    _error = null;

    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;

      final success = await SupabaseService.updateFolder(folderId, data);

      if (success) {
        final index = _folders.indexWhere((f) => f.id == folderId);
        if (index != -1) {
          _folders[index] = _folders[index].copyWith(
            name: name ?? _folders[index].name,
            description: description ?? _folders[index].description,
          );
          _folders.sort((a, b) => a.name.compareTo(b.name));
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _error = 'Failed to update folder: $e';
      debugPrint('Error updating folder: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete a folder (Teacher only)
  Future<bool> deleteFolder(String folderId) async {
    _error = null;

    try {
      final success = await SupabaseService.deleteFolder(folderId);

      if (success) {
        _folders.removeWhere((f) => f.id == folderId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = 'Failed to delete folder: $e';
      debugPrint('Error deleting folder: $e');
      notifyListeners();
      return false;
    }
  }

  /// Upload a file (Teacher only)
  Future<StudyFile?> uploadFile({
    required String name,
    required String filePath,
    required String fileType,
    required int fileSize,
    String? description,
    required String teacherId,
  }) async {
    if (_currentFolderId == null) {
      _error = 'Please select a folder first';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final file = await SupabaseService.uploadFile(
        name: name,
        folderId: _currentFolderId!,
        filePath: filePath,
        fileType: fileType,
        fileSize: fileSize,
        description: description,
        uploadedBy: teacherId,
      );

      if (file != null) {
        _files.add(file);
        _files.sort((a, b) => a.name.compareTo(b.name));
      }

      _isLoading = false;
      notifyListeners();
      return file;
    } catch (e) {
      _error = 'Failed to upload file: $e';
      _isLoading = false;
      debugPrint('Error uploading file: $e');
      notifyListeners();
      return null;
    }
  }

  /// Create file record with URL (Teacher only)
  Future<StudyFile?> createFileWithUrl({
    required String name,
    required String fileUrl,
    required String fileType,
    required int fileSize,
    String? description,
    required String teacherId,
  }) async {
    if (_currentFolderId == null) {
      _error = 'Please select a folder first';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final file = await SupabaseService.createFileRecord(
        name: name,
        folderId: _currentFolderId!,
        fileUrl: fileUrl,
        fileType: fileType,
        fileSize: fileSize,
        description: description,
        uploadedBy: teacherId,
      );

      if (file != null) {
        _files.add(file);
        _files.sort((a, b) => a.name.compareTo(b.name));
      }

      _isLoading = false;
      notifyListeners();
      return file;
    } catch (e) {
      _error = 'Failed to create file record: $e';
      _isLoading = false;
      debugPrint('Error creating file record: $e');
      notifyListeners();
      return null;
    }
  }

  /// Update a file (Teacher only)
  Future<bool> updateFile(String fileId,
      {String? name, String? description}) async {
    _error = null;

    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;

      final success = await SupabaseService.updateFile(fileId, data);

      if (success) {
        final index = _files.indexWhere((f) => f.id == fileId);
        if (index != -1) {
          _files[index] = _files[index].copyWith(
            name: name ?? _files[index].name,
            description: description ?? _files[index].description,
          );
          _files.sort((a, b) => a.name.compareTo(b.name));
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _error = 'Failed to update file: $e';
      debugPrint('Error updating file: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete a file (Teacher only)
  Future<bool> deleteFile(String fileId) async {
    _error = null;

    try {
      final success = await SupabaseService.deleteFile(fileId);

      if (success) {
        _files.removeWhere((f) => f.id == fileId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = 'Failed to delete file: $e';
      debugPrint('Error deleting file: $e');
      notifyListeners();
      return false;
    }
  }

  /// Track file download
  Future<void> trackDownload(String fileId) async {
    await SupabaseService.incrementDownloadCount(fileId);

    final index = _files.indexWhere((f) => f.id == fileId);
    if (index != -1) {
      _files[index] = _files[index].copyWith(
        downloadCount: _files[index].downloadCount + 1,
      );
      notifyListeners();
    }
  }

  /// Search materials
  Future<Map<String, dynamic>> search(String query,
      {String? branchId, int? semester}) async {
    try {
      return await SupabaseService.searchStudyMaterials(
        query,
        branchId: branchId,
        semester: semester,
      );
    } catch (e) {
      debugPrint('Error searching: $e');
      return {'folders': [], 'files': []};
    }
  }

  /// Get folders created by a teacher
  Future<List<StudyFolder>> getTeacherFolders(String teacherId) async {
    try {
      return await SupabaseService.getTeacherFolders(teacherId);
    } catch (e) {
      debugPrint('Error getting teacher folders: $e');
      return [];
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh current view
  Future<void> refresh({String? branchId, int? semester}) async {
    if (_currentFolderId != null) {
      await openFolder(_currentFolderId!);
    } else {
      await loadRootFolders(branchId: branchId, semester: semester);
    }
  }
}
