import 'dart:math';

import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../detect/yolo_decoder.dart';

class YoloService {
  Interpreter? _interpreter;
  var _size = 320;
  var _floatInput = true;
  List<int> _outShape = const [1, 84, 2100];
  Object? _input;
  Object? _output;

  Future<bool> load() async {
    try {
      final interpreter = await Interpreter.fromAsset('assets/models/yolo11n.tflite');
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      _size = inputTensor.shape.length >= 3 ? inputTensor.shape[1] : 320;
      _floatInput = inputTensor.type == TensorType.float32;
      _outShape = outputTensor.shape;
      _input = _blank(_floatInput, [1, _size, _size, 3]);
      _output = _blank(outputTensor.type == TensorType.float32, _outShape);
      _interpreter = interpreter;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get isReady => _interpreter != null;

  void close() { _interpreter?.close(); }

  List<Detection> detect(CameraImage image) {
    final interpreter = _interpreter;
    final input = _input;
    final output = _output;
    if (interpreter == null || input == null || output == null) { return const []; }
    _fillInput(image, input);
    interpreter.run(input, output);
    final flat = <double>[];
    _flatten(output, flat);
    return decodeYolo(flat, _outShape, inputSize: _size.toDouble());
  }

  void _fillInput(CameraImage image, Object input) {
    final plane = input as List;
    final rows = plane[0] as List;
    final size = _size;
    final srcW = image.width;
    final srcH = image.height;
    final scale = min(size / srcW, size / srcH);
    final fittedW = max(1, (srcW * scale).round());
    final fittedH = max(1, (srcH * scale).round());
    final padX = (size - fittedW) ~/ 2;
    final padY = (size - fittedH) ~/ 2;
    for (var y = 0; y < size; y++) {
      final row = rows[y] as List;
      for (var x = 0; x < size; x++) {
        final cell = row[x] as List;
        if (x < padX || y < padY || x >= padX + fittedW || y >= padY + fittedH) {
          _paint(cell, 114, 114, 114);
          continue;
        }
        final sx = ((x - padX) * srcW / fittedW).floor().clamp(0, srcW - 1);
        final sy = ((y - padY) * srcH / fittedH).floor().clamp(0, srcH - 1);
        final rgb = _sample(image, sx, sy);
        _paint(cell, (rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
      }
    }
  }

  void _paint(List cell, int red, int green, int blue) {
    if (_floatInput) {
      cell[0] = red / 255;
      cell[1] = green / 255;
      cell[2] = blue / 255;
      return;
    }
    cell[0] = red;
    cell[1] = green;
    cell[2] = blue;
  }

  int _sample(CameraImage image, int x, int y) {
    if (image.planes.length >= 3) { return _yuv(image, x, y); }
    return _bgra(image, x, y);
  }

  int _bgra(CameraImage image, int x, int y) {
    final plane = image.planes[0];
    final index = y * plane.bytesPerRow + x * 4;
    if (index + 2 >= plane.bytes.length) { return 0x727272; }
    final blue = plane.bytes[index];
    final green = plane.bytes[index + 1];
    final red = plane.bytes[index + 2];
    return (red << 16) | (green << 8) | blue;
  }

  int _yuv(CameraImage image, int x, int y) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yIndex = y * yPlane.bytesPerRow + x * (yPlane.bytesPerPixel ?? 1);
    final uvX = x ~/ 2;
    final uvY = y ~/ 2;
    final uIndex = uvY * uPlane.bytesPerRow + uvX * (uPlane.bytesPerPixel ?? 1);
    final vIndex = uvY * vPlane.bytesPerRow + uvX * (vPlane.bytesPerPixel ?? 1);
    if (yIndex >= yPlane.bytes.length || uIndex >= uPlane.bytes.length || vIndex >= vPlane.bytes.length) {
      return 0x727272;
    }
    final yp = yPlane.bytes[yIndex];
    final up = uPlane.bytes[uIndex];
    final vp = vPlane.bytes[vIndex];
    final red = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
    final green = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round().clamp(0, 255);
    final blue = (yp + 1.772 * (up - 128)).round().clamp(0, 255);
    return (red << 16) | (green << 8) | blue;
  }
}

Object _blank(bool asFloat, List<int> shape) {
  Object build(int axis) {
    final length = shape[axis];
    if (axis == shape.length - 1) {
      if (asFloat) { return List<double>.filled(length, 0); }
      return List<int>.filled(length, 0);
    }
    return List.generate(length, (_) => build(axis + 1));
  }
  return build(0);
}

void _flatten(Object node, List<double> into) {
  if (node is List) {
    for (final child in node) { _flatten(child, into); }
    return;
  }
  if (node is num) { into.add(node.toDouble()); }
}
