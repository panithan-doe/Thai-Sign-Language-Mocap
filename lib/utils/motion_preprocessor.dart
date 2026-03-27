import '../models/motion_models.dart';
import 'preprocessing_config.dart';

/// Motion data preprocessor for reducing jitter and filling gaps
class MotionPreprocessor {
  final PreprocessingConfig config;

  const MotionPreprocessor(this.config);

  /// Preprocess MotionSequence ทั้งหมด
  MotionSequence preprocess(MotionSequence sequence) {
    if (!config.enabled) return sequence;

    // Process แต่ละ clip แยกกัน
    final processedClips = sequence.clips.map((clip) {
      final processedFrames = _preprocessClip(clip.frames);
      return MotionClip(
        gloss: clip.gloss,
        fps: clip.fps,
        totalFrames: processedFrames.length,
        videoWidth: clip.videoWidth,
        videoHeight: clip.videoHeight,
        frames: processedFrames,
      );
    }).toList();

    return MotionSequence(
      clips: processedClips,
    );
  }

  /// Preprocess แต่ละ clip
  List<MotionFrame> _preprocessClip(List<MotionFrame> frames) {
    if (frames.isEmpty) return frames;

    final totalFrames = frames.length;

    // สร้างโครงสร้างผลลัพธ์
    List<Map<String, List<Landmark>>> processedData = List.generate(
      totalFrames,
      (index) => {'pose': [], 'leftHand': [], 'rightHand': []},
    );

    // Process แต่ละกลุ่ม landmark
    for (String key in ['pose', 'leftHand', 'rightHand']) {
      // หาจำนวน landmarks สูงสุด
      int maxLandmarkId = 0;
      for (var frame in frames) {
        final landmarks = _getLandmarks(frame, key);
        for (var lm in landmarks) {
          if (lm.location > maxLandmarkId) maxLandmarkId = lm.location;
        }
      }

      // Process แต่ละ landmark ID
      for (int id = 0; id <= maxLandmarkId; id++) {
        _processLandmarkAcrossFrames(
          frames,
          processedData,
          key,
          id,
          totalFrames,
        );
      }
    }

    // สร้าง MotionFrame ใหม่จากข้อมูลที่ประมวลผลแล้ว
    return List.generate(totalFrames, (frameIndex) {
      return MotionFrame(
        frameIndex: frameIndex,
        pose: processedData[frameIndex]['pose']!,
        leftHand: processedData[frameIndex]['leftHand']!,
        rightHand: processedData[frameIndex]['rightHand']!,
      );
    });
  }

