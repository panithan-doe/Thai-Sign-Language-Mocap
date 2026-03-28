import 'package:flutter/material.dart';
import '../models/motion_models.dart';
import '../services/motion_loader.dart';
import '../utils/motion_preprocessor.dart';
import '../utils/preprocessing_config.dart';
import '../utils/vocab_mapper.dart';
import '../constants/api_constants.dart';
import 'motion_player.dart';

/// Dialog สำหรับแสดง preview animation ของคำ
/// ใช้ MotionPlayer เหมือนกับ PlayerScreen เพื่อให้ algorithm เดียวกัน
class WordPreviewDialog extends StatefulWidget {
  final String word;
  final String variant;
  final String context;

  const WordPreviewDialog({
    super.key,
    required this.word,
    required this.variant,
    required this.context,
  });

  @override
  State<WordPreviewDialog> createState() => _WordPreviewDialogState();
}

class _WordPreviewDialogState extends State<WordPreviewDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  MotionSequence? _sequence;
  Map<String, dynamic> _glossMap = {};

  late final MotionLoader _motionLoader;
  final VocabMapper _vocabMapper = VocabMapper();

  @override
  void initState() {
    super.initState();
    _motionLoader = MotionLoader(
      baseUrl: ApiConstants.cloudflareR2StorageBaseUrl,
      localPath: ApiConstants.motionLocalPath,
      useLocal: ApiConstants.useLocalMotionStorage,
    );
    _loadMotion();
  }

  Future<void> _loadMotion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. โหลด gloss_map.json
      await _vocabMapper.loadVocab();
      _glossMap = _vocabMapper.glossMap;

      // 2. สร้าง WordToken สำหรับคำนี้
      final token = WordToken(
        word: widget.word,
        variant: widget.variant,
        isUnknown: false,
      );

      // 3. โหลด motion data
      final motionDataList = await _motionLoader.preloadMotionsFromTokens([token]);

      if (motionDataList.isEmpty) {
        setState(() {
          _errorMessage = 'ไม่พบข้อมูล motion สำหรับคำนี้';
          _isLoading = false;
        });
        return;
      }

      // 4. สร้าง MotionClip
      final motionData = motionDataList.first;
      final clip = MotionClip.fromJson(
        motionData.motionJson,
        motionData.word,
        isStill: motionData.isStill,
      );

      // 5. สร้าง sequence
      final rawSequence = MotionSequence(clips: [clip]);

      // 6. Apply preprocessing (เหมือน PlayerScreen)
      const preprocessingConfig = PreprocessingConfig.normal;
      final preprocessor = MotionPreprocessor(preprocessingConfig);
      final processedSequence = preprocessor.preprocess(rawSequence);

      setState(() {
        _sequence = processedSequence;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3B82F6),
                    Color(0xFF1D4ED8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.word,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.variant}: ${widget.context}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF2563EB)),
            SizedBox(height: 16),
            Text(
              'กำลังโหลดข้อมูล...',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFDC2626),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadMotion,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_sequence == null) {
      return const Center(
        child: Text('ไม่พบข้อมูล'),
      );
    }

    // แสดง MotionPlayer เหมือน PlayerScreen
    return Padding(
      padding: const EdgeInsets.all(20),
      child: MotionPlayer(
        sequence: _sequence!,
        autoPlay: true,
        glossMap: _glossMap,
        mergedTokens: [
          WordToken(
            word: widget.word,
            variant: widget.variant,
            isUnknown: false,
          ),
        ],
        thaiGroups: [
          [widget.word],
        ],
      ),
    );
  }
}

/// ฟังก์ชัน helper สำหรับเปิด dialog
Future<void> showWordPreview(
  BuildContext context, {
  required String word,
  required String variant,
  required String wordContext,
}) {
  return showDialog(
    context: context,
    builder: (context) => WordPreviewDialog(
      word: word,
      variant: variant,
      context: wordContext,
    ),
  );
}
