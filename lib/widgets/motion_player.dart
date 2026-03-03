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
  final void Function(int clipIndex)? onClipChange; // callback เมื่อเปลี่ยน clip

  final double playbackFps;

  const MotionPlayer({
    super.key,
    required this.sequence,
    this.autoPlay = false,
    this.onComplete,
    this.thaiGroups,
    this.onClipChange,
    this.playbackFps = 50.0,
  });

  @override
  State<MotionPlayer> createState() => _MotionPlayerState();
}

class _MotionPlayerState extends State<MotionPlayer> {
  Timer? _timer;
  int _currentFrame = 0;
  bool _isPlaying = false;
  String _currentGloss = '';
  int _currentClipIndex = 0;

  // FPS control: range 5-60, default 30
  // static const double _minFps = 5.0;
  // static const double _maxFps = 60.0;
  // static const double _defaultFps = 30.0;
  // double _playbackFps = _defaultFps;

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

  /// ดึงคำภาษาไทยของ clip ปัจจุบัน (อาจมีหลายคำถ้าเป็น merged STILL)
  String get _currentThaiWord {
    if (widget.thaiGroups != null &&
        _currentClipIndex < widget.thaiGroups!.length) {
      final words = widget.thaiGroups![_currentClipIndex];
      // รวมคำด้วย ", " ถ้ามีหลายคำ
      return words.join(', ');
    }
    return '';
  }

  /// ตรวจสอบว่าคำปัจจุบันเป็น unknown/STILL หรือไม่
  bool get _isCurrentWordUnknown {
    // ถ้า gloss เป็น STILL หรือว่าง แสดงว่าเป็น unknown
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
    // final frameDuration = Duration(milliseconds: (1000 / _playbackFps).round());
    final frameDuration = Duration(milliseconds: (1000 / widget.playbackFps).round());

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
          // ตรวจสอบว่า clip index เปลี่ยนหรือไม่
          if (frameInfo.clipIndex != _currentClipIndex) {
            _currentClipIndex = frameInfo.clipIndex;
            widget.onClipChange?.call(_currentClipIndex);
          }
        }
      });
    });
  }

  // void _setFps(double fps) {
  //   setState(() {
  //     _playbackFps = fps.clamp(_minFps, _maxFps);
  //   });
  //   // ถ้ากำลังเล่นอยู่ ให้ restart timer ด้วย fps ใหม่
  //   if (_isPlaying) {
  //     _startTimer();
  //   }
  // }

  @override
  void didUpdateWidget(covariant MotionPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ถ้าเลื่อน Slider จากหน้าหลัก และแอนิเมชันกำลังเล่นอยู่ ให้รีสตาร์ทเวลาใหม่
    if (oldWidget.playbackFps != widget.playbackFps && _isPlaying) {
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

  void _seekTo(int frame) {
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
        // Current gloss indicator (Styled as a modern badge) - แสดงทั้งภาษาไทยและอังกฤษ
        // สีแดงเมื่อเป็น unknown/STILL, สีน้ำเงินเมื่อเป็นคำปกติ
        Builder(
          builder: (context) {
            final isUnknown = _isCurrentWordUnknown;
            final badgeColor = isUnknown ? Colors.red : Colors.blue.shade600;
            final shadowColor = isUnknown
                ? Colors.red.shade100
                : Colors.blue.shade100;
            final subtitleColor = isUnknown ? Colors.red.shade100 : Colors.blue.shade100;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // รหัสท่าทาง (English Gloss)
                  Text(
                    _currentGloss.isEmpty ? 'STILL' : _currentGloss,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // คำภาษาไทย
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _currentThaiWord.isNotEmpty ? _currentThaiWord : 'รอเล่น...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Skeleton canvas with correct aspect ratio and modern card look
        Expanded(
          child: Center(
            // 1. นำ ConstrainedBox มาครอบ AspectRatio ไว้
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 360, // 2. กำหนดความสูงสูงสุดของ Canvas (ปรับเลขให้พอดีกับจอได้เลย เช่น 300-400)
                maxWidth: double.infinity, // ความกว้างให้ขยายได้เต็มที่ตามสัดส่วน
              ),
              child: AspectRatio(
                aspectRatio: widget.sequence.aspectRatio,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50, // ใช้สีเทาอ่อนๆ หรือ Colors.white ก็ได้
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: frameInfo != null
                        ? CustomPaint(
                            painter: SkeletonPainter(frame: frameInfo.frame),
                            size: Size.infinite,
                          )
                        : Center(
                            child: Text(
                              'No frame data',
                              style: TextStyle(color: Colors.blue.shade300),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Control Panel Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            // borderRadius: BorderRadius.circular(24),
            // border: Border.all(color: Colors.blue.shade100, width: 1),
          ),
          child: Column(
            children: [
              // Progress bar
              Row(
                children: [
                  Text(
                    '0',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blue.shade600,
                        inactiveTrackColor: Colors.blue.shade200,
                        thumbColor: Colors.blue.shade700,
                        overlayColor: Colors.blue.withOpacity(0.2),
                        trackHeight: 4.0,
                      ),
                      child: Slider(
                        value: _currentFrame.toDouble(),
                        min: 0,
                        max: (totalFrames - 1).toDouble(),
                        onChanged: (value) => _seekTo(value.toInt()),
                      ),
                    ),
                  ),
                  Text(
                    '${totalFrames - 1}',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                ],
              ),
              Text(
                'Frame: $_currentFrame / ${totalFrames - 1}',
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // const SizedBox(height: 16),

              // // FPS Slider
              // Row(
              //   children: [
              //     Icon(Icons.speed, color: Colors.lightBlue.shade600, size: 22),
              //     const SizedBox(width: 8),
              //     Expanded(
              //       child: SliderTheme(
              //         data: SliderTheme.of(context).copyWith(
              //           activeTrackColor: Colors.lightBlue.shade400,
              //           inactiveTrackColor: Colors.lightBlue.shade100,
              //           thumbColor: Colors.lightBlue.shade600,
              //           trackHeight: 3.0,
              //         ),
              //         child: Slider(
              //           value: _playbackFps,
              //           min: _minFps,
              //           max: _maxFps,
              //           divisions: 11,
              //           label: '${_playbackFps.round()} FPS',
              //           onChanged: _setFps,
              //         ),
              //       ),
              //     ),
              //     Container(
              //       width: 75,
              //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              //       decoration: BoxDecoration(
              //         color: Colors.white,
              //         borderRadius: BorderRadius.circular(12),
              //         border: Border.all(color: Colors.lightBlue.shade200),
              //       ),
              //       child: Text(
              //         '${_playbackFps.round()} FPS',
              //         textAlign: TextAlign.center,
              //         style: TextStyle(
              //           fontWeight: FontWeight.bold,
              //           color: Colors.lightBlue.shade700,
              //           fontSize: 13,
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
              const SizedBox(height: 20),

              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded),
                    iconSize: 30,
                    color: Colors.blueGrey.shade400,
                    splashRadius: 28,
                  ),
                  const SizedBox(width: 24),
                  // Emphasized Play/Pause Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade100,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _isPlaying ? _pause : _play,
                      icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      iconSize: 36,
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    onPressed: () => _seekTo(_currentFrame + 10),
                    icon: const Icon(Icons.fast_forward_rounded),
                    iconSize: 30,
                    color: Colors.blueGrey.shade400,
                    splashRadius: 28,
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