class DetectedObject {
  final String name;
  final double score;
  final BoundingBox boundingBox;

  DetectedObject({
    required this.name,
    required this.score,
    required this.boundingBox,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      name: json['name'] as String,
      score: (json['score'] as num).toDouble(),
      boundingBox: BoundingBox.fromJson(json['boundingPoly'] as Map<String, dynamic>),
    );
  }
}

class BoundingBox {
  final List<Vertex> vertices;

  BoundingBox({required this.vertices});

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    final normalizedVertices = json['normalizedVertices'] as List?;
    
    if (normalizedVertices != null) {
      return BoundingBox(
        vertices: normalizedVertices
            .map((v) => Vertex.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
    }
    
    // Fallback to regular vertices if normalized not available
    final vertices = json['vertices'] as List;
    return BoundingBox(
      vertices: vertices
          .map((v) => Vertex.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  // 中心座標を取得
  Vertex get center {
    double sumX = 0;
    double sumY = 0;
    for (var vertex in vertices) {
      sumX += vertex.x;
      sumY += vertex.y;
    }
    return Vertex(x: sumX / vertices.length, y: sumY / vertices.length);
  }

  // 幅と高さを取得
  double get width {
    if (vertices.length < 2) return 0;
    return (vertices[1].x - vertices[0].x).abs();
  }

  double get height {
    if (vertices.length < 3) return 0;
    return (vertices[2].y - vertices[0].y).abs();
  }
}

class Vertex {
  final double x;
  final double y;

  Vertex({required this.x, required this.y});

  factory Vertex.fromJson(Map<String, dynamic> json) {
    return Vertex(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

