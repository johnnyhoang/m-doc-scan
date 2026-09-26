import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../services/pdf_service.dart';
import '../services/smart_namer_service.dart';
import '../services/storage_service.dart';
import '../widgets/document_card.dart';
import 'camera_scanner_screen.dart';
import 'crop_screen.dart';
import 'document_view_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DocumentItem> _documents = [];
  List<DocumentItem> _filteredDocuments = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _searchController.addListener(_filterDocuments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = await StorageService.loadDocuments();
    if (mounted) {
      setState(() {
        _documents = docs;
        _filteredDocuments = docs;
        _isLoading = false;
      });
    }
  }

  void _filterDocuments() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDocuments = _documents;
      } else {
        _filteredDocuments = _documents.where((d) => d.name.toLowerCase().contains(query)).toList();
      }
    });
  }

  Future<void> _startScanFlow(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return;

    final docId = const Uuid().v4();
    final suggestedName = SmartNamerService.generateSuggestions(
      hintText: imagePaths.first,
      pageCount: imagePaths.length,
    ).first;

    final pages = <DocumentPage>[];
    for (int i = 0; i < imagePaths.length; i++) {
      pages.add(DocumentPage(
        id: const Uuid().v4(),
        pageNumber: i + 1,
        originalImagePath: imagePaths[i],
      ));
    }

    final newDoc = DocumentItem(
      id: docId,
      name: suggestedName,
      pages: pages,
    );

    await StorageService.saveDocument(newDoc);
    await _loadDocuments();

    if (!mounted) return;

    // Navigate to crop the first page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropScreen(
          imagePath: pages.first.originalImagePath,
          existingPage: pages.first,
          onSavePage: (savedPage) async {
            final updatedPages = List<DocumentPage>.from(newDoc.pages);
            updatedPages[0] = savedPage;
            final updatedDoc = newDoc.copyWith(pages: updatedPages);
            await StorageService.saveDocument(updatedDoc);
            await _loadDocuments();

            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentViewScreen(document: updatedDoc),
                ),
              ).then((_) => _loadDocuments());
            }
          },
        ),
      ),
    );
  }

  Future<void> _importFromGallery() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      final paths = pickedFiles.map((f) => f.path).toList();
      _startScanFlow(paths);
    }
  }

  void _openCameraScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScannerScreen(
          onScanCompleted: (paths) => _startScanFlow(paths),
        ),
      ),
    );
  }

  Future<void> _deleteDocument(DocumentItem doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa tài liệu'),
        content: Text('Bạn có chắc chắn muốn xóa "${doc.name}"? Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteDocument(doc.id);
      await _loadDocuments();
    }
  }

  Future<void> _renameDocument(DocumentItem doc) async {
    final controller = TextEditingController(text: doc.name);
    final suggestions = SmartNamerService.generateSuggestions(
      hintText: doc.name,
      pageCount: doc.pageCount,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên tài liệu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Tên mới',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestions.map((sug) {
                  return ActionChip(
                    label: Text(sug, style: const TextStyle(fontSize: 12)),
                    onPressed: () => controller.text = sug,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final updated = doc.copyWith(name: newName, updatedAt: DateTime.now());
      await StorageService.saveDocument(updated);
      await _loadDocuments();
    }
  }

  Future<void> _shareDocument(DocumentItem doc) async {
    final pdf = await PdfService.generatePdf(doc);
    await Share.shareXFiles([XFile(pdf.path)], text: doc.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.document_scanner, color: Color(0xFF0D9488), size: 22),
            ),
            const SizedBox(width: 10),
            const Text('DocScan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm tài liệu đã quét...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchController.clear())
                    : null,
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
              ),
            ),
          ),

          // Document List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
                : _filteredDocuments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.withOpacity(0.6)),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Chưa có tài liệu nào'
                                  : 'Không tìm thấy tài liệu phù hợp',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Nhấn vào nút máy ảnh hoặc thư viện để bắt đầu quét',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredDocuments.length,
                        itemBuilder: (context, index) {
                          final doc = _filteredDocuments[index];
                          return DocumentCard(
                            document: doc,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DocumentViewScreen(document: doc),
                                ),
                              ).then((_) => _loadDocuments());
                            },
                            onShare: () => _shareDocument(doc),
                            onRename: () => _renameDocument(doc),
                            onDelete: () => _deleteDocument(doc),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton.extended(
              heroTag: 'gallery_btn',
              onPressed: _importFromGallery,
              backgroundColor: theme.cardColor,
              foregroundColor: theme.textTheme.bodyMedium?.color,
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              label: const Text('Thư viện', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            FloatingActionButton.extended(
              heroTag: 'camera_btn',
              onPressed: _openCameraScanner,
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.camera_alt, size: 22),
              label: const Text('Quét tài liệu', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