  /// Process landmark หนึ่งจุดข้ามทุกเฟรม
  void _processLandmarkAcrossFrames(
    List<MotionFrame> frames,
    List<Map<String, List<Landmark>>> output,
    String key,
    int landmarkId,
    int totalFrames,
  ) {
    // 1. สกัดข้อมูล x, y, z ทุกเฟรม
    List<double> rawX = List.filled(totalFrames, 0.0);
    List<double> rawY = List.filled(totalFrames, 0.0);
    List<double> rawZ = List.filled(totalFrames, 0.0);
    List<bool> isPresent = List.filled(totalFrames, false);

    double firstValidX = 0.0, firstValidY = 0.0, firstValidZ = 0.0;
    bool foundFirst = false;

    for (int f = 0; f < totalFrames; f++) {
      final landmarks = _getLandmarks(frames[f], key);
      final lm = landmarks.where((p) => p.location == landmarkId).firstOrNull;

      // ✅ Filter out (0,0,0) landmarks (from low visibility in MediaPipe)
      if (lm != null && !(lm.x == 0.0 && lm.y == 0.0 && lm.z == 0.0)) {
        rawX[f] = lm.x;
        rawY[f] = lm.y;
        rawZ[f] = lm.z;
        isPresent[f] = true;

        if (!foundFirst) {
          firstValidX = lm.x;
          firstValidY = lm.y;
          firstValidZ = lm.z;
          foundFirst = true;
        }
      }
    }

    if (!foundFirst) return; // landmark ไม่มีเลยในทุกเฟรม

    // 2. Gap Filling - Linear Interpolation
    _fillGaps(rawX, rawY, rawZ, isPresent, firstValidX, firstValidY, firstValidZ, totalFrames);

    // 3. Median Filter - กำจัด noise (เปิดกลับมาเพื่อกำจัด outliers)
    rawX = _applyMedianFilter(rawX);
    rawY = _applyMedianFilter(rawY);
    rawZ = _applyMedianFilter(rawZ);

    // 4. Savitzky-Golay Filter - รีดเส้นให้เนียน
    List<double> smoothX = rawX;
    List<double> smoothY = rawY;
    List<double> smoothZ = rawZ;

    for (int p = 0; p < config.sgPasses; p++) {
      if (config.sgWindowSize == 9) {
        smoothX = _applySavitzkyGolay9(smoothX);
        smoothY = _applySavitzkyGolay9(smoothY);
        smoothZ = _applySavitzkyGolay9(smoothZ);
      } else {
        smoothX = _applySavitzkyGolay5(smoothX);
        smoothY = _applySavitzkyGolay5(smoothY);
        smoothZ = _applySavitzkyGolay5(smoothZ);
      }
    }

    // 5. ประกอบข้อมูลกลับ
    // ⚠️ เพิ่มเฉพาะ landmark ที่มีข้อมูลจริง (isPresent = true)
    // เฟรมที่ไม่มีมือ จะไม่ถูก add → ไม่วาดมือ
    for (int f = 0; f < totalFrames; f++) {
      if (isPresent[f]) {
        output[f][key]!.add(Landmark(
          location: landmarkId,
          x: smoothX[f],
          y: smoothY[f],
          z: smoothZ[f],
          visibility: 0.99,
        ));
      }
    }
  }

  /// Gap Filling: เติมช่องว่างด้วย Linear Interpolation
  /// ⚠️ เติมค่า x,y,z ให้ทุก gap เพื่อให้ Median/SG Filter ทำงานได้ถูกต้อง
  /// แต่ set isPresent=true เฉพาะ gap เล็ก (<= maxGapToFill)
  void _fillGaps(
    List<double> x,
    List<double> y,
    List<double> z,
    List<bool> isPresent,
    double firstX,
    double firstY,
    double firstZ,
    int totalFrames,
  ) {
    int lastValidIndex = -1;

    // 1. Linear interpolation สำหรับช่องโหว่ระหว่างเฟรม
    // ⚠️ เติมค่าทุก gap (ไม่สน maxGapToFill) เพื่อไม่ให้เหลือค่า 0.0
    for (int f = 0; f < totalFrames; f++) {
      if (isPresent[f]) {
        if (lastValidIndex != -1 && f - lastValidIndex > 1) {
          int gap = f - lastValidIndex;
          double startX = x[lastValidIndex];
          double startY = y[lastValidIndex];
          double startZ = z[lastValidIndex];
          double endX = x[f];
          double endY = y[f];
          double endZ = z[f];

          // เติมค่าทุก gap (ไม่เช็ค maxGapToFill)
          for (int step = 1; step < gap; step++) {
            x[lastValidIndex + step] = startX + ((endX - startX) / gap) * step;
            y[lastValidIndex + step] = startY + ((endY - startY) / gap) * step;
            z[lastValidIndex + step] = startZ + ((endZ - startZ) / gap) * step;
            // ❌ ไม่ set isPresent ที่นี่
          }
        }
        lastValidIndex = f;
      }
    }

    // 2. เติมค่าด้านหน้า (แต่ไม่ set isPresent=true)
    for (int f = 0; f < totalFrames; f++) {
      if (isPresent[f]) break;
      x[f] = firstX;
      y[f] = firstY;
      z[f] = firstZ;
    }

    // 3. เติมค่าด้านหลัง (แต่ไม่ set isPresent=true)
    if (lastValidIndex != -1 && lastValidIndex < totalFrames - 1) {
      for (int f = lastValidIndex + 1; f < totalFrames; f++) {
        x[f] = x[lastValidIndex];
        y[f] = y[lastValidIndex];
        z[f] = z[lastValidIndex];
      }
    }

    // 4. อัปเดต isPresent เฉพาะ gap เล็ก (<= maxGapToFill)
    // gap ใหญ่จะมีค่า x,y,z (ไม่ใช่ 0.0) แต่ไม่แสดงออกมา
    // ⚠️ ไม่ set gap ที่อยู่ด้านหน้าสุดของคลิป (f=0 ไปจนถึงจุดแรกที่มีข้อมูล)
    bool foundFirstData = false;
    int missingCount = 0;
    for (int f = 0; f < totalFrames; f++) {
      if (!isPresent[f]) {
        missingCount++;
      } else {
        // เจอจุดที่มีข้อมูล
        if (!foundFirstData) {
          // นี่คือจุดแรกที่มีข้อมูล → ไม่ set gap ด้านหน้า
          foundFirstData = true;
          missingCount = 0;
        } else {
          // มีข้อมูลมาก่อนหน้านี้แล้ว → เช็ค gap ว่าเล็กพอไหม
          if (missingCount > 0 && missingCount <= config.maxGapToFill) {
            // gap เล็ก → แสดงออกมา
            for (int m = 1; m <= missingCount; m++) {
              isPresent[f - m] = true;
            }
          }
          missingCount = 0;
        }
      }
    }
  }

