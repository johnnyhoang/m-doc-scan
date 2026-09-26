import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../services/image_processing_service.dart';
import '../services/pdf_service.dart';
import '../services/smart_namer_service.dart';
import '../services/storage_service.dart';
import 'camera_scanner_screen.dart';
import 'crop_screen.dart';
import 'enhance_screen.dart';

class DocumentViewScreen extends StatefulWidget {
  final DocumentItem document;

  const DocumentViewScreen({super.key, required this.document});

  @override
  State<DocumentViewScreen> createState() => _DocumentViewScreenState();
}

class _DocumentViewScreenState extends State<DocumentViewScreen> {
  late DocumentItem _doc;
  int _selectedPageIndex = 0;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
  }

  Future<void> _saveCurrentDoc() async {
    await StorageService.saveDocument(_doc);
    setState(() {});
  }

  Future<void> _sharePdf() async {
    if (_doc.pages.isEmpty) return;
    setState(() => _isExporting = true);

    try {
      final pdfFile = await PdfService.generatePdf(_doc);
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: 'Tài liệu scan: ${_doc.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Có lỗi xảy ra khi chia sẻ tài liệu')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _printDocument() async {
    if (_doc.pages.isEmpty) return;
    await PdfService.printDocument(_doc);
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _doc.name);
    final suggestions = SmartNamerService.generateSuggestions(
      hintText: _doc.name,
      pageCount: _doc.pageCount,
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Đổi tên tài liệu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Tên tài liệu',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => controller.clear(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Gợi ý thông minh:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: suggestions.map((sug) {
                        return ActionChip(
                          label: Text(sug, style: const TextStyle(fontSize: 12)),
                          backgroundColor: const Color(0xFF0D9488).withOpacity(0.1),
                          side: const BorderSide(color: Color(0xFF0D9488)),
                          onPressed: () {
                            controller.text = sug;
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.isNotEmpty) {
                      setState(() {
                        _doc = _doc.copyWith(name: newName, updatedAt: DateTime.now());
                      });
                      await _saveCurrentDoc();
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _rotateCurrentPage() async {
    if (_doc.pages.isEmpty) return;
    final page = _doc.pages[_selectedPageIndex];
    final displayPath = page.displayPath;

    final imgObj = await ImageProcessingService.loadImage(displayPath);
    if (imgObj != null) {
      final rotated = ImageProcessingService.rotateImage(imgObj, 90);
      await ImageProcessingService.saveImage(rotated, displayPath);

      final updatedPages = List<DocumentPage>.from(_doc.pages);
      updatedPages[_selectedPageIndex] = page.copyWith(
        rotationAngle: (page.rotationAngle + 90) % 360,
      );

      setState(() {
        _doc = _doc.copyWith(pages: updatedPages, updatedAt: DateTime.now());
      });
      await _saveCurrentDoc();
    }
  }

  void _deleteCurrentPage() {
    if (_doc.pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tài liệu phải có ít nhất 1 trang')),
      );
      return;
    }

    final updatedPages = List<DocumentPage>.from(_doc.pages)..removeAt(_selectedPageIndex);
    for (int i = 0; i < updatedPages.length; i++) {
      updatedPages[i] = updatedPages[i].copyWith(pageNumber: i + 1);
    }

    setState(() {
      _doc = _doc.copyWith(pages: updatedPages, updatedAt: DateTime.now());
      if (_selectedPageIndex >= updatedPages.length) {
        _selectedPageIndex = updatedPages.length - 1;
      }
    });
    _saveCurrentDoc();
  }

  void _addNewPagesFromCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScannerScreen(
          onScanCompleted: (paths) => _processNewImages(paths),
        ),
      ),
    );
  }

  Future<void> _addNewPagesFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      _processNewImages(picked.map((p) => p.path).toList());
    }
  }

  Future<void> _processNewImages(List<String> paths) async {
    final newPages = <DocumentPage>[];
    int startIdx = _doc.pages.length + 1;

    for (final path in paths) {
      final pageId = const Uuid().v4();
      final page = DocumentPage(
        id: pageId,
        pageNumber: startIdx++,
        originalImagePath: path,
      );
      newPages.add(page);
    }

    setState(() {
      _doc = _doc.copyWith(
        pages: [..._doc.pages, ...newPages],
        updatedAt: DateTime.now(),
      );
    });
    await _saveCurrentDoc();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPage = _doc.pages.isNotEmpty ? _doc.pages[_selectedPageIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _showRenameDialog,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _doc.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 16, color: Color(0xFF0D9488)),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'In tài liệu',
            onPressed: _printDocument,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Chia sẻ PDF',
            onPressed: _sharePdf,
          ),
        ],
      ),
      body: _isExporting
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
          : Column(
              children: [
                // Top Page Carousel / Main Preview
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: currentPage != null && File(currentPage.displayPath).existsSync()
                        ? InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Image.file(
                              File(currentPage.displayPath),
                              fit: BoxFit.contain,
                              key: ValueKey(currentPage.displayPath + DateTime.now().millisecondsSinceEpoch.toString()),
                            ),
                          )
                        : const Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey)),
                  ),
                ),

                // Per-page Quick Action Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildToolbarButton(
                        icon: Icons.crop,
                        label: 'Cắt góc',
                        onTap: () {
                          if (currentPage == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CropScreen(
                                imagePath: currentPage.originalImagePath,
                                existingPage: currentPage,
                                onSavePage: (updatedPage) {
                                  final list = List<DocumentPage>.from(_doc.pages);
                                  list[_selectedPageIndex] = updatedPage;
                                  setState(() {
                                    _doc = _doc.copyWith(pages: list, updatedAt: DateTime.now());
                                  });
                                  _saveCurrentDoc();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      _buildToolbarButton(
                        icon: Icons.auto_awesome,
                        label: 'Bộ lọc',
                        onTap: () {
                          if (currentPage == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EnhanceScreen(
                                page: currentPage,
                                onSavePage: (updatedPage) {
                                  final list = List<DocumentPage>.from(_doc.pages);
                                  list[_selectedPageIndex] = updatedPage;
                                  setState(() {
                                    _doc = _doc.copyWith(pages: list, updatedAt: DateTime.now());
                                  });
                                  _saveCurrentDoc();
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      _buildToolbarButton(
                        icon: Icons.rotate_right,
                        label: 'Xoay 90°',
                        onTap: _rotateCurrentPage,
                      ),
                      _buildToolbarButton(
                        icon: Icons.delete_outline,
                        label: 'Xóa trang',
                        color: Colors.red,
                        onTap: _deleteCurrentPage,
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Multi-page Horizontal Thumbnail Strip & Add Page Button
                Container(
                  height: 100,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _doc.pages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _doc.pages.length) {
                        return Container(
                          width: 60,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF0D9488), width: 1.5, style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt, color: Color(0xFF0D9488)),
                                        title: const Text('Chụp trang mới'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _addNewPagesFromCamera();
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_library, color: Color(0xFF2563EB)),
                                        title: const Text('Chọn ảnh từ thư viện'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _addNewPagesFromGallery();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, color: Color(0xFF0D9488)),
                                Text('Thêm', style: TextStyle(fontSize: 10, color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      }

                      final page = _doc.pages[index];
                      final isSelected = _selectedPageIndex == index;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedPageIndex = index),
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0D9488) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(page.displayPath), fit: BoxFit.cover),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final btnColor = color ?? theme.textTheme.bodyMedium?.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: btnColor),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: btnColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
