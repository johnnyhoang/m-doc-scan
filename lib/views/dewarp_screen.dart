import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../services/image_processing_service.dart';

class DewarpScreen extends StatefulWidget {
  final String imagePath;
  final double initialStrength;
  final ValueChanged<String> onApplyDewarp;

  const DewarpScreen({
    super.key,
    required this.imagePath,
    this.initialStrength = 0.8,
    required this.onApplyDewarp,
  });

  @override
  State<DewarpScreen> createState() => _DewarpScreenState();
}

class _DewarpScreenState extends State<DewarpScreen> {
  late double _strength;
  img.Image? _baseImage;
  String? _previewPath;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _strength = widget.initialStrength;
    _loadBase();
  }

  Future<void> _loadBase() async {
    final image = await ImageProcessingService.loadImage(widget.imagePath);
    if (image != null) {
      _baseImage = image;
      _applyDewarpPreview();
    }
  }

  Future<void> _applyDewarpPreview() async {
    if (_baseImage == null) return;
    setState(() => _isProcessing = true);

    final dewarped = ImageProcessingService.dewarpPage(_baseImage!, strength: _strength);
    final tempDir = await getTemporaryDirectory();
    final previewFile = '${tempDir.path}/dewarp_preview_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await ImageProcessingService.saveImage(dewarped, previewFile);

    if (mounted) {
      setState(() {
        _previewPath = previewFile;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Làm phẳng nếp gấp & độ cong', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () {
              if (_previewPath != null) {
                widget.onApplyDewarp(_previewPath!);
                Navigator.pop(context);
              }
            },
            child: const Text('Áp dụng', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _previewPath != null
                  ? Image.file(
                      File(_previewPath!),
                      fit: BoxFit.contain,
                    )
                  : const CircularProgressIndicator(color: Color(0xFF14B8A6)),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1E293B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Độ làm phẳng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    Text('${(_strength * 100).round()}%', style: const TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _strength,
                  min: 0.0,
                  max: 1.0,
                  activeColor: const Color(0xFF14B8A6),
                  inactiveColor: const Color(0xFF334155),
                  onChanged: (val) => setState(() => _strength = val),
                  onChangeEnd: (_) => _applyDewarpPreview(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
