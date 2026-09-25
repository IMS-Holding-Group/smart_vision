import 'coco_labels.dart';

class Detection {
  final String label;
  final double score;
  final double area;

  const Detection({required this.label, required this.score, required this.area});
}

class _Box {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double score;
  final int classId;

  const _Box(this.x1, this.y1, this.x2, this.y2, this.score, this.classId);
}

List<Detection> decodeYolo(List<double> data, List<int> shape, {double minScore = 0.45, double inputSize = 320}) {
  final boxes = _readBoxes(data, shape, minScore, inputSize);
  boxes.sort((a, b) => b.score.compareTo(a.score));
  final kept = <_Box>[];
  for (final box in boxes) {
    var overlap = false;
    for (final other in kept) {
      if (_iou(box, other) > 0.5) { overlap = true; }
    }
    if (!overlap && kept.length < 5) { kept.add(box); }
  }
  return [
    for (final box in kept)
      Detection(
        label: cocoLabelsAr[box.classId],
        score: box.score,
        area: ((box.x2 - box.x1) * (box.y2 - box.y1)).clamp(0, 1),
      ),
  ];
}

List<_Box> _readBoxes(List<double> data, List<int> shape, double minScore, double inputSize) {
  if (shape.length != 3 || shape[0] != 1) { return const []; }
  final mid = shape[1];
  final last = shape[2];
  if (last == 6 && mid != 84) { return _readEndToEnd(data, mid, minScore, inputSize); }
  if (mid == 84) { return _readChannelsFirst(data, last, minScore, inputSize); }
  if (last == 84) { return _readChannelsLast(data, mid, minScore, inputSize); }
  return const [];
}

List<_Box> _readEndToEnd(List<double> data, int count, double minScore, double inputSize) {
  final boxes = <_Box>[];
  for (var i = 0; i < count; i++) {
    final base = i * 6;
    if (base + 5 >= data.length) { break; }
    final score = data[base + 4];
    final classId = data[base + 5].round();
    if (score < minScore || classId < 0 || classId >= cocoLabelsAr.length) { continue; }
    boxes.add(_boxFromCorners(data[base], data[base + 1], data[base + 2], data[base + 3], score, classId, inputSize));
  }
  return boxes;
}

List<_Box> _readChannelsFirst(List<double> data, int count, double minScore, double inputSize) {
  final boxes = <_Box>[];
  for (var i = 0; i < count; i++) {
    final cx = data[i];
    final cy = data[count + i];
    final w = data[2 * count + i];
    final h = data[3 * count + i];
    var best = 0.0;
    var classId = -1;
    for (var c = 0; c < 80; c++) {
      final score = data[(4 + c) * count + i];
      if (score > best) {
        best = score;
        classId = c;
      }
    }
    if (best < minScore || classId < 0) { continue; }
    boxes.add(_boxFromCenter(cx, cy, w, h, best, classId, inputSize));
  }
  return boxes;
}

List<_Box> _readChannelsLast(List<double> data, int count, double minScore, double inputSize) {
  final boxes = <_Box>[];
  for (var i = 0; i < count; i++) {
    final base = i * 84;
    if (base + 83 >= data.length) { break; }
    var best = 0.0;
    var classId = -1;
    for (var c = 0; c < 80; c++) {
      final score = data[base + 4 + c];
      if (score > best) {
        best = score;
        classId = c;
      }
    }
    if (best < minScore) { continue; }
    boxes.add(_boxFromCenter(data[base], data[base + 1], data[base + 2], data[base + 3], best, classId, inputSize));
  }
  return boxes;
}

_Box _boxFromCorners(double x1, double y1, double x2, double y2, double score, int classId, double inputSize) {
  final left = _norm(x1, inputSize);
  final top = _norm(y1, inputSize);
  final right = _norm(x2, inputSize);
  final bottom = _norm(y2, inputSize);
  return _Box(left, top, right, bottom, score, classId);
}

_Box _boxFromCenter(double cx, double cy, double w, double h, double score, int classId, double inputSize) {
  final nx = _norm(cx, inputSize);
  final ny = _norm(cy, inputSize);
  final nw = _norm(w, inputSize);
  final nh = _norm(h, inputSize);
  return _Box(nx - nw / 2, ny - nh / 2, nx + nw / 2, ny + nh / 2, score, classId);
}

double _norm(double value, double inputSize) {
  if (value > 1.5) { return value / inputSize; }
  return value;
}

double _iou(_Box a, _Box b) {
  final left = a.x1 > b.x1 ? a.x1 : b.x1;
  final top = a.y1 > b.y1 ? a.y1 : b.y1;
  final right = a.x2 < b.x2 ? a.x2 : b.x2;
  final bottom = a.y2 < b.y2 ? a.y2 : b.y2;
  final width = right - left;
  final height = bottom - top;
  if (width <= 0 || height <= 0) { return 0; }
  final inter = width * height;
  final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
  final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
  final union = areaA + areaB - inter;
  if (union <= 0) { return 0; }
  return inter / union;
}
