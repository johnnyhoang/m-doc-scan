import 'dart:math' as math;

/// 2D coordinate point representing normalized or pixel positions
class Point2D {
  final double x;
  final double y;

  const Point2D(this.x, this.y);

  Point2D copyWith({double? x, double? y}) {
    return Point2D(x ?? this.x, y ?? this.y);
  }

  double distanceTo(Point2D other) {
    return math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory Point2D.fromJson(Map<String, dynamic> json) {
    return Point2D(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'Point2D(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// Quadrilateral corner coordinates for document detection & perspective transform
class QuadCorners {
  final Point2D topLeft;
  final Point2D topRight;
  final Point2D bottomRight;
  final Point2D bottomLeft;

  const QuadCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  List<Point2D> toList() => [topLeft, topRight, bottomRight, bottomLeft];

  factory QuadCorners.fromList(List<Point2D> pts) {
    if (pts.length != 4) {
      throw ArgumentError('QuadCorners requires exactly 4 points');
    }
    return QuadCorners(
      topLeft: pts[0],
      topRight: pts[1],
      bottomRight: pts[2],
      bottomLeft: pts[3],
    );
  }

  factory QuadCorners.defaultForSize(double width, double height, {double insetPercent = 0.05}) {
    final insetX = width * insetPercent;
    final insetY = height * insetPercent;
    return QuadCorners(
      topLeft: Point2D(insetX, insetY),
      topRight: Point2D(width - insetX, insetY),
      bottomRight: Point2D(width - insetX, height - insetY),
      bottomLeft: Point2D(insetX, height - insetY),
    );
  }

  QuadCorners copyWith({
    Point2D? topLeft,
    Point2D? topRight,
    Point2D? bottomRight,
    Point2D? bottomLeft,
  }) {
    return QuadCorners(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomRight: bottomRight ?? this.bottomRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
    );
  }

  /// Expand quadrilateral outward from centroid by margin percentage
  QuadCorners expand(double marginPercent, double imageWidth, double imageHeight) {
    final pts = toList();
    final centerX = (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4.0;
    final centerY = (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4.0;
    final scale = 1.0 + (marginPercent * 2.0);

    final expanded = pts.map((pt) {
      final vx = pt.x - centerX;
      final vy = pt.y - centerY;
      final ex = centerX + vx * scale;
      final ey = centerY + vy * scale;
      return Point2D(
        ex.clamp(-imageWidth * 0.2, imageWidth * 1.2),
        ey.clamp(-imageHeight * 0.2, imageHeight * 1.2),
      );
    }).toList();

    return QuadCorners.fromList(expanded);
  }

  Map<String, dynamic> toJson() => {
        'topLeft': topLeft.toJson(),
        'topRight': topRight.toJson(),
        'bottomRight': bottomRight.toJson(),
        'bottomLeft': bottomLeft.toJson(),
      };

  factory QuadCorners.fromJson(Map<String, dynamic> json) {
    return QuadCorners(
      topLeft: Point2D.fromJson(json['topLeft'] as Map<String, dynamic>),
      topRight: Point2D.fromJson(json['topRight'] as Map<String, dynamic>),
      bottomRight: Point2D.fromJson(json['bottomRight'] as Map<String, dynamic>),
      bottomLeft: Point2D.fromJson(json['bottomLeft'] as Map<String, dynamic>),
    );
  }
}

/// Document Enhancement Modes matching core desktop pipeline
enum EnhancementMode {
  natural,
  magicColor,
  cleanBg,
  sharpText,
  restoreYellowed,
  removeBleedthrough,
  highContrastStamp,
  superSharpMono,
  bwScan,
  original;

  String get displayName {
    switch (this) {
      case EnhancementMode.magicColor:
        return 'Magic Color';
      case EnhancementMode.cleanBg:
        return 'Clean White BG';
      case EnhancementMode.sharpText:
        return 'Sharp Text';
      case EnhancementMode.restoreYellowed:
        return 'Restore Aged Paper';
      case EnhancementMode.removeBleedthrough:
        return 'Remove Bleed-through';
      case EnhancementMode.highContrastStamp:
        return 'Vivid Seal & Signature';
      case EnhancementMode.superSharpMono:
        return 'Thermal Receipt / POS';
      case EnhancementMode.bwScan:
        return 'B&W Scan';
      case EnhancementMode.natural:
        return 'Natural Balanced';
      case EnhancementMode.original:
        return 'Original';
    }
  }

  String get description {
    switch (this) {
      case EnhancementMode.magicColor:
        return 'Pure white paper with vibrant stamps and colored ink strokes';
      case EnhancementMode.cleanBg:
        return 'Eliminates shadows and uneven yellow lighting across paper';
      case EnhancementMode.sharpText:
        return 'High contrast enhancement for faint pencil or low-ink text';
      case EnhancementMode.restoreYellowed:
        return 'Neutralizes yellow/brown foxing stains on archival documents';
      case EnhancementMode.removeBleedthrough:
        return 'Suppresses double-sided ghost text bleeding through thin pages';
      case EnhancementMode.highContrastStamp:
        return 'Accentuates official red notary seals & blue ink signatures';
      case EnhancementMode.superSharpMono:
        return 'High-clarity mode for thermal receipts and carbon copies';
      case EnhancementMode.bwScan:
        return 'Crisp binarized black & white office document scan';
      case EnhancementMode.natural:
        return 'Balanced true-to-life colors and clean contrast';
      case EnhancementMode.original:
        return 'Direct crop without color transformations';
    }
  }
}

/// Fine-tuning filter parameters
class FilterParams {
  final double shadowReduction; // 0.0 -> 1.0
  final double sharpness;       // 0.0 -> 1.0
  final double contrast;        // 0.0 -> 1.0
  final double brightness;      // -1.0 -> 1.0
  final double dewarpStrength;  // 0.0 -> 1.0

  const FilterParams({
    this.shadowReduction = 0.6,
    this.sharpness = 0.6,
    this.contrast = 0.2,
    this.brightness = 0.0,
    this.dewarpStrength = 0.0,
  });

  FilterParams copyWith({
    double? shadowReduction,
    double? sharpness,
    double? contrast,
    double? brightness,
    double? dewarpStrength,
  }) {
    return FilterParams(
      shadowReduction: shadowReduction ?? this.shadowReduction,
      sharpness: sharpness ?? this.sharpness,
      contrast: contrast ?? this.contrast,
      brightness: brightness ?? this.brightness,
      dewarpStrength: dewarpStrength ?? this.dewarpStrength,
    );
  }

  Map<String, dynamic> toJson() => {
        'shadowReduction': shadowReduction,
        'sharpness': sharpness,
        'contrast': contrast,
        'brightness': brightness,
        'dewarpStrength': dewarpStrength,
      };

  factory FilterParams.fromJson(Map<String, dynamic> json) {
    return FilterParams(
      shadowReduction: (json['shadowReduction'] as num?)?.toDouble() ?? 0.6,
      sharpness: (json['sharpness'] as num?)?.toDouble() ?? 0.6,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 0.2,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
      dewarpStrength: (json['dewarpStrength'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Model representing a single page in a document
class DocumentPage {
  final String id;
  final int pageNumber;
  final String originalImagePath;
  final String? croppedImagePath;
  final String? enhancedImagePath;
  final QuadCorners? corners;
  final int rotationAngle; // 0, 90, 180, 270
  final EnhancementMode enhancementMode;
  final FilterParams filterParams;
  final DateTime createdAt;

  DocumentPage({
    required this.id,
    required this.pageNumber,
    required this.originalImagePath,
    this.croppedImagePath,
    this.enhancedImagePath,
    this.corners,
    this.rotationAngle = 0,
    this.enhancementMode = EnhancementMode.magicColor,
    this.filterParams = const FilterParams(),
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayPath => enhancedImagePath ?? croppedImagePath ?? originalImagePath;

  DocumentPage copyWith({
    String? id,
    int? pageNumber,
    String? originalImagePath,
    String? croppedImagePath,
    String? enhancedImagePath,
    QuadCorners? corners,
    int? rotationAngle,
    EnhancementMode? enhancementMode,
    FilterParams? filterParams,
    DateTime? createdAt,
  }) {
    return DocumentPage(
      id: id ?? this.id,
      pageNumber: pageNumber ?? this.pageNumber,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      croppedImagePath: croppedImagePath ?? this.croppedImagePath,
      enhancedImagePath: enhancedImagePath ?? this.enhancedImagePath,
      corners: corners ?? this.corners,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      enhancementMode: enhancementMode ?? this.enhancementMode,
      filterParams: filterParams ?? this.filterParams,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pageNumber': pageNumber,
        'originalImagePath': originalImagePath,
        'croppedImagePath': croppedImagePath,
        'enhancedImagePath': enhancedImagePath,
        'corners': corners?.toJson(),
        'rotationAngle': rotationAngle,
        'enhancementMode': enhancementMode.name,
        'filterParams': filterParams.toJson(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory DocumentPage.fromJson(Map<String, dynamic> json) {
    return DocumentPage(
      id: json['id'] as String,
      pageNumber: json['pageNumber'] as int,
      originalImagePath: json['originalImagePath'] as String,
      croppedImagePath: json['croppedImagePath'] as String?,
      enhancedImagePath: json['enhancedImagePath'] as String?,
      corners: json['corners'] != null ? QuadCorners.fromJson(json['corners'] as Map<String, dynamic>) : null,
      rotationAngle: json['rotationAngle'] as int? ?? 0,
      enhancementMode: EnhancementMode.values.firstWhere(
        (e) => e.name == json['enhancementMode'],
        orElse: () => EnhancementMode.magicColor,
      ),
      filterParams: json['filterParams'] != null
          ? FilterParams.fromJson(json['filterParams'] as Map<String, dynamic>)
          : const FilterParams(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Model representing a multi-page scanned document item
class DocumentItem {
  final String id;
  final String name;
  final List<DocumentPage> pages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> suggestedNames;

  DocumentItem({
    required this.id,
    required this.name,
    required this.pages,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.suggestedNames = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get pageCount => pages.length;
  String? get thumbnailPath => pages.isNotEmpty ? pages.first.displayPath : null;

  DocumentItem copyWith({
    String? id,
    String? name,
    List<DocumentPage>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? suggestedNames,
  }) {
    return DocumentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      pages: pages ?? this.pages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      suggestedNames: suggestedNames ?? this.suggestedNames,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pages': pages.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'suggestedNames': suggestedNames,
      };

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: json['id'] as String,
      name: json['name'] as String,
      pages: (json['pages'] as List<dynamic>)
          .map((p) => DocumentPage.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      suggestedNames: (json['suggestedNames'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
