import 'package:flutter/material.dart';
import '../models/motion_models.dart';
import '../widgets/motion_player.dart';
import '../services/motion_loader.dart';
import '../utils/vocab_mapper.dart';
import '../utils/motion_preprocessor.dart';
import '../utils/preprocessing_config.dart';

class PlayerScreen extends StatefulWidget {
  final List<MotionData> motionDataList;
  final List<WordToken> tokens;
  final MergedTokenSequence mergedSequence;
  final String originalText;

  const PlayerScreen({
    super.key,
    required this.motionDataList,
    required this.tokens,
    required this.mergedSequence,
    required this.originalText,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  MotionSequence? _sequence;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentClipIndex = 0;
  Map<String, dynamic> _glossMap = {}; // เก็บ gloss_map.json

  // สร้าง Key สำหรับควบคุม MotionPlayer จากภายนอก
  final GlobalKey<MotionPlayerState> _playerKey = GlobalKey<MotionPlayerState>();
  final VocabMapper _vocabMapper = VocabMapper();

  // Responsive breakpoints
  bool _isMobile(BuildContext context) => MediaQuery.of(context).size.width < 768;

  @override
  void initState() {
    super.initState();
    _loadGlossMapAndBuildSequence();
  }

  Future<void> _loadGlossMapAndBuildSequence() async {
    try {
      // โหลด gloss_map.json ก่อน
      await _vocabMapper.loadVocab();
      _glossMap = _vocabMapper.glossMap;

      // จากนั้นสร้าง sequence
      _buildSequence();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading gloss map: $e';
        _isLoading = false;
      });
    }
  }

  void _buildSequence() {
    try {
      final clips = <MotionClip>[];

      for (final motionData in widget.motionDataList) {
        final clip = MotionClip.fromJson(
          motionData.motionJson,
          motionData.word,
          isStill: motionData.isStill,
        );
        clips.add(clip);
      }

      // สร้าง sequence ต้นฉบับ
      final rawSequence = MotionSequence(clips: clips);

      // 🆕 Apply preprocessing (Gap Filling + Median + Savitzky-Golay)
      // เปลี่ยน config ได้ที่นี่: .none, .light, .normal, .heavy
      // ใช้ .light สำหรับท่าที่มีการเคลื่อนไหวเร็ว (responsive กว่า)
      const preprocessingConfig = PreprocessingConfig.normal;
      final preprocessor = MotionPreprocessor(preprocessingConfig);
      final processedSequence = preprocessor.preprocess(rawSequence);

      setState(() {
        _sequence = processedSequence;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error building sequence: $e';
        _isLoading = false;
      });
    }
  }

