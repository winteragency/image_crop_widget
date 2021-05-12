// Copyright 2019 Florian Bauer. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

library image_crop_widget;

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'src/crop_area.dart';
import 'src/crop_area_touch_handler.dart';
import 'src/pan_gesture_recognizer.dart';

class ImageCrop extends StatefulWidget {
  final ui.Image image;
  final double aspectRatio;

  ImageCrop({Key key, this.image, this.aspectRatio})
      : assert(image != null),
        super(key: key);

  @override
  ImageCropState createState() => ImageCropState();
}

class ImageCropState extends State<ImageCrop> {
  /// Rotates the image clockwise by 90 degree.
  /// Completes when the rotation is done.
  Future<void> rotateImage() async {
    final image = _state.image;
    ui.Image newImage;
    var pixel = 0;
    var attempts = 0;

    /// This loop is a very hacky workaround.
    /// In on device tests, about 1 in 10 times, the picture.toImage method returned
    /// a corrupted image object. So far, it is unclear why this happens.
    ///
    /// In case the image is corrupted, two possibilities have been observed:
    /// 1. All bytes of the image are 0.
    /// 2. An index out of bounds exception was thrown when accessing a high index.
    ///
    /// Usually, this behavior was observed on the first attempt to call this rotateImage method
    /// after the widget was build. Following calls to this method never or rarely produced this issue.
    do {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.rotate(pi / 2.0);
      canvas.translate(0.0, -image.height.toDouble());
      canvas.drawImage(image, Offset.zero, Paint());

      final picture = recorder.endRecording();
      newImage = await picture.toImage(image.height, image.width);
      picture.dispose();

      final newByteData = await newImage.toByteData();
      try {
        pixel = newByteData.getUint8(newByteData.lengthInBytes - 1);
      } catch (e) {
        print(e);
      }

      attempts++;
    } while (pixel == 0 && attempts < 4);

    setState(() {
      _state.image = newImage;
    });

    _state.imageSize = Size(
      _state.image.width.toDouble(),
      _state.image.height.toDouble(),
    );
    _state.fittedImageSize = applyBoxFit(
      BoxFit.contain,
      _state.imageSize,
      _state.widgetSize
    );
    _state.horizontalSpacing =
        (_state.widgetSize.width - _state.fittedImageSize.destination.width) / 2;
    _state.verticalSpacing =
        (_state.widgetSize.height - _state.fittedImageSize.destination.height) /
            2;

    _state.imageContainingRect = Rect.fromLTWH(
        _state.horizontalSpacing,
        _state.verticalSpacing,
        _state.fittedImageSize.destination.width,
        _state.fittedImageSize.destination.height);

    _state.cropArea.initSizes(
      center: Offset(_state.imageContainingRect.left + (0.5 * 100 * widget.aspectRatio), _state.imageContainingRect.top + 50),
      height: 100.0,
      width: 100.0 * widget.aspectRatio,
    bounds: _state.imageContainingRect
    );
    setState(() => {});
  }

  Future<void> rotateCounterClockwise() async {
    Future rotate() async {
      final image = _state.image;
      ui.Image newImage;
      var pixel = 0;
      var attempts = 0;

      do {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        canvas.rotate(pi / 2.0);
        canvas.translate(0.0, -image.height.toDouble());
        canvas.drawImage(image, Offset.zero, Paint());

        final picture = recorder.endRecording();
        newImage = await picture.toImage(image.height, image.width);
        picture.dispose();

        final newByteData = await newImage.toByteData();
        try {
          pixel = newByteData.getUint8(newByteData.lengthInBytes - 1);
        } catch (e) {
          print(e);
        }

        attempts++;
      } while (pixel == 0 && attempts < 4);
      _state.image = newImage;
    }

    await rotate();
    await rotate();
    await rotate();

    _state.imageSize = Size(
      _state.image.width.toDouble(),
      _state.image.height.toDouble(),
    );
    _state.fittedImageSize = applyBoxFit(
      BoxFit.contain,
      _state.imageSize,
      _state.widgetSize
    );
    _state.horizontalSpacing =
        (_state.widgetSize.width - _state.fittedImageSize.destination.width) / 2;
    _state.verticalSpacing =
        (_state.widgetSize.height - _state.fittedImageSize.destination.height) /
            2;

    _state.imageContainingRect = Rect.fromLTWH(
        _state.horizontalSpacing,
        _state.verticalSpacing,
        _state.fittedImageSize.destination.width,
        _state.fittedImageSize.destination.height);

    _state.cropArea.initSizes(
      center: Offset(_state.imageContainingRect.left + (0.5 * 100 * widget.aspectRatio), _state.imageContainingRect.top + 50),
      height: 100.0,
      width: 100.0 * widget.aspectRatio,
    bounds: _state.imageContainingRect
    );
    setState(() => {});
  }

