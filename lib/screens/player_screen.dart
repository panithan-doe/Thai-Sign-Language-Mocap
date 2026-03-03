import 'package:flutter/material.dart';
import '../models/motion_models.dart';
import '../widgets/motion_player.dart';
import '../services/motion_loader.dart';
import '../utils/vocab_mapper.dart';

class PlayerScreen extends StatefulWidget {
  final List<MotionData> motionDataList;
  final List<String> thaiTokens; // รายการคำภาษาไทยจาก Gemini (original)
  final MergedSequence mergedSequence; // ข้อมูลที่ merge แล้ว
  final String originalText; // ข้อความต้นฉบับที่ผู้ใช้ป้อนเข้ามา

  const PlayerScreen({
    super.key,
    required this.motionDataList,
    required this.thaiTokens,
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
  int _currentClipIndex = 0; // track คำที่กำลังเล่นอยู่

  double _playbackFps = 50.0;

  @override
  void initState() {
    super.initState();
    _buildSequence();
  }

  void _buildSequence() {
    try {
      final clips = <MotionClip>[];

      for (final motionData in widget.motionDataList) {
        final clip = MotionClip.fromJson(
          motionData.motionJson,
          motionData.gloss,
          isStill: motionData.isStill,
        );
        clips.add(clip);
      }

      setState(() {
        _sequence = MotionSequence(clips: clips);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error building sequence: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(25),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Animation Player',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(), 
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildBody(),
          ),
        ],
      ),
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
            Text(
              'กำลังเตรียม Animation...',
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
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withAlpha(25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Color(0xFFDC2626),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'เกิดข้อผิดพลาด',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_sequence == null || _sequence!.clips.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              const Text(
                'ไม่มีข้อมูล Motion',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24), 
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ================= ฝั่งซ้าย: เครื่องเล่น Animation =================
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withAlpha(20),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.blue.shade50, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: MotionPlayer(
                    sequence: _sequence!,
                    autoPlay: false,
                    playbackFps: _playbackFps,
                    thaiGroups: widget.mergedSequence.thaiGroups,
                    onClipChange: (clipIndex) {
                      setState(() {
                        _currentClipIndex = clipIndex;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 24),

          // ================= ฝั่งขวา: Context & Controls ในกล่องใหญ่กล่องเดียว =================
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withAlpha(20),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.blue.shade50, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Title ของฝั่งขวา ---
                      const Row(
                        children: [
                          // Icon(Icons.analytics_outlined, color: Color(0xFF3B82F6), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'รายละเอียด',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),

                      // 1. กล่องข้อความต้นฉบับ
                      _buildOriginalTextCard(),
                      const SizedBox(height: 16),

                      // 2. Info Cards (รวม Motion, Frame, FPS เรียงแนวนอน 3 กล่อง)
                      _buildInfoCards(),
                      const SizedBox(height: 16),

                      // 3. พื้นที่ Scroll ได้ สำหรับ Lists ด้านล่าง
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildGlossChips(),
                              const SizedBox(height: 8),
                              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 8),
                              _buildDatabaseGlossBox(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildInfoCard(
              icon: Icons.accessibility_new_outlined,
              title: 'Total motions',
              value: '${_sequence!.clips.length}',
              unit: 'motions',
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInfoCard(
              icon: Icons.layers_outlined,
              title: 'Total frames',
              value: '${_sequence!.totalFrames}',
              unit: 'frames',
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFpsCompactCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
    Widget? bottomWidget,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // ปรับเป็นสีเทาอ่อนๆ เพื่อให้แยกจากพื้นหลังหลัก
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (bottomWidget != null) ...[
            const Spacer(),
            const SizedBox(height: 8),
            bottomWidget,
          ]
        ],
      ),
    );
  }

  Widget _buildFpsCompactCard() {
    return _buildInfoCard(
      icon: Icons.speed_outlined,
      title: 'Frame rate',
      value: '${_playbackFps.round()}',
      unit: 'fps',
      color: const Color(0xFF8B5CF6),
      bottomWidget: SizedBox(
        height: 20,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF8B5CF6),
            inactiveTrackColor: const Color(0xFFEDE9FE),
            thumbColor: const Color(0xFF7C3AED),
            trackHeight: 3.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
          ),
          child: Slider(
            value: _playbackFps,
            min: 5.0,
            max: 60.0,
            divisions: 11,
            onChanged: (value) {
              setState(() {
                _playbackFps = value;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGlossChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8), // ลด padding เดิมออก
      decoration: const BoxDecoration(
        color: Colors.transparent, 
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.accessibility_new,
                color: Colors.blue,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'ลำดับท่าทาง',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(widget.thaiTokens.length, (index) {
              final thaiWord = widget.thaiTokens[index];
              final isUnknown = VocabMapper.isUnknownWord(thaiWord);
              final displayWord = isUnknown
                  ? VocabMapper.extractWord(thaiWord)
                  : thaiWord;

              final currentOriginalIndices = _currentClipIndex <
                      widget.mergedSequence.originalIndices.length
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: isCurrentlyPlaying ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: numberBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayWord,
                      style: TextStyle(
                        color: textColor,
                        fontWeight:
                            isCurrentlyPlaying ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalTextCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // พื้นหลังอ่อนๆ ไม่กลืนกับสีขาวหลัก
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.format_quote, color: Color(0xFF3B82F6), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'ข้อความต้นฉบับ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.originalText,
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseGlossBox() {
    final dbGlosses = widget.mergedSequence.mergedGloss;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8), // ลด padding เดิมออก
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.data_object,
                color: Colors.purple,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Database Lookup Gloss',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(dbGlosses.length, (index) {
              final gloss = dbGlosses[index];
              final displayGloss = gloss.isEmpty ? 'STILL' : gloss;
              final isCurrentlyPlaying = index == _currentClipIndex;

              final bgColor = isCurrentlyPlaying ? Colors.purple.shade600 : Colors.purple.shade50;
              final textColor = isCurrentlyPlaying ? Colors.white : Colors.purple.shade700;
              final borderColor = isCurrentlyPlaying ? Colors.purple.shade600 : Colors.purple.shade200;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: isCurrentlyPlaying ? 2 : 1),
                ),
                child: Text(
                  displayGloss,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.w600,
                    color: textColor,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}