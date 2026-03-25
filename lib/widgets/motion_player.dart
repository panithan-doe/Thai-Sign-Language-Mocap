import 'dart:async';
import 'package:flutter/material.dart';
import '../models/motion_models.dart';
import 'skeleton_painter.dart';

/// Widget that plays a sequence of motion clips as skeleton animation
class MotionPlayer extends StatefulWidget {
  final MotionSequence sequence;
  final bool autoPlay;
  final VoidCallback? onComplete;
  final List<List<String>>? thaiGroups; // กลุ่มคำภาษาไทยสำหรับแสดงผล (merged)
  final List<WordToken>? mergedTokens; // WordToken พร้อม variant สำหรับแสดง gloss
  final Map<String, dynamic>? glossMap; // gloss_map.json สำหรับดึงบริบท
  final void Function(int clipIndex)? onClipChange; // callback เมื่อเปลี่ยน clip

  const MotionPlayer({
    super.key,
    required this.sequence,
    this.autoPlay = false,
    this.onComplete,
    this.thaiGroups,
    this.mergedTokens,
    this.glossMap,
    this.onClipChange,
  });

  @override
  // เปลี่ยนชื่อคลาส State เป็น Public (เอา _ ออก) เพื่อให้ใช้กับ GlobalKey ได้
  State<MotionPlayer> createState() => MotionPlayerState();
}

class MotionPlayerState extends State<MotionPlayer> {
  Timer? _timer;
  int _currentFrame = 0;
  bool _isPlaying = false;
  String _currentGloss = '';
  int _currentClipIndex = 0;

  // นำระบบจัดการ FPS กลับมาไว้ที่นี่ เพราะฝั่งซ้ายคุมเองทั้งหมดแล้ว
  static const double _minFps = 5.0;
  static const double _maxFps = 60.0;
  static const double _defaultFps = 50.0;
  double _playbackFps = _defaultFps;

  @override
  void initState() {
    super.initState();
    if (widget.sequence.clips.isNotEmpty) {
      _currentGloss = widget.sequence.clips.first.gloss;
    }
    if (widget.autoPlay) {
      _play();
    }
  }

  String get _currentThaiWord {
    if (widget.thaiGroups != null &&
        _currentClipIndex < widget.thaiGroups!.length) {
      final words = widget.thaiGroups![_currentClipIndex];
      return words.join(', ');
    }
    return '';
  }

  /// ดึงข้อมูล variant และบริบทจาก gloss_map
  /// เช่น "ผม (v2: เส้นผม)" หรือกรณีไม่มีคำแสดง "STILL"
  String get _currentVariantDisplay {
    if (widget.mergedTokens != null && _currentClipIndex < widget.mergedTokens!.length) {
      final token = widget.mergedTokens![_currentClipIndex];

      // ถ้าเป็น Unknown word → แสดงแค่ "STILL"
      if (token.isUnknown) {
        return 'STILL';
      }

      // ถ้าเป็นคำปกติ → แสดง "คำ (variant: บริบท)"
      if (widget.glossMap != null) {
        final wordVariants = widget.glossMap![token.word];
        if (wordVariants != null && wordVariants is Map) {
          final context = wordVariants[token.variant];
          if (context != null) {
            // return '${token.word} (${token.variant}: $context)';
            return '${token.variant}: $context';
          }
        }
      }
      // fallback: ถ้าไม่มีบริบทใน glossMap
      return '${token.word} (${token.variant})';
    }

    // fallback ถ้าไม่มี mergedTokens
    return _currentGloss.isEmpty ? 'STILL' : _currentGloss;
  }

