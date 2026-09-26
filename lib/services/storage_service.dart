import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/document_model.dart';

class StorageService {
  static const String _metadataFileName = 'documents_index.json';

  static Future<Directory> getAppStorageDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${docsDir.path}/DocScan');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  static Future<File> _getMetadataFile() async {
    final appDir = await getAppStorageDir();
    return File('${appDir.path}/$_metadataFileName');
  }

  /// Load all saved documents
  static Future<List<DocumentItem>> loadDocuments() async {
    try {
      final file = await _getMetadataFile();
      if (!await file.exists()) {
        return [];
      }
      final jsonStr = await file.readAsString();
      if (jsonStr.trim().isEmpty) return [];

      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((item) => DocumentItem.fromJson(item as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      print('Error loading documents: $e');
      return [];
    }
  }

  /// Save or update document
  static Future<void> saveDocument(DocumentItem doc) async {
    final docs = await loadDocuments();
    final index = docs.indexWhere((d) => d.id == doc.id);

    if (index >= 0) {
      docs[index] = doc;
    } else {
      docs.insert(0, doc);
    }

    final file = await _getMetadataFile();
    final jsonList = docs.map((d) => d.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  /// Delete document and its image files
  static Future<void> deleteDocument(String docId) async {
    final docs = await loadDocuments();
    final target = docs.firstWhere((d) => d.id == docId, orElse: () => throw Exception('Doc not found'));

    // Delete image files
    for (final page in target.pages) {
      _tryDeleteFile(page.originalImagePath);
      _tryDeleteFile(page.croppedImagePath);
      _tryDeleteFile(page.enhancedImagePath);
    }

    docs.removeWhere((d) => d.id == docId);

    final file = await _getMetadataFile();
    final jsonList = docs.map((d) => d.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  static void _tryDeleteFile(String? path) {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }
}
