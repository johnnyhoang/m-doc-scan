import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/document_model.dart';
import '../services/image_processing_service.dart';
import '../widgets/filter_chip_item.dart';
import 'dewarp_screen.dart';

class EnhanceScreen extends StatefulWidget {
  final DocumentPage page;
  final Function(DocumentPage) onSavePage;

  const EnhanceScreen({
    super.key,
    required this.page,
    required this.onSavePage,
  });

  @override
  State<EnhanceScreen> createState() => _EnhanceScreenState();
}

class _EnhanceScreenState extends State<EnhanceScreen> {
  late EnhancementMode _selectedMode;
  late FilterParams _params;
  img.Image? _baseCroppedImage;
  String? _enhancedPreviewPath;
  bool _isProcessing = false;
  bool _showOriginalCompare = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.page.enhancementMode;
    _params = widget.page.filterParams;
    _loadAndProcess();
  }

  Future<void> _loadAndProcess() async {
    final croppedPath = widget.page.croppedImagePath ?? widget.page.originalImagePath;
    final image = await ImageProcessingService.loadImage(croppedPath);
    if (image == null) return;

    _baseCroppedImage = image;
    await _applyFilter();
  }

  Future<void> _applyFilter() async {
    if (_baseCroppedImage == null) return;
    setState(() => _isProcessing = true);

    final enhanced = ImageProcessingService.processDocument(
      _baseCroppedImage!,
      mode: _selectedMode,
      params: _params,
    );

    final tempDir = await getTemporaryDirectory();
    final enhancedPath = '${tempDir.path}/enhanced_${widget.page.id}.jpg';
    await ImageProcessingService.saveImage(enhanced, enhancedPath);

    if (mounted) {
      setState(() {
        _enhancedPreviewPath = enhancedPath;
        _isProcessing = false;
      });
    }
  }

  void _saveFinal() {
    if (_enhancedPreviewPath == null) return;

    final updatedPage = widget.page.copyWith(
      enhancedImagePath: _enhancedPreviewPath,
      enhancementMode: _selectedMode,
      filterParams: _params,
    );
    widget.onSavePage(updatedPage);
  }

  Future<void> _copyImage() async {
    final targetPath = _enhancedPreviewPath ?? widget.page.croppedImagePath ?? widget.page.originalImagePath;
    final success = await ImageProcessingService.copyImageToClipboard(targetPath);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Đã sao chép ảnh vào bộ nhớ tạm (Clipboard)' : 'Không thể sao chép ảnh'),
        backgroundColor: success ? const Color(0xFF0D9488) : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAdjustmentsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tinh chỉnh thông số',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _params = const FilterParams();
                            });
                            setState(() {});
                            _applyFilter();
                          },
                          child: const Text('Đặt lại', style: TextStyle(color: Color(0xFF14B8A6))),
                        )
                      ],
                    ),
                    const Divider(color: Color(0xFF334155)),

                    // Shadow Reduction Slider
                    _buildSliderRow(
                      title: 'Khử bóng nếp gấp (Shadows)',
                      value: _params.shadowReduction,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        setModalState(() => _params = _params.copyWith(shadowReduction: val));
                        setState(() {});
                      },
                      onChangeEnd: (_) => _applyFilter(),
                    ),

                    // Sharpness Slider
                    _buildSliderRow(
                      title: 'Độ sắc nét nét chữ (Sharpness)',
                      value: _params.sharpness,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        setModalState(() => _params = _params.copyWith(sharpness: val));
                        setState(() {});
                      },
                      onChangeEnd: (_) => _applyFilter(),
                    ),

                    // Contrast Slider
                    _buildSliderRow(
                      title: 'Độ tương phản (Contrast)',
                      value: _params.contrast,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        setModalState(() => _params = _params.copyWith(contrast: val));
                        setState(() {});
                      },
                      onChangeEnd: (_) => _applyFilter(),
                    ),

                    // Brightness Slider
                    _buildSliderRow(
                      title: 'Độ sáng (Brightness)',
                      value: _params.brightness,
                      min: -1.0,
                      max: 1.0,
                      onChanged: (val) {
                        setModalState(() => _params = _params.copyWith(brightness: val));
                        setState(() {});
                      },
                      onChangeEnd: (_) => _applyFilter(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSliderRow({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text('${(value * 100).round()}%', style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFF14B8A6),
          inactiveColor: const Color(0xFF334155),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final croppedPath = widget.page.croppedImagePath ?? widget.page.originalImagePath;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Bộ lọc & Tăng cường', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Sao chép ảnh',
            onPressed: _copyImage,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Tinh chỉnh chi tiết',
            onPressed: _showAdjustmentsModal,
          ),
          IconButton(
            icon: const Icon(Icons.waves),
            tooltip: 'Làm phẳng nếp gấp',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DewarpScreen(
                    imagePath: croppedPath,
                    initialStrength: _params.dewarpStrength > 0 ? _params.dewarpStrength : 0.8,
                    onApplyDewarp: (dewarpedPath) async {
                      final image = await ImageProcessingService.loadImage(dewarpedPath);
                      if (image != null) {
                        setState(() {
                          _baseCroppedImage = image;
                          _params = _params.copyWith(dewarpStrength: 0.8);
                        });
                        _applyFilter();
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter description banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF14B8A6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedMode.description,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTapDown: (_) => setState(() => _showOriginalCompare = true),
                  onTapUp: (_) => setState(() => _showOriginalCompare = false),
                  onTapCancel: () => setState(() => _showOriginalCompare = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Giữ để so sánh', style: TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),

          // Main image preview
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_showOriginalCompare)
                    Image.file(File(croppedPath), fit: BoxFit.contain)
                  else if (_enhancedPreviewPath != null)
                    Image.file(File(_enhancedPreviewPath!), fit: BoxFit.contain)
                  else
                    Image.file(File(croppedPath), fit: BoxFit.contain),

                  if (_isProcessing)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      padding: const EdgeInsets.all(16),
                      child: const CircularProgressIndicator(color: Color(0xFF14B8A6)),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Filter Selector & Action bar
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            child: Column(
              children: [
                // Horizontal filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: EnhancementMode.values.map((mode) {
                      return FilterChipItem(
                        mode: mode,
                        isSelected: _selectedMode == mode,
                        onTap: () {
                          setState(() => _selectedMode = mode);
                          _applyFilter();
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Action buttons: Copy & Save
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF14B8A6)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.copy_outlined, size: 20),
                            label: const Text('Sao chép', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            onPressed: _copyImage,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 20),
                            label: const Text('Lưu trang', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            onPressed: _saveFinal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
