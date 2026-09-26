import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../services/image_processing_service.dart';
import '../widgets/corner_crop_widget.dart';
import 'enhance_screen.dart';

class CropScreen extends StatefulWidget {
  final String imagePath;
  final DocumentPage? existingPage;
  final Function(DocumentPage) onSavePage;

  const CropScreen({
    super.key,
    required this.imagePath,
    this.existingPage,
    required this.onSavePage,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  img.Image? _loadedImage;
  QuadCorners? _displayCorners;
  Size? _displaySize;
  bool _isLoading = true;
  int _currentRotation = 0;

  @override
  void initState() {
    super.initState();
    _loadImageAndDetect();
  }

  Future<void> _loadImageAndDetect() async {
    setState(() => _isLoading = true);
    final image = await ImageProcessingService.loadImage(widget.imagePath);
    if (image == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải hình ảnh')),
        );
        Navigator.pop(context);
      }
      return;
    }

    _loadedImage = image;
    _currentRotation = widget.existingPage?.rotationAngle ?? 0;
    if (_currentRotation != 0) {
      _loadedImage = ImageProcessingService.rotateImage(_loadedImage!, _currentRotation);
    }

    setState(() => _isLoading = false);
  }

  void _initDisplayCorners(Size displaySize) {
    if (_displayCorners != null || _loadedImage == null) return;

    _displaySize = displaySize;
    final imgW = _loadedImage!.width.toDouble();
    final imgH = _loadedImage!.height.toDouble();

    final rawCorners = ImageProcessingService.detectCorners(_loadedImage!);

    // Scale from image coordinates to display coordinates
    final scaleX = displaySize.width / imgW;
    final scaleY = displaySize.height / imgH;

    setState(() {
      _displayCorners = QuadCorners(
        topLeft: Point2D(rawCorners.topLeft.x * scaleX, rawCorners.topLeft.y * scaleY),
        topRight: Point2D(rawCorners.topRight.x * scaleX, rawCorners.topRight.y * scaleY),
        bottomRight: Point2D(rawCorners.bottomRight.x * scaleX, rawCorners.bottomRight.y * scaleY),
        bottomLeft: Point2D(rawCorners.bottomLeft.x * scaleX, rawCorners.bottomLeft.y * scaleY),
      );
    });
  }

  void _resetToFull() {
    if (_displaySize == null) return;
    setState(() {
      _displayCorners = QuadCorners.defaultForSize(_displaySize!.width, _displaySize!.height, insetPercent: 0.02);
    });
  }

  void _autoDetect() {
    if (_loadedImage == null || _displaySize == null) return;
    final imgW = _loadedImage!.width.toDouble();
    final imgH = _loadedImage!.height.toDouble();
    final detected = ImageProcessingService.detectCorners(_loadedImage!);

    final scaleX = _displaySize!.width / imgW;
    final scaleY = _displaySize!.height / imgH;

    setState(() {
      _displayCorners = QuadCorners(
        topLeft: Point2D(detected.topLeft.x * scaleX, detected.topLeft.y * scaleY),
        topRight: Point2D(detected.topRight.x * scaleX, detected.topRight.y * scaleY),
        bottomRight: Point2D(detected.bottomRight.x * scaleX, detected.bottomRight.y * scaleY),
        bottomLeft: Point2D(detected.bottomLeft.x * scaleX, detected.bottomLeft.y * scaleY),
      );
    });
  }

  void _rotate() {
    if (_loadedImage == null) return;
    setState(() {
      _isLoading = true;
      _currentRotation = (_currentRotation + 90) % 360;
      _loadedImage = ImageProcessingService.rotateImage(_loadedImage!, 90);
      _displayCorners = null;
      _isLoading = false;
    });
  }

  Future<void> _proceedToEnhance() async {
    if (_loadedImage == null || _displayCorners == null || _displaySize == null) return;

    setState(() => _isLoading = true);

    final imgW = _loadedImage!.width.toDouble();
    final imgH = _loadedImage!.height.toDouble();

    // Convert display corners to pixel coordinates
    final scaleX = imgW / _displaySize!.width;
    final scaleY = imgH / _displaySize!.height;

    final pixelCorners = QuadCorners(
      topLeft: Point2D(_displayCorners!.topLeft.x * scaleX, _displayCorners!.topLeft.y * scaleY),
      topRight: Point2D(_displayCorners!.topRight.x * scaleX, _displayCorners!.topRight.y * scaleY),
      bottomRight: Point2D(_displayCorners!.bottomRight.x * scaleX, _displayCorners!.bottomRight.y * scaleY),
      bottomLeft: Point2D(_displayCorners!.bottomLeft.x * scaleX, _displayCorners!.bottomLeft.y * scaleY),
    );

    // Warp perspective
    final warpedImg = ImageProcessingService.warpPerspective(_loadedImage!, pixelCorners);

    final tempDir = await getTemporaryDirectory();
    final pageId = widget.existingPage?.id ?? const Uuid().v4();
    final croppedPath = '${tempDir.path}/cropped_$pageId.jpg';
    await ImageProcessingService.saveImage(warpedImg, croppedPath);

    final updatedPage = (widget.existingPage ??
            DocumentPage(
              id: pageId,
              pageNumber: 1,
              originalImagePath: widget.imagePath,
            ))
        .copyWith(
      croppedImagePath: croppedPath,
      corners: pixelCorners,
      rotationAngle: _currentRotation,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhanceScreen(
          page: updatedPage,
          onSavePage: (savedPage) {
            widget.onSavePage(savedPage);
            Navigator.pop(context); // Pop Crop
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Cắt & Căn chỉnh góc', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Xoay 90°',
            onPressed: _rotate,
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Chọn toàn bộ',
            onPressed: _resetToFull,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final maxHeight = constraints.maxHeight - 80;

                final imgW = _loadedImage!.width.toDouble();
                final imgH = _loadedImage!.height.toDouble();

                final imgAspect = imgW / imgH;
                final boxAspect = maxWidth / maxHeight;

                double displayW;
                double displayH;

                if (imgAspect > boxAspect) {
                  displayW = maxWidth;
                  displayH = maxWidth / imgAspect;
                } else {
                  displayH = maxHeight;
                  displayW = maxHeight * imgAspect;
                }

                final displaySize = Size(displayW, displayH);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _initDisplayCorners(displaySize);
                });

                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: displayW,
                          height: displayH,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                File(widget.imagePath),
                                fit: BoxFit.fill,
                              ),
                              if (_displayCorners != null)
                                CornerCropWidget(
                                  corners: _displayCorners!,
                                  imageDisplaySize: displaySize,
                                  onCornersChanged: (newCorners) {
                                    setState(() => _displayCorners = newCorners);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom action toolbar
                    Container(
                      height: 80,
                      color: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF334155)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.auto_fix_high, size: 18),
                            label: const Text('Tự động nhận diện'),
                            onPressed: _autoDetect,
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.check, size: 20),
                            label: const Text('Tiếp tục', style: TextStyle(fontWeight: FontWeight.w600)),
                            onPressed: _proceedToEnhance,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
