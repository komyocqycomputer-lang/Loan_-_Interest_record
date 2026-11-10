import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum _CropDragHandle {
  none,
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class ImageCropScreen extends StatefulWidget {
  final File imageFile;
  final double aspectRatio;

  const ImageCropScreen({
    super.key,
    required this.imageFile,
    this.aspectRatio = 92.0 / 122.0,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  ui.Image? _uiImage;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  int _quarterTurns = 0;

  // Geometry state
  Rect? _imageRect;
  Rect? _cropRect;
  Size? _lastViewportSize;
  int _lastQuarterTurns = 0;

  // Drag & scale state
  _CropDragHandle _activeHandle = _CropDragHandle.none;
  Rect? _startCropRect;
  Offset? _startFocalPoint;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _uiImage = frame.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _uiImage?.dispose();
    super.dispose();
  }

  void _rotateClockwise() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  Rect _computeInitialCropRect(Rect imageRect) {
    final double ratio = widget.aspectRatio;

    double cropW;
    double cropH;

    if (imageRect.width / imageRect.height > ratio) {
      cropH = imageRect.height * 0.82;
      cropW = cropH * ratio;
    } else {
      cropW = imageRect.width * 0.82;
      cropH = cropW / ratio;
    }

    if (cropW > imageRect.width) {
      cropW = imageRect.width;
      cropH = cropW / ratio;
    }
    if (cropH > imageRect.height) {
      cropH = imageRect.height;
      cropW = cropH * ratio;
    }

    final double cropLeft = imageRect.left + (imageRect.width - cropW) / 2;
    final double cropTop = imageRect.top + (imageRect.height - cropH) / 2;

    return Rect.fromLTWH(cropLeft, cropTop, cropW, cropH);
  }

  _CropDragHandle _hitTest(Offset pos, Rect crop) {
    const double cornerHitRadius = 38.0;

    // Corners have highest priority
    if ((pos - crop.topLeft).distance <= cornerHitRadius) {
      return _CropDragHandle.topLeft;
    }
    if ((pos - crop.topRight).distance <= cornerHitRadius) {
      return _CropDragHandle.topRight;
    }
    if ((pos - crop.bottomLeft).distance <= cornerHitRadius) {
      return _CropDragHandle.bottomLeft;
    }
    if ((pos - crop.bottomRight).distance <= cornerHitRadius) {
      return _CropDragHandle.bottomRight;
    }

    // Inside crop box -> Move whole box
    if (crop.contains(pos)) {
      return _CropDragHandle.move;
    }

    return _CropDragHandle.none;
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_cropRect == null || _imageRect == null) return;
    _startFocalPoint = details.localFocalPoint;
    _startCropRect = _cropRect;
    _activeHandle = _hitTest(details.localFocalPoint, _cropRect!);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_startCropRect == null || _imageRect == null) return;

    final double ratio = widget.aspectRatio;
    final Rect s = _startCropRect!;
    final Rect img = _imageRect!;
    const double minH = 50.0;
    const double minW = 50.0;

    // 1. Pinch to scale with 2 fingers
    if (details.pointerCount >= 2) {
      double newW = s.width * details.scale;
      final double maxAllowedW = math.min(img.width, img.height * ratio);
      newW = newW.clamp(minW, maxAllowedW);
      final double newH = newW / ratio;

      final Offset newCenter = s.center + details.focalPointDelta;
      double newLeft = newCenter.dx - newW / 2;
      double newTop = newCenter.dy - newH / 2;

      newLeft = newLeft.clamp(img.left, img.right - newW);
      newTop = newTop.clamp(img.top, img.bottom - newH);

      setState(() {
        _cropRect = Rect.fromLTWH(newLeft, newTop, newW, newH);
      });
      return;
    }

    // 2. Single finger actions
    if (_activeHandle == _CropDragHandle.move && _startFocalPoint != null) {
      final Offset delta = details.localFocalPoint - _startFocalPoint!;
      double newLeft = s.left + delta.dx;
      double newTop = s.top + delta.dy;

      newLeft = newLeft.clamp(img.left, img.right - s.width);
      newTop = newTop.clamp(img.top, img.bottom - s.height);

      setState(() {
        _cropRect = Rect.fromLTWH(newLeft, newTop, s.width, s.height);
      });
      return;
    }

    final Offset pos = details.localFocalPoint;

    // Locked aspect ratio corner resizing
    switch (_activeHandle) {
      case _CropDragHandle.bottomRight:
        final double ax = s.left;
        final double ay = s.top;
        final double vx = pos.dx - ax;
        final double vy = pos.dy - ay;
        final double projH = (vx * ratio + vy) / (ratio * ratio + 1);
        final double maxH = math.min(img.bottom - ay, (img.right - ax) / ratio);
        final double finalH = projH.clamp(minH, math.max(minH, maxH));
        final double finalW = finalH * ratio;
        setState(() {
          _cropRect = Rect.fromLTWH(ax, ay, finalW, finalH);
        });
        break;

      case _CropDragHandle.bottomLeft:
        final double ax = s.right;
        final double ay = s.top;
        final double vx = ax - pos.dx;
        final double vy = pos.dy - ay;
        final double projH = (vx * ratio + vy) / (ratio * ratio + 1);
        final double maxH = math.min(img.bottom - ay, (ax - img.left) / ratio);
        final double finalH = projH.clamp(minH, math.max(minH, maxH));
        final double finalW = finalH * ratio;
        setState(() {
          _cropRect = Rect.fromLTWH(ax - finalW, ay, finalW, finalH);
        });
        break;

      case _CropDragHandle.topRight:
        final double ax = s.left;
        final double ay = s.bottom;
        final double vx = pos.dx - ax;
        final double vy = ay - pos.dy;
        final double projH = (vx * ratio + vy) / (ratio * ratio + 1);
        final double maxH = math.min(ay - img.top, (img.right - ax) / ratio);
        final double finalH = projH.clamp(minH, math.max(minH, maxH));
        final double finalW = finalH * ratio;
        setState(() {
          _cropRect = Rect.fromLTWH(ax, ay - finalH, finalW, finalH);
        });
        break;

      case _CropDragHandle.topLeft:
        final double ax = s.right;
        final double ay = s.bottom;
        final double vx = ax - pos.dx;
        final double vy = ay - pos.dy;
        final double projH = (vx * ratio + vy) / (ratio * ratio + 1);
        final double maxH = math.min(ay - img.top, (ax - img.left) / ratio);
        final double finalH = projH.clamp(minH, math.max(minH, maxH));
        final double finalW = finalH * ratio;
        setState(() {
          _cropRect = Rect.fromLTWH(ax - finalW, ay - finalH, finalW, finalH);
        });
        break;

      default:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _activeHandle = _CropDragHandle.none;
    _startCropRect = null;
    _startFocalPoint = null;
  }

  Future<void> _cropAndConfirm() async {
    if (_isProcessing ||
        _uiImage == null ||
        _imageRect == null ||
        _cropRect == null) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final double normLeft =
          ((_cropRect!.left - _imageRect!.left) / _imageRect!.width).clamp(
            0.0,
            1.0,
          );
      final double normTop =
          ((_cropRect!.top - _imageRect!.top) / _imageRect!.height).clamp(
            0.0,
            1.0,
          );
      final double normWidth = (_cropRect!.width / _imageRect!.width).clamp(
        0.0,
        1.0 - normLeft,
      );
      final double normHeight = (_cropRect!.height / _imageRect!.height).clamp(
        0.0,
        1.0 - normTop,
      );

      final bool isRotated = (_quarterTurns % 2 == 1);
      final double fullW = isRotated
          ? _uiImage!.height.toDouble()
          : _uiImage!.width.toDouble();
      final double fullH = isRotated
          ? _uiImage!.width.toDouble()
          : _uiImage!.height.toDouble();

      final double srcX = normLeft * fullW;
      final double srcY = normTop * fullH;
      final double srcW = normWidth * fullW;
      final double srcH = normHeight * fullH;

      // Target output size: maintain high resolution matching Home Screen camera box scale (92:122)
      final int outW = srcW.round().clamp(368, 1840);
      final int outH = (outW / widget.aspectRatio).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Crop from (srcX, srcY, srcW, srcH) of the rotated image into (0, 0, outW, outH)
      canvas.save();
      final double scaleX = outW / srcW;
      final double scaleY = outH / srcH;
      canvas.scale(scaleX, scaleY);
      canvas.translate(-srcX, -srcY);

      if (_quarterTurns == 1) {
        canvas.translate(fullW, 0);
        canvas.rotate(math.pi / 2);
      } else if (_quarterTurns == 2) {
        canvas.translate(fullW, fullH);
        canvas.rotate(math.pi);
      } else if (_quarterTurns == 3) {
        canvas.translate(0, fullH);
        canvas.rotate(3 * math.pi / 2);
      }

      canvas.drawImage(
        _uiImage!,
        Offset.zero,
        Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.restore();

      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(outW, outH);
      final byteData = await croppedUiImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Failed to generate cropped image data');
      }

      final bytes = byteData.buffer.asUint8List();
      final photosDir = Directory(
        '${Directory.systemTemp.parent.path}/files/loan_photos',
      );
      if (!photosDir.existsSync()) {
        await photosDir.create(recursive: true);
      }
      final fileName = 'crop_${DateTime.now().millisecondsSinceEpoch}.png';
      final croppedFile = File('${photosDir.path}/$fileName');
      await croppedFile.writeAsBytes(bytes, flush: true);

      if (mounted) {
        Navigator.of(context).pop(croppedFile.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ပုံဖြတ်ရာတွင် အမှားဖြစ်ပွားပါသည်: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1527),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: const Text(
          'ဓာတ်ပုံ Crop ပြုလုပ်မည်',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.rotate_90_degrees_cw,
              color: Color(0xFFF59E0B),
            ),
            tooltip: '၉၀° လှည့်မည်',
            onPressed: _rotateClockwise,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Middle Crop Area: Static image with movable/resizable crop border box
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF59E0B),
                      ),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Text(
                        'ပုံဖတ်၍မရပါ: $_errorMessage',
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        const double padding = 16.0;
                        final double availW =
                            (constraints.maxWidth - padding * 2).clamp(
                              100.0,
                              double.infinity,
                            );
                        final double availH =
                            (constraints.maxHeight - padding * 2).clamp(
                              100.0,
                              double.infinity,
                            );

                        final bool isRotated = (_quarterTurns % 2 == 1);
                        final double fullW = isRotated
                            ? _uiImage!.height.toDouble()
                            : _uiImage!.width.toDouble();
                        final double fullH = isRotated
                            ? _uiImage!.width.toDouble()
                            : _uiImage!.height.toDouble();

                        final double imgAspect = fullW / fullH;
                        final double contAspect = availW / availH;

                        double dispW;
                        double dispH;
                        if (imgAspect > contAspect) {
                          dispW = availW;
                          dispH = availW / imgAspect;
                        } else {
                          dispH = availH;
                          dispW = availH * imgAspect;
                        }

                        final double imgLeft =
                            (constraints.maxWidth - dispW) / 2;
                        final double imgTop =
                            (constraints.maxHeight - dispH) / 2;
                        final newImageRect = Rect.fromLTWH(
                          imgLeft,
                          imgTop,
                          dispW,
                          dispH,
                        );

                        final bool needsInit = _imageRect == null ||
                            _cropRect == null ||
                            _lastViewportSize != viewportSize ||
                            _lastQuarterTurns != _quarterTurns;

                        if (needsInit) {
                          _imageRect = newImageRect;
                          _cropRect = _computeInitialCropRect(newImageRect);
                          _lastViewportSize = viewportSize;
                          _lastQuarterTurns = _quarterTurns;
                        } else {
                          _imageRect = newImageRect;
                        }

                        return GestureDetector(
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          onScaleEnd: _onScaleEnd,
                          behavior: HitTestBehavior.opaque,
                          child: CustomPaint(
                            size: viewportSize,
                            painter: _CropViewerPainter(
                              image: _uiImage!,
                              imageRect: _imageRect!,
                              cropRect: _cropRect!,
                              quarterTurns: _quarterTurns,
                              borderColor: const Color(0xFFF59E0B),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Controls Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1527),
                border: Border(top: BorderSide(color: Color(0xFF1E2B43))),
              ),
              child: Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF94A3B8),
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Confirm Button
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0F172A),
                                ),
                              )
                            : const Icon(
                                Icons.crop,
                                size: 20,
                                color: Color(0xFF0F172A),
                              ),
                        label: Text(
                          _isProcessing ? 'ဖြတ်နေပါသည်...' : 'Crop',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: _isProcessing ? null : _cropAndConfirm,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropViewerPainter extends CustomPainter {
  final ui.Image image;
  final Rect imageRect;
  final Rect cropRect;
  final int quarterTurns;
  final Color borderColor;

  _CropViewerPainter({
    required this.image,
    required this.imageRect,
    required this.cropRect,
    required this.quarterTurns,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw static image inside imageRect with rotation
    canvas.save();
    canvas.clipRect(imageRect);
    canvas.translate(imageRect.left, imageRect.top);

    final bool isRotated = (quarterTurns % 2 == 1);
    final double fullW = isRotated
        ? image.height.toDouble()
        : image.width.toDouble();
    final double fullH = isRotated
        ? image.width.toDouble()
        : image.height.toDouble();

    final double scale = imageRect.width / fullW;
    canvas.scale(scale, scale);

    if (quarterTurns == 1) {
      canvas.translate(fullW, 0);
      canvas.rotate(math.pi / 2);
    } else if (quarterTurns == 2) {
      canvas.translate(fullW, fullH);
      canvas.rotate(math.pi);
    } else if (quarterTurns == 3) {
      canvas.translate(0, fullH);
      canvas.rotate(3 * math.pi / 2);
    }

    canvas.drawImage(
      image,
      Offset.zero,
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
    canvas.restore();

    // 2. Draw outer image border subtle outline
    final outerBorderPaint = Paint()
      ..color = const Color(0x3394A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(imageRect, outerBorderPaint);

    // 3. Draw dimmed mask outside cropRect
    final maskPaint = Paint()
      ..color = const Color(0xB8090E1B)
      ..style = PaintingStyle.fill;

    // Top
    if (cropRect.top > imageRect.top) {
      canvas.drawRect(
        Rect.fromLTRB(
          imageRect.left,
          imageRect.top,
          imageRect.right,
          cropRect.top,
        ),
        maskPaint,
      );
    }
    // Bottom
    if (cropRect.bottom < imageRect.bottom) {
      canvas.drawRect(
        Rect.fromLTRB(
          imageRect.left,
          cropRect.bottom,
          imageRect.right,
          imageRect.bottom,
        ),
        maskPaint,
      );
    }
    // Left
    if (cropRect.left > imageRect.left) {
      canvas.drawRect(
        Rect.fromLTRB(
          imageRect.left,
          cropRect.top,
          cropRect.left,
          cropRect.bottom,
        ),
        maskPaint,
      );
    }
    // Right
    if (cropRect.right < imageRect.right) {
      canvas.drawRect(
        Rect.fromLTRB(
          cropRect.right,
          cropRect.top,
          imageRect.right,
          cropRect.bottom,
        ),
        maskPaint,
      );
    }

    // 4. Rule of Thirds grid lines inside cropRect
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double stepX = cropRect.width / 3.0;
    final double stepY = cropRect.height / 3.0;

    canvas.drawLine(
      Offset(cropRect.left + stepX, cropRect.top),
      Offset(cropRect.left + stepX, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + stepX * 2, cropRect.top),
      Offset(cropRect.left + stepX * 2, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + stepY),
      Offset(cropRect.right, cropRect.top + stepY),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + stepY * 2),
      Offset(cropRect.right, cropRect.top + stepY * 2),
      gridPaint,
    );

    // 5. Crop Box Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, borderPaint);

    // 6. Corner L-brackets & Corner drag handles
    final cornerBracketPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.square;

    const double cornerLen = 22.0;

    // Top-Left corner bracket
    canvas.drawLine(
      cropRect.topLeft,
      Offset(cropRect.left + cornerLen, cropRect.top),
      cornerBracketPaint,
    );
    canvas.drawLine(
      cropRect.topLeft,
      Offset(cropRect.left, cropRect.top + cornerLen),
      cornerBracketPaint,
    );

    // Top-Right corner bracket
    canvas.drawLine(
      cropRect.topRight,
      Offset(cropRect.right - cornerLen, cropRect.top),
      cornerBracketPaint,
    );
    canvas.drawLine(
      cropRect.topRight,
      Offset(cropRect.right, cropRect.top + cornerLen),
      cornerBracketPaint,
    );

    // Bottom-Left corner bracket
    canvas.drawLine(
      cropRect.bottomLeft,
      Offset(cropRect.left + cornerLen, cropRect.bottom),
      cornerBracketPaint,
    );
    canvas.drawLine(
      cropRect.bottomLeft,
      Offset(cropRect.left, cropRect.bottom - cornerLen),
      cornerBracketPaint,
    );

    // Bottom-Right corner bracket
    canvas.drawLine(
      cropRect.bottomRight,
      Offset(cropRect.right - cornerLen, cropRect.bottom),
      cornerBracketPaint,
    );
    canvas.drawLine(
      cropRect.bottomRight,
      Offset(cropRect.right, cropRect.bottom - cornerLen),
      cornerBracketPaint,
    );

    // Circular corner handle dots
    final handleCircleFill = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    final handleCircleStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double dotRadius = 5.5;
    for (final pt in [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ]) {
      canvas.drawCircle(pt, dotRadius, handleCircleFill);
      canvas.drawCircle(pt, dotRadius, handleCircleStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _CropViewerPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.cropRect != cropRect ||
        oldDelegate.quarterTurns != quarterTurns ||
        oldDelegate.borderColor != borderColor;
  }
}
