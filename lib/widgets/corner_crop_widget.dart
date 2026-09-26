import 'package:flutter/material.dart';
import '../models/document_model.dart';

class CornerCropWidget extends StatefulWidget {
  final QuadCorners corners;
  final Size imageDisplaySize;
  final ValueChanged<QuadCorners> onCornersChanged;

  const CornerCropWidget({
    super.key,
    required this.corners,
    required this.imageDisplaySize,
    required this.onCornersChanged,
  });

  @override
  State<CornerCropWidget> createState() => _CornerCropWidgetState();
}

class _CornerCropWidgetState extends State<CornerCropWidget> {
  int? _activeCornerIndex; // 0: TL, 1: TR, 2: BR, 3: BL

  @override
  Widget build(BuildContext context) {
    final pts = widget.corners.toList();

    return GestureDetector(
      onPanStart: (details) {
        final pos = details.localPosition;
        int? closestIndex;
        double minDistance = 40.0; // 40px touch target

        for (int i = 0; i < pts.length; i++) {
          final dist = Point2D(pos.dx, pos.dy).distanceTo(pts[i]);
          if (dist < minDistance) {
            minDistance = dist;
            closestIndex = i;
          }
        }
        setState(() => _activeCornerIndex = closestIndex);
      },
      onPanUpdate: (details) {
        if (_activeCornerIndex == null) return;

        final newPos = Point2D(
          details.localPosition.dx.clamp(0.0, widget.imageDisplaySize.width),
          details.localPosition.dy.clamp(0.0, widget.imageDisplaySize.height),
        );

        final updatedList = List<Point2D>.from(pts);
        updatedList[_activeCornerIndex!] = newPos;

        widget.onCornersChanged(QuadCorners.fromList(updatedList));
      },
      onPanEnd: (_) => setState(() => _activeCornerIndex = null),
      onPanCancel: () => setState(() => _activeCornerIndex = null),
      child: CustomPaint(
        size: widget.imageDisplaySize,
        painter: _QuadCropPainter(
          corners: widget.corners,
          activeIndex: _activeCornerIndex,
        ),
      ),
    );
  }
}

class _QuadCropPainter extends CustomPainter {
  final QuadCorners corners;
  final int? activeIndex;

  _QuadCropPainter({required this.corners, this.activeIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [
      Offset(corners.topLeft.x, corners.topLeft.y),
      Offset(corners.topRight.x, corners.topRight.y),
      Offset(corners.bottomRight.x, corners.bottomRight.y),
      Offset(corners.bottomLeft.x, corners.bottomLeft.y),
    ];

    // Dim mask outside polygon
    final path = Path()..addPolygon(pts, true);
    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final overlayPath = Path.combine(PathOperation.difference, bgPath, path);

    final dimPaint = Paint()..color = Colors.black.withOpacity(0.45);
    canvas.drawPath(overlayPath, dimPaint);

    // Quad border stroke
    final borderPaint = Paint()
      ..color = const Color(0xFF14B8A6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);

    // Corner circles & crosshairs
    for (int i = 0; i < pts.length; i++) {
      final isCurrentActive = activeIndex == i;
      final center = pts[i];

      // Outer glow/ring
      final circlePaint = Paint()
        ..color = isCurrentActive ? const Color(0xFF2563EB) : const Color(0xFF14B8A6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, isCurrentActive ? 14 : 10, circlePaint);

      // Inner white dot
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, isCurrentActive ? 6 : 4, whitePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _QuadCropPainter oldDelegate) {
    return oldDelegate.corners != corners || oldDelegate.activeIndex != activeIndex;
  }
}