  /// Crops the image to the currently marked area.
  /// Returns a new [ui.Image].
  Future<ui.Image> cropImage() async {
    final yOffset =
        (_state.widgetSize.height - _state.fittedImageSize.destination.height) /
            2.0;
    final xOffset =
        (_state.widgetSize.width - _state.fittedImageSize.destination.width) /
            2.0;
    final fittedCropRect = Rect.fromCenter(
      center: Offset(
        _state.cropArea.cropRect.center.dx - xOffset,
        _state.cropArea.cropRect.center.dy - yOffset,
      ),
      width: _state.cropArea.cropRect.width,
      height: _state.cropArea.cropRect.height,
    );

    final scale =
        _state.imageSize.width / _state.fittedImageSize.destination.width;
    final imageCropRect = Rect.fromLTRB(
        fittedCropRect.left * scale,
        fittedCropRect.top * scale,
        fittedCropRect.right * scale,
        fittedCropRect.bottom * scale);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(
      _state.image,
      Offset(-imageCropRect.left, -imageCropRect.top),
      Paint(),
    );

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(
      imageCropRect.width.toInt(),
      imageCropRect.height.toInt(),
    );
    picture.dispose();

    return croppedImage;
  }

  _SharedCropState _state = _SharedCropState();

  @override
  void initState() {
    super.initState();
    _state.image = widget.image;
    _state.cropArea = CropArea();
    _state.cropAreaTouchHandler =
        CropAreaTouchHandler(cropArea: _state.cropArea);
  }

  @override
  void didUpdateWidget(Widget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _state.cropArea.initSizes(
      center: Offset(_state.imageContainingRect.left + (0.5 * 100 * widget.aspectRatio), _state.imageContainingRect.top + 50),
      height: 100.0,
      width: 100.0 * widget.aspectRatio,
    bounds: _state.imageContainingRect
    );
  }

  void _onPanUpdate(PointerEvent event) {
    _onUpdate(event.position);
  }

  void _onPanEnd(PointerEvent event) {
    setState(() {
      _state.lastTouchPosition = null;
      _state.touchPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black87,
      child: CustomPaint(
        painter: _ImagePainter(_state),
        foregroundPainter: _OverlayPainter(_state, widget.aspectRatio),
        child: RawGestureDetector(
          gestures: {
            PanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
              () => PanGestureRecognizer(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
              ),
              (PanGestureRecognizer instance) {},
            )
          },
        ),
      ),
    );
  }

  void _onUpdate(Offset globalPosition) {
    final RenderBox renderBox = context.findRenderObject();
    _state.lastTouchPosition = _state.touchPosition;
    _state.touchPosition = renderBox.globalToLocal(globalPosition);

    if (_state.lastTouchPosition == null) {
      _state.cropAreaTouchHandler.startTouch(_state.touchPosition);
    } else {
      _state.cropAreaTouchHandler.updateTouch(_state.touchPosition, widget.aspectRatio);
    }

    setState(() {});
  }
}

class _SharedCropState {
  ui.Image image;

  Offset touchPosition;
  Offset lastTouchPosition;

  Size widgetSize;
  Size imageSize;
  FittedSizes fittedImageSize;
  double horizontalSpacing;
  double verticalSpacing;
  Rect imageContainingRect;

  CropArea cropArea;
  CropAreaTouchHandler cropAreaTouchHandler;
}

class _ImagePainter extends CustomPainter {
  final _SharedCropState state;
  final ui.Image image;

  _ImagePainter(this.state) : image = state.image;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final displayRect = Rect.fromLTWH(0.0, 0.0, size.width, size.height);
    state.widgetSize = size;
    paintImage(
      canvas: canvas,
      image: state.image,
      rect: displayRect,
      fit: BoxFit.contain,
    );
    state.imageSize = Size(
      state.image.width.toDouble(),
      state.image.height.toDouble(),
    );
    state.fittedImageSize = applyBoxFit(
      BoxFit.contain,
      state.imageSize,
      size,
    );
    state.horizontalSpacing =
        (state.widgetSize.width - state.fittedImageSize.destination.width) / 2;
    state.verticalSpacing =
        (state.widgetSize.height - state.fittedImageSize.destination.height) /
            2;

    state.imageContainingRect = Rect.fromLTWH(
        state.horizontalSpacing,
        state.verticalSpacing,
        state.fittedImageSize.destination.width,
        state.fittedImageSize.destination.height);
  }

  @override
  bool shouldRepaint(_ImagePainter oldDelegate) {
    return image != oldDelegate.image;
  }
}

class _OverlayPainter extends CustomPainter {
  final _SharedCropState _state;
  final Rect _cropRect;
  final double aspectRatio;
  final paintCorner = Paint()
    ..strokeWidth = 10.0
    ..strokeCap = StrokeCap.round
    ..color = Colors.white;
  final paintBackground = Paint()..color = Colors.white30;

  _OverlayPainter(this._state, this.aspectRatio) : _cropRect = _state.cropArea.cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    if (_state.cropArea.cropRect == null) {
      _state.cropArea.initSizes(
        bounds: _state.imageContainingRect,
        center: Offset(size.width / 2, size.height / 2),
        height: 100.0,
        width: 100.0 * aspectRatio,
      );
    }

    _state.cropArea.bounds = _state.imageContainingRect;

    canvas.drawRect(_state.cropArea.cropRect, paintBackground);
    final points = <Offset>[
      _state.cropArea.cropRect.bottomRight
    ];

    canvas.drawPoints(ui.PointMode.points, points, paintCorner);
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) {
    return _cropRect != oldDelegate._cropRect;
  }
}
