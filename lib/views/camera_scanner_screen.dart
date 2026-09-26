import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CameraScannerScreen extends StatefulWidget {
  final Function(List<String> capturedPaths) onScanCompleted;

  const CameraScannerScreen({
    super.key,
    required this.onScanCompleted,
  });

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isTakingPhoto = false;
  FlashMode _flashMode = FlashMode.auto;
  final List<String> _capturedImages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      print('Camera initialization error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    FlashMode nextMode;
    if (_flashMode == FlashMode.auto) {
      nextMode = FlashMode.always;
    } else if (_flashMode == FlashMode.always) {
      nextMode = FlashMode.off;
    } else {
      nextMode = FlashMode.auto;
    }

    await _cameraController!.setFlashMode(nextMode);
    setState(() => _flashMode = nextMode);
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isTakingPhoto) return;

    try {
      setState(() => _isTakingPhoto = true);
      final xFile = await _cameraController!.takePicture();
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/scan_raw_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(xFile.path).copy(targetPath);

      setState(() {
        _capturedImages.add(targetPath);
        _isTakingPhoto = false;
      });
    } catch (e) {
      print('Capture photo error: $e');
      setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _importFromGallery() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      final paths = pickedFiles.map((f) => f.path).toList();
      widget.onScanCompleted(paths);
      Navigator.pop(context);
    }
  }

  void _finishScanning() {
    if (_capturedImages.isNotEmpty) {
      widget.onScanCompleted(_capturedImages);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Máy quét tài liệu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(
              _flashMode == FlashMode.always
                  ? Icons.flash_on
                  : _flashMode == FlashMode.auto
                      ? Icons.flash_auto
                      : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          if (_isCameraInitialized && _cameraController != null)
            Center(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
            ),

          // Document framing guide overlay
          IgnorePointer(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Căn chỉnh mép tài liệu vào khung',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      shadows: const [Shadow(color: Colors.black84, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Control Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Gallery Import Button
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28),
                    tooltip: 'Chọn ảnh từ thư viện',
                    onPressed: _importFromGallery,
                  ),

                  // Shutter Button
                  GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D9488),
                            shape: BoxShape.circle,
                          ),
                          child: _isTakingPhoto
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                              : null,
                        ),
                      ),
                    ),
                  ),

                  // Finish Scanning / Counter badge
                  if (_capturedImages.isNotEmpty)
                    Badge(
                      label: Text('${_capturedImages.length}'),
                      backgroundColor: const Color(0xFF2563EB),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _finishScanning,
                        child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