  /// Median Filter
  List<double> _applyMedianFilter(List<double> data) {
    if (data.length < config.medianWindowSize) return data;

    List<double> filtered = List.filled(data.length, 0.0);
    int edge = config.medianWindowSize ~/ 2;

    // Copy edges
    for (int i = 0; i < edge; i++) {
      filtered[i] = data[i];
      filtered[data.length - 1 - i] = data[data.length - 1 - i];
    }

    // Median filter
    for (int i = edge; i < data.length - edge; i++) {
      List<double> window = data.sublist(i - edge, i + edge + 1);
      window.sort();
      filtered[i] = window[edge];
    }
    return filtered;
  }

  /// Savitzky-Golay Filter (Window=5, Polynomial=2)
  List<double> _applySavitzkyGolay5(List<double> data) {
    if (data.length < 5) return data;
    List<double> smoothed = List.filled(data.length, 0.0);

    smoothed[0] = data[0];
    smoothed[1] = data[1];
    smoothed[data.length - 2] = data[data.length - 2];
    smoothed[data.length - 1] = data[data.length - 1];

    for (int i = 2; i < data.length - 2; i++) {
      smoothed[i] = (-3 * data[i - 2] +
              12 * data[i - 1] +
              17 * data[i] +
              12 * data[i + 1] +
              -3 * data[i + 2]) /
          35.0;
    }
    return smoothed;
  }

  /// Savitzky-Golay Filter (Window=9, Polynomial=2)
  List<double> _applySavitzkyGolay9(List<double> data) {
    if (data.length < 9) return data;
    List<double> smoothed = List.filled(data.length, 0.0);

    for (int i = 0; i < 4; i++) {
      smoothed[i] = data[i];
      smoothed[data.length - 1 - i] = data[data.length - 1 - i];
    }

    for (int i = 4; i < data.length - 4; i++) {
      smoothed[i] = (-21 * data[i - 4] +
              14 * data[i - 3] +
              39 * data[i - 2] +
              54 * data[i - 1] +
              59 * data[i] +
              54 * data[i + 1] +
              39 * data[i + 2] +
              14 * data[i + 3] +
              -21 * data[i + 4]) /
          231.0;
    }
    return smoothed;
  }

  /// Helper: ดึง landmarks ตาม key
  List<Landmark> _getLandmarks(MotionFrame frame, String key) {
    switch (key) {
      case 'pose':
        return frame.pose;
      case 'leftHand':
        return frame.leftHand;
      case 'rightHand':
        return frame.rightHand;
      default:
        return [];
    }
  }
}
