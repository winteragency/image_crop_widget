// Copyright 2019 Florian Bauer. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'crop_area.dart';

class CropAreaTouchHandler {
  final CropArea _cropArea;
  Offset _activeAreaDelta;
  CropActionArea _activeArea;
  Offset _startPosition;

  CropAreaTouchHandler({@required CropArea cropArea}) : _cropArea = cropArea;

  void startTouch(Offset touchPosition) {
    _activeArea = _cropArea.getActionArea(touchPosition);
    _activeAreaDelta = _cropArea.getActionAreaDelta(touchPosition, _activeArea);
    _startPosition = touchPosition;
  }

  void updateTouch(Offset touchPosition, double aspectRatio) {
    _cropArea.move(touchPosition, _startPosition, _activeAreaDelta, _activeArea, aspectRatio);
  }

  void endTouch() {
    _activeArea = null;
    _activeAreaDelta = null;
  }
}