  bool get _isCurrentWordUnknown {
    if (_currentGloss.isEmpty || _currentGloss == 'STILL') {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play() {
    if (_isPlaying) return;
    setState(() {
      _isPlaying = true;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final frameDuration = Duration(milliseconds: (1000 / _playbackFps).round());

    _timer = Timer.periodic(frameDuration, (timer) {
      if (_currentFrame >= widget.sequence.totalFrames - 1) {
        _stop();
        widget.onComplete?.call();
        return;
      }

      setState(() {
        _currentFrame++;
        final frameInfo = widget.sequence.getFrameAt(_currentFrame);
        if (frameInfo != null) {
          _currentGloss = frameInfo.gloss;
          if (frameInfo.clipIndex != _currentClipIndex) {
            _currentClipIndex = frameInfo.clipIndex;
            widget.onClipChange?.call(_currentClipIndex);
          }
        }
      });
    });
  }

  void _setFps(double fps) {
    setState(() {
      _playbackFps = fps.clamp(_minFps, _maxFps);
    });
    if (_isPlaying) {
      _startTimer();
    }
  }

  void _pause() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _currentFrame = 0;
      _currentClipIndex = 0;
      if (widget.sequence.clips.isNotEmpty) {
        _currentGloss = widget.sequence.clips.first.gloss;
      }
    });
    widget.onClipChange?.call(0);
  }

  // เปลี่ยนเป็น Public Method (เอา _ ออก) เพื่อให้ภายนอกเรียกได้
  void seekTo(int frame) {
    setState(() {
      _currentFrame = frame.clamp(0, widget.sequence.totalFrames - 1);
      final frameInfo = widget.sequence.getFrameAt(_currentFrame);
      if (frameInfo != null) {
        _currentGloss = frameInfo.gloss;
        if (frameInfo.clipIndex != _currentClipIndex) {
          _currentClipIndex = frameInfo.clipIndex;
          widget.onClipChange?.call(_currentClipIndex);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final frameInfo = widget.sequence.getFrameAt(_currentFrame);
    final totalFrames = widget.sequence.totalFrames;

    return Column(
      children: [
        // 1. Badge แสดงคำปัจจุบัน (ลอยอยู่ด้านบน)
        Builder(
          builder: (context) {
            final isUnknown = _isCurrentWordUnknown;
            final badgeColor = isUnknown ? Colors.red : Colors.blue.shade600;
            final subtitleColor = isUnknown ? Colors.red.shade100 : Colors.blue.shade100;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              // decoration: BoxDecoration(
              //   color: badgeColor,
              //   borderRadius: BorderRadius.circular(24),
              //   boxShadow: [
              //     BoxShadow(
              //       color: badgeColor.withOpacity(0.3),
              //       blurRadius: 10,
              //       offset: const Offset(0, 4),
              //     ),
              //   ],
              // ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // บรรทัดบน: คำภาษาไทยที่สกัดได้ (สีดำทึบ, ขนาดใหญ่)
                  Text(
                    _currentThaiWord.isNotEmpty ? _currentThaiWord : 'รอเล่น...',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // บรรทัดล่าง: ท่า motion.json ที่ถูกเล่นจริงๆ พร้อม variant และบริบท (สีเทา, ขนาดเล็ก)
                  Text(
                    _currentVariantDisplay,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // 2. เวทีแสดงผล (Canvas) พื้นที่ใหญ่ที่สุด
        Expanded(
          // --- แก้ไขตรงนี้: กำหนดความสูงตายตัว และให้ขยายความกว้างเอง ---
          child: SizedBox(
            height: 360, // ล็อคความสูงไว้เท่าเดิมตามที่คุณต้องการ
            child: AspectRatio(
              aspectRatio: widget.sequence.aspectRatio, // ใส่สัดส่วนภาพเหมือนเดิม
              // --------------------------------------------------
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: frameInfo != null
                      ? CustomPaint(
                          painter: SkeletonPainter(frame: frameInfo.frame),
                          size: Size.infinite,
                        )
                      : const Center(child: Text('No frame data')),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. แผงควบคุมทั้งหมด (แบบ Web Player)
        Container(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              // 3.1 Progress bar (ยาวเต็มพื้นที่)
              Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blue.shade600,
                        inactiveTrackColor: Colors.blue.shade100,
                        thumbColor: Colors.blue.shade700,
                        overlayColor: Colors.blue.withOpacity(0.2),
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      ),
                      child: Slider(
                        value: _currentFrame.toDouble(),
                        min: 0,
                        max: (totalFrames - 1).toDouble(),
                        onChanged: (value) => seekTo(value.toInt()),
                      ),
                    ),
                  ),
                ],
              ),
              
              // 3.2 ปุ่มควบคุมซ้าย-ขวา
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ฝั่งซ้าย: กลุ่มปุ่ม Play/Pause และบอกเวลา(Frame)
                  Row(
                    children: [
                      IconButton(
                        onPressed: _isPlaying ? _pause : _play,
                        icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                        iconSize: 42,
                        color: Colors.blue.shade600,
                        padding: EdgeInsets.zero,
                        splashRadius: 24,
                      ),
                      IconButton(
                        onPressed: _stop,
                        icon: const Icon(Icons.stop_circle_outlined),
                        iconSize: 32,
                        color: Colors.blueGrey.shade400,
                        padding: EdgeInsets.zero,
                        splashRadius: 24,
                      ),
                      const SizedBox(width: 8),
                      // ตัวเลขบอกเฟรมปัจจุบัน / เฟรมทั้งหมด
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_currentFrame + 1} / $totalFrames',
                          style: TextStyle(
                            color: Colors.blueGrey.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ฝั่งขวา: ปุ่มตั้งค่าความเร็ว (FPS Slider แบบกะทัดรัด)
                  Row(
                    children: [
                      Icon(Icons.speed, color: Colors.blueGrey.shade400, size: 20),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 100, // กำหนดความกว้างไม่ให้ Slider ยาวเกินไป
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.blueGrey.shade400,
                            inactiveTrackColor: Colors.blueGrey.shade100,
                            thumbColor: Colors.blueGrey.shade600,
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                          ),
                          child: Slider(
                            value: _playbackFps,
                            min: _minFps,
                            max: _maxFps,
                            divisions: 11,
                            onChanged: _setFps,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_playbackFps.round()}x', // แสดงเป็นอารมณ์ความเร็วเช่น 30x (30 fps)
                        style: TextStyle(
                          color: Colors.blueGrey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}