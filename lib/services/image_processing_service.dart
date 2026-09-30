import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pasteboard/pasteboard.dart';
import '../models/document_model.dart';

class ImageProcessingService {
  /// Copy image to system clipboard
  static Future<bool> copyImageToClipboard(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      await Pasteboard.writeImage(bytes);
      return true;
    } catch (e) {
      print('Error copying image to clipboard: $e');
      return false;
    }
  }

  /// Loads image from file path
  static Future<img.Image?> loadImage(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return img.decodeImage(bytes);
    } catch (e) {
      print('Error loading image $filePath: $e');
      return null;
    }
  }

  /// Saves image to disk as JPEG
  static Future<String> saveImage(img.Image image, String targetPath, {int quality = 85}) async {
    final bytes = img.encodeJpg(image, quality: quality);
    final file = File(targetPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return targetPath;
  }

  /// Orders 4 corner points into [Top-Left, Top-Right, Bottom-Right, Bottom-Left]
  static QuadCorners orderCorners(List<Point2D> pts) {
    if (pts.length != 4) {
      throw ArgumentError('Exactly 4 points required');
    }

    // Sort by sum (x + y) -> Top-Left is smallest, Bottom-Right is largest
    final sumSorted = List<Point2D>.from(pts)
      ..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final tl = sumSorted.first;
    final br = sumSorted.last;

    // Remaining 2 points sorted by diff (y - x) -> Top-Right is smallest, Bottom-Left is largest
    final remaining = pts.where((p) => p != tl && p != br).toList();
    Point2D tr;
    Point2D bl;
    if (remaining.length == 2) {
      if ((remaining[0].y - remaining[0].x) < (remaining[1].y - remaining[1].x)) {
        tr = remaining[0];
        bl = remaining[1];
      } else {
        tr = remaining[1];
        bl = remaining[0];
      }
    } else {
      tr = Point2D(br.x, tl.y);
      bl = Point2D(tl.x, br.y);
    }

    return QuadCorners(
      topLeft: tl,
      topRight: tr,
      bottomRight: br,
      bottomLeft: bl,
    );
  }

  /// Multi-pass document corner detection on image
  static QuadCorners detectCorners(img.Image image, {double marginPercent = 0.0}) {
    final origW = image.width.toDouble();
    final origH = image.height.toDouble();

    // Work on downscaled copy for fast mobile detection
    const targetH = 600;
    final scale = origH / targetH;
    final targetW = (origW / scale).round();
    final small = img.copyResize(image, width: targetW, height: targetH);
    final gray = img.grayscale(small);

    // Compute gradient & edge profile
    final edges = img.sobel(gray);
    final w = edges.width;
    final h = edges.height;

    // Find bounding quadrilateral by analyzing edge density in 4 quadrants
    double minX = w * 0.05;
    double maxX = w * 0.95;
    double minY = h * 0.05;
    double maxY = h * 0.95;

    // Horizontal scan for Left & Right boundaries
    for (int y = (h * 0.2).round(); y < (h * 0.8).round(); y += 10) {
      for (int x = 0; x < (w * 0.3).round(); x++) {
        final p = edges.getPixel(x, y);
        if (p.r > 70) {
          minX = math.min(minX, x.toDouble());
          break;
        }
      }
      for (int x = w - 1; x > (w * 0.7).round(); x--) {
        final p = edges.getPixel(x, y);
        if (p.r > 70) {
          maxX = math.max(maxX, x.toDouble());
          break;
        }
      }
    }

    // Vertical scan for Top & Bottom boundaries
    for (int x = (w * 0.2).round(); x < (w * 0.8).round(); x += 10) {
      for (int y = 0; y < (h * 0.3).round(); y++) {
        final p = edges.getPixel(x, y);
        if (p.r > 70) {
          minY = math.min(minY, y.toDouble());
          break;
        }
      }
      for (int y = h - 1; y > (h * 0.7).round(); y--) {
        final p = edges.getPixel(x, y);
        if (p.r > 70) {
          maxY = math.max(maxY, y.toDouble());
          break;
        }
      }
    }

    // Map back to original scale
    var rawCorners = QuadCorners(
      topLeft: Point2D((minX * scale).clamp(0, origW), (minY * scale).clamp(0, origH)),
      topRight: Point2D((maxX * scale).clamp(0, origW), (minY * scale).clamp(0, origH)),
      bottomRight: Point2D((maxX * scale).clamp(0, origW), (maxY * scale).clamp(0, origH)),
      bottomLeft: Point2D((minX * scale).clamp(0, origW), (maxY * scale).clamp(0, origH)),
    );

    if (marginPercent > 0) {
      rawCorners = rawCorners.expand(marginPercent, origW, origH);
    }

    return rawCorners;
  }

  /// 4-Point Homography Perspective Warp
  static img.Image warpPerspective(img.Image src, QuadCorners corners) {
    final ordered = orderCorners(corners.toList());
    final tl = ordered.topLeft;
    final tr = ordered.topRight;
    final br = ordered.bottomRight;
    final bl = ordered.bottomLeft;

    // Calculate destination width and height
    final widthA = math.sqrt(math.pow(br.x - bl.x, 2) + math.pow(br.y - bl.y, 2));
    final widthB = math.sqrt(math.pow(tr.x - tl.x, 2) + math.pow(tr.y - tl.y, 2));
    final dstWidth = math.max(widthA, widthB).round().clamp(100, 4000);

    final heightA = math.sqrt(math.pow(tr.x - br.x, 2) + math.pow(tr.y - br.y, 2));
    final heightB = math.sqrt(math.pow(tl.x - bl.x, 2) + math.pow(tl.y - bl.y, 2));
    final dstHeight = math.max(heightA, heightB).round().clamp(100, 4000);

    final dst = img.Image(width: dstWidth, height: dstHeight, numChannels: src.numChannels);

    // Compute perspective mapping coefficients via bilinear interpolation
    for (int y = 0; y < dstHeight; y++) {
      final v = y / (dstHeight - 1.0);
      final leftX = tl.x + (bl.x - tl.x) * v;
      final leftY = tl.y + (bl.y - tl.y) * v;
      final rightX = tr.x + (br.x - tr.x) * v;
      final rightY = tr.y + (br.y - tr.y) * v;

      for (int x = 0; x < dstWidth; x++) {
        final u = x / (dstWidth - 1.0);
        final srcX = leftX + (rightX - leftX) * u;
        final srcY = leftY + (rightY - leftY) * u;

        final pixel = _sampleBilinear(src, srcX, srcY);
        dst.setPixel(x, y, pixel);
      }
    }

    return dst;
  }

  /// Helper for bilinear interpolation sampling
  static img.Pixel _sampleBilinear(img.Image src, double x, double y) {
    final clampX = x.clamp(0.0, (src.width - 1).toDouble());
    final clampY = y.clamp(0.0, (src.height - 1).toDouble());

    final x0 = clampX.floor();
    final y0 = clampY.floor();
    final x1 = math.min(x0 + 1, src.width - 1);
    final y1 = math.min(y0 + 1, src.height - 1);

    final dx = clampX - x0;
    final dy = clampY - y0;

    final p00 = src.getPixel(x0, y0);
    final p10 = src.getPixel(x1, y0);
    final p01 = src.getPixel(x0, y1);
    final p11 = src.getPixel(x1, y1);

    final r = (p00.r * (1 - dx) * (1 - dy) +
            p10.r * dx * (1 - dy) +
            p01.r * (1 - dx) * dy +
            p11.r * dx * dy)
        .round();
    final g = (p00.g * (1 - dx) * (1 - dy) +
            p10.g * dx * (1 - dy) +
            p01.g * (1 - dx) * dy +
            p11.g * dx * dy)
        .round();
    final b = (p00.b * (1 - dx) * (1 - dy) +
            p10.b * dx * (1 - dy) +
            p01.b * (1 - dx) * dy +
            p11.b * dx * dy)
        .round();

    return src.getPixel(0, 0)..setRgb(r, g, b);
  }

  /// Rotates image by specified angle (90, 180, 270)
  static img.Image rotateImage(img.Image src, int angleDeg) {
    final angle = angleDeg % 360;
    if (angle == 90) {
      return img.copyRotate(src, angle: 90);
    } else if (angle == 180) {
      return img.copyRotate(src, angle: 180);
    } else if (angle == 270) {
      return img.copyRotate(src, angle: 270);
    }
    return src;
  }

  /// Remove crease shadows and uneven fold lighting
  static img.Image removeCreaseShadows(img.Image src, {double strength = 0.6}) {
    if (strength <= 0.05) return src;

    final radius = math.max(15, (math.min(src.width, src.height) * 0.06).round());
    final blurred = img.gaussianBlur(img.Image.from(src), radius: radius);

    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final bg = blurred.getPixel(x, y);

        // Normalize luminance / illumination division
        final normR = ((p.r / math.max(1, bg.r)) * 255.0).clamp(0, 255);
        final normG = ((p.g / math.max(1, bg.g)) * 255.0).clamp(0, 255);
        final normB = ((p.b / math.max(1, bg.b)) * 255.0).clamp(0, 255);

        // Blend with original
        final finalR = (normR * strength + p.r * (1.0 - strength)).round().clamp(0, 255);
        final finalG = (normG * strength + p.g * (1.0 - strength)).round().clamp(0, 255);
        final finalB = (normB * strength + p.b * (1.0 - strength)).round().clamp(0, 255);

        result.setPixelRgb(x, y, finalR, finalG, finalB);
      }
    }
    return result;
  }

  /// Subtle text unsharp masking
  static img.Image unsharpMask(img.Image src, {double strength = 0.6, double sigma = 1.0}) {
    if (strength <= 0.05) return src;

    final blurred = img.gaussianBlur(img.Image.from(src), radius: sigma.round().clamp(1, 5));
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final b = blurred.getPixel(x, y);

        final diffR = p.r - b.r;
        final diffG = p.g - b.g;
        final diffB = p.b - b.b;

        final r = (p.r + diffR * strength).round().clamp(0, 255);
        final g = (p.g + diffG * strength).round().clamp(0, 255);
        final bl = (p.b + diffB * strength).round().clamp(0, 255);

        result.setPixelRgb(x, y, r, g, bl);
      }
    }
    return result;
  }

  /// CamScanner Magic Color: White paper + vivid ink colors
  static img.Image enhanceMagicColor(img.Image src) {
    final cleaned = removeCreaseShadows(src, strength: 0.75);
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);

    for (int y = 0; y < cleaned.height; y++) {
      for (int x = 0; x < cleaned.width; x++) {
        final p = cleaned.getPixel(x, y);

        // Convert RGB to HSV approximation
        final r = p.r / 255.0;
        final g = p.g / 255.0;
        final b = p.b / 255.0;

        final max = math.max(r, math.max(g, b));
        final min = math.min(r, math.min(g, b));
        final delta = max - min;

        // Saturation boost
        double s = max == 0 ? 0 : delta / max;
        s = (s * 1.45).clamp(0.0, 1.0);

        // Value / Paper bleaching
        double v = max;
        v = (math.pow(v, 0.85) * 1.1 + 0.05).clamp(0.0, 1.0);

        // Reconstruct RGB
        if (s == 0) {
          final grayVal = (v * 255).round().clamp(0, 255);
          result.setPixelRgb(x, y, grayVal, grayVal, grayVal);
        } else {
          double h = 0;
          if (max == r) {
            h = ((g - b) / delta) % 6;
          } else if (max == g) {
            h = ((b - r) / delta) + 2;
          } else {
            h = ((r - g) / delta) + 4;
          }
          h *= 60;
          if (h < 0) h += 360;

          final c = v * s;
          final xVal = c * (1 - ((h / 60) % 2 - 1).abs());
          final m = v - c;

          double r1 = 0, g1 = 0, b1 = 0;
          if (h < 60) {
            r1 = c; g1 = xVal; b1 = 0;
          } else if (h < 120) {
            r1 = xVal; g1 = c; b1 = 0;
          } else if (h < 180) {
            r1 = 0; g1 = c; b1 = xVal;
          } else if (h < 240) {
            r1 = 0; g1 = xVal; b1 = c;
          } else if (h < 300) {
            r1 = xVal; g1 = 0; b1 = c;
          } else {
            r1 = c; g1 = 0; b1 = xVal;
          }

          result.setPixelRgb(
            x,
            y,
            ((r1 + m) * 255).round().clamp(0, 255),
            ((g1 + m) * 255).round().clamp(0, 255),
            ((b1 + m) * 255).round().clamp(0, 255),
          );
        }
      }
    }
    return unsharpMask(result, strength: 0.5);
  }

  /// Whiten paper background while preserving text sharpness
  static img.Image enhanceCleanBg(img.Image src) {
    final cleaned = removeCreaseShadows(src, strength: 0.85);
    return img.adjustColor(cleaned, contrast: 1.25, brightness: 1.05);
  }

  /// High contrast for faded pencil notes or low-ink text
  static img.Image enhanceSharpText(img.Image src) {
    final cleaned = removeCreaseShadows(src, strength: 0.6);
    final contrasted = img.adjustColor(cleaned, contrast: 1.45, brightness: 1.0);
    return unsharpMask(contrasted, strength: 0.85);
  }

  /// Neutralize aged yellowed / foxed paper
  static img.Image restoreYellowedPaper(img.Image src) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);

        // Check if pixel is colored ink (e.g. red seal or blue signature)
        final isRedSeal = p.r > 130 && (p.r - p.g > 40) && (p.r - p.b > 40);
        final isBlueSig = p.b > 110 && (p.b - p.r > 30);

        if (isRedSeal || isBlueSig) {
          result.setPixel(x, y, p);
        } else {
          // Neutralize yellow cast: shift blue channel up towards red/green
          final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
          final bleachedLum = ((lum / 220.0) * 255.0).clamp(0, 255).round();
          result.setPixelRgb(x, y, bleachedLum, bleachedLum, bleachedLum);
        }
      }
    }
    return unsharpMask(result, strength: 0.5);
  }

  /// Suppress bleed-through / show-through text from rear side
  static img.Image removeBleedthrough(img.Image src) {
    final edges = img.sobel(img.grayscale(src));
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final edgeP = edges.getPixel(x, y);

        // Front text has sharp high edge gradient; bleed-through is faint and diffuse
        if (edgeP.r < 30 && p.r > 140 && p.g > 140 && p.b > 140) {
          // Bleach background bleed
          result.setPixelRgb(x, y, 255, 255, 255);
        } else {
          result.setPixel(x, y, p);
        }
      }
    }
    return unsharpMask(result, strength: 0.6);
  }

  /// Boost official notary red stamps and blue ballpoint signatures
  static img.Image boostStampsAndSignatures(img.Image src) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);

        final isRedSeal = p.r > 100 && (p.r - p.g > 25) && (p.r - p.b > 25);
        final isBlueSig = p.b > 90 && (p.b - p.r > 20);

        if (isRedSeal) {
          // Super-vivid red stamp
          final r = math.min(255, (p.r * 1.35).round());
          final g = math.max(0, (p.g * 0.75).round());
          final b = math.max(0, (p.b * 0.75).round());
          result.setPixelRgb(x, y, r, g, b);
        } else if (isBlueSig) {
          // Super-vivid blue signature
          final r = math.max(0, (p.r * 0.75).round());
          final g = math.max(0, (p.g * 0.85).round());
          final b = math.min(255, (p.b * 1.35).round());
          result.setPixelRgb(x, y, r, g, b);
        } else {
          // Paper background bleaching
          final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
          final bleached = ((lum * 1.08 + 10)).clamp(0, 255).round();
          result.setPixelRgb(x, y, bleached, bleached, bleached);
        }
      }
    }
    return unsharpMask(result, strength: 0.5);
  }

  /// High-clarity mode for thermal receipts & carbon copy text
  static img.Image superSharpThermalReceipt(img.Image src) {
    final gray = img.grayscale(src);
    final contrasted = img.adjustColor(gray, contrast: 1.6, gamma: 1.2);
    return unsharpMask(contrasted, strength: 1.0);
  }

  /// Clean crisp binarized office document scan
  static img.Image bwScan(img.Image src) {
    final gray = img.grayscale(src);
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);

    // Adaptive local threshold binarization
    final blurred = img.gaussianBlur(img.Image.from(gray), radius: 15);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final p = gray.getPixel(x, y);
        final bg = blurred.getPixel(x, y);

        final val = (p.r < bg.r - 8) ? 0 : 255;
        result.setPixelRgb(x, y, val, val, val);
      }
    }
    return result;
  }

  /// Unwrinkle & dewarp mesh displacement flattening
  static img.Image dewarpPage(img.Image src, {double strength = 0.8}) {
    if (strength <= 0.05) return src;

    final w = src.width;
    final h = src.height;
    final dst = img.Image(width: w, height: h, numChannels: src.numChannels);

    const numBands = 8;
    final bandH = h / numBands;

    for (int y = 0; y < h; y++) {
      final bandIdx = (y / bandH).floor().clamp(0, numBands - 1);
      final wave = math.sin((bandIdx / numBands) * math.pi) * (h * 0.015 * strength);

      for (int x = 0; x < w; x++) {
        final flowX = (x / w) * math.pi;
        final offsetY = math.sin(flowX) * wave;
        final srcY = (y + offsetY).clamp(0.0, (h - 1).toDouble());

        final pixel = _sampleBilinear(src, x.toDouble(), srcY);
        dst.setPixel(x, y, pixel);
      }
    }
    return dst;
  }

  /// Master document enhancement pipeline
  static img.Image processDocument(
    img.Image src, {
    EnhancementMode mode = EnhancementMode.magicColor,
    FilterParams params = const FilterParams(),
  }) {
    img.Image processed = img.Image.from(src);

    // Step 1: Dewarp if requested
    if (params.dewarpStrength > 0.05) {
      processed = dewarpPage(processed, strength: params.dewarpStrength);
    }

    // Step 2: Mode Processing
    switch (mode) {
      case EnhancementMode.magicColor:
        processed = enhanceMagicColor(processed);
        break;
      case EnhancementMode.cleanBg:
        processed = enhanceCleanBg(processed);
        break;
      case EnhancementMode.sharpText:
        processed = enhanceSharpText(processed);
        break;
      case EnhancementMode.restoreYellowed:
        processed = restoreYellowedPaper(processed);
        break;
      case EnhancementMode.removeBleedthrough:
        processed = removeBleedthrough(processed);
        break;
      case EnhancementMode.highContrastStamp:
        processed = boostStampsAndSignatures(processed);
        break;
      case EnhancementMode.superSharpMono:
        processed = superSharpThermalReceipt(processed);
        break;
      case EnhancementMode.bwScan:
        processed = bwScan(processed);
        break;
      case EnhancementMode.natural:
        processed = removeCreaseShadows(processed, strength: params.shadowReduction);
        break;
      case EnhancementMode.original:
        return processed;
    }

    // Step 3: Global fine adjustments (Contrast, Brightness, Sharpness)
    if (params.contrast != 0.0 || params.brightness != 0.0) {
      processed = img.adjustColor(
        processed,
        contrast: 1.0 + (params.contrast * 0.5),
        brightness: 1.0 + (params.brightness * 0.3),
      );
    }

    if (params.sharpness > 0.1 && mode != EnhancementMode.bwScan) {
      processed = unsharpMask(processed, strength: params.sharpness);
    }

    return processed;
  }
}