  // Helper method: Video Player Section
  Widget _buildVideoPlayerSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MotionPlayer(
            key: _playerKey,
            sequence: _sequence!,
            autoPlay: false,
            thaiGroups: widget.mergedSequence.thaiGroups,
            mergedTokens: widget.mergedSequence.mergedTokens,
            glossMap: _glossMap,
            onClipChange: (clipIndex) {
              setState(() {
                _currentClipIndex = clipIndex;
              });
            },
          ),
        ),
      ),
    );
  }

  // Helper method: Info Cards (Motions + Frames)
  Widget _buildInfoCards() {
    return Row(
      children: [
        // กล่องที่ 1: Total Motions
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.accessibility_new_outlined,
                    color: Color(0xFF3B82F6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Motions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${widget.mergedSequence.mergedTokens.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // กล่องที่ 2: Total Frames
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.layers_outlined,
                    color: Color(0xFF3B82F6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Frames',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_sequence!.totalFrames}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper method: Gloss Sequence Section
  Widget _buildGlossSequenceSection(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // หัวตาราง + Info Cards (ซ่อนบน mobile)
          if (!isMobile) ...[
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ลำดับท่าทาง (Gloss Sequence)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info Cards
                  Row(
                    children: [
                      // กล่องที่ 1: Total Motions
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.accessibility_new_outlined,
                                  color: Color(0xFF3B82F6),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Motions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${widget.mergedSequence.mergedTokens.length}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF3B82F6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // กล่องที่ 2: Total Frames
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.layers_outlined,
                                  color: Color(0xFF3B82F6),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Frames',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${_sequence!.totalFrames}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF3B82F6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
          ],

          // ลิสต์รายการท่าทาง (Scrollable)
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 8),
              itemCount: _sequence!.clips.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final clip = _sequence!.clips[index];
                final isCurrent = index == _currentClipIndex;
                final displayGloss = clip.gloss.isEmpty ? 'STILL' : clip.gloss;

                int calculatedStartFrame = 0;
                for (int i = 0; i < index; i++) {
                  calculatedStartFrame += _sequence!.clips[i].totalFrames;
                }

                final int frameCount = clip.totalFrames;
                final int calculatedEndFrame = calculatedStartFrame + frameCount - 1;

                return InkWell(
                  onTap: () {
                    _playerKey.currentState?.seekTo(calculatedStartFrame);
                  },
                  child: Container(
                    color: isCurrent ? Colors.blue.shade50.withOpacity(0.5) : Colors.transparent,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 24,
                      vertical: isMobile ? 10 : 12,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // กล่องไอคอนฝั่งซ้าย
                          AspectRatio(
                            aspectRatio: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isCurrent ? const Color(0xFF3B82F6) : Colors.blue.shade50.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  isCurrent ? Icons.accessibility_new : Icons.accessibility_new_outlined,
                                  color: isCurrent ? Colors.white : Colors.blue.shade300,
                                  size: isMobile ? 20 : 24,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: isMobile ? 12 : 16),

                          // เนื้อหา 3 บรรทัดฝั่งขวา
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // บรรทัดที่ 1: ชื่อ Motion (ENG) + Badge
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayGloss,
                                        style: TextStyle(
                                          fontSize: isMobile ? 13 : 15,
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                          color: isCurrent ? const Color(0xFF1E293B) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    if (isCurrent) ...[
                                      SizedBox(width: isMobile ? 8 : 12),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 6 : 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Playing',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isMobile ? 9 : 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),

                                const SizedBox(height: 2),

                                const SizedBox(height: 2),

                                // บรรทัดที่ 3: Framestamp
                                Text(
                                  'Frame: ${calculatedStartFrame + 1} - ${calculatedEndFrame + 1} • $frameCount frames',
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 12,
                                    color: isCurrent ? Colors.blue.shade400 : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        // Mobile: แสดงแค่ไอคอน back, Desktop: แสดงปุ่มเต็ม
        leadingWidth: isMobile ? 56 : 220,

        leading: isMobile
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              color: const Color(0xFF3B82F6),
            )
          : Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'ทดสอบประโยคใหม่',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  backgroundColor: Colors.blue.shade50.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

        title: Text(
          'Animation Player',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 18 : 20,
            color: const Color(0xFF1E293B),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF3B82F6)),
            SizedBox(height: 16),
            Text('กำลังเตรียม Animation...', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_sequence == null || _sequence!.clips.isEmpty) {
      return const Center(child: Text('ไม่มีข้อมูล Motion'));
    }

    final isMobile = _isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= 1. ส่วน Header (ข้อความต้นฉบับ + Chips) =================
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // เครื่องหมายคำพูดเปิด
              Transform.flip(
                flipX: true,
                child: Icon(
                  Icons.format_quote_rounded,
                  color: Colors.blue.shade300,
                  size: isMobile ? 20 : 28,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),

              // ข้อความต้นฉบับ
            Text(
                widget.originalText,
                style: TextStyle(
                  fontSize: isMobile ? 18 : 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              

              SizedBox(width: isMobile ? 8 : 12),

              // เครื่องหมายคำพูดปิด
              Icon(
                Icons.format_quote_rounded,
                color: Colors.blue.shade300,
                size: isMobile ? 20 : 28,
              ),
            ],
          ),

          SizedBox(height: isMobile ? 12 : 20),

          // --- Gloss Chips สำหรับทั้ง Mobile และ Desktop ---
          Row(
            children: [
              Text(
                'ลำดับคำภาษาไทย',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'สีแดงคือคำที่ไม่มีใน Gloss Dictionary\nระบบจะทำการใช้ท่าทาง STILL ให้อัตโนมัติ',
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Colors.redAccent,
                  size: isMobile ? 16 : 18,
                ),
              ),
            ],
          ),

          SizedBox(height: isMobile ? 6 : 8),

          Wrap(
            spacing: isMobile ? 6 : 8,
            runSpacing: isMobile ? 6 : 8,
            children: List.generate(widget.tokens.length, (index) {
              final token = widget.tokens[index];
              final isUnknown = token.isUnknown;
              final displayWord = token.word;

              final currentOriginalIndices = _currentClipIndex < widget.mergedSequence.originalIndices.length
                  ? widget.mergedSequence.originalIndices[_currentClipIndex]
                  : <int>[];
              final isCurrentlyPlaying = currentOriginalIndices.contains(index);

              Color bgColor;
              Color borderColor;
              Color textColor;
              Color numberBgColor;

              if (isUnknown) {
                bgColor = isCurrentlyPlaying ? Colors.red : Colors.red.shade50;
                borderColor = Colors.red;
                textColor = isCurrentlyPlaying ? Colors.white : Colors.red;
                numberBgColor = Colors.red;
              } else {
                bgColor = isCurrentlyPlaying ? Colors.blue.shade600 : Colors.blue.shade50;
                borderColor = Colors.blue.shade600;
                textColor = isCurrentlyPlaying ? Colors.white : Colors.blue.shade700;
                numberBgColor = Colors.blue.shade600;
              }

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 14,
                  vertical: isMobile ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                  border: Border.all(
                    color: borderColor,
                    width: isCurrentlyPlaying ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isMobile ? 18 : 20,
                      height: isMobile ? 18 : 20,
                      decoration: BoxDecoration(
                        color: numberBgColor,
                        borderRadius: BorderRadius.circular(isMobile ? 5 : 6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 10 : 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 6 : 8),
                    Text(
                      displayWord,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.w600,
                        fontSize: isMobile ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // ================= 2. ส่วน Content (ซ้าย 70% / ขวา 30%) =================
          Expanded(
            child: isMobile
                ? Column(
                    children: [
                      // Video Player Section (แสดงก่อนบน mobile) - ใหญ่ขึ้นจาก flex: 3 เป็น 5
                      Expanded(
                        flex: 5,
                        child: _buildVideoPlayerSection(),
                      ),
                      const SizedBox(height: 16),
                      // Gloss Sequence Section (แสดงทีหลังล่างบน mobile) - ลดลงจาก flex: 2 เป็น 2
                      Expanded(
                        flex: 2,
                        child: _buildGlossSequenceSection(isMobile),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Video Player Section (ซ้าย 70%)
                      Expanded(
                        flex: 7,
                        child: _buildVideoPlayerSection(),
                      ),
                      const SizedBox(width: 32),
                      // Gloss Sequence Section (ขวา 30%)
                      Expanded(
                        flex: 3,
                        child: _buildGlossSequenceSection(isMobile),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}