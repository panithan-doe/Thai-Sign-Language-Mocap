import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/motion_loader.dart';
import '../utils/vocab_mapper.dart';
import '../constants/api_constants.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final VocabMapper _vocabMapper = VocabMapper();
  late final MotionLoader _motionLoader;

  List<String> _thaiTokens = [];
  List<String> _englishGloss = [];
  List<MotionData> _motionDataList = [];
  MergedSequence? _mergedSequence; // ผลลัพธ์จากการ merge consecutive STILL
  bool _isLoading = false;
  bool _isLoadingMotions = false;
  String? _errorMessage;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _motionLoader =
        MotionLoader(baseUrl: ApiConstants.cloudflareR2StorageBaseUrl);
    _initVocab();
  }

  Future<void> _initVocab() async {
    await _vocabMapper.loadVocab();
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _processText() async {
    final inputText = _textController.text.trim();
    if (inputText.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณาใส่ข้อความ';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _thaiTokens = [];
      _englishGloss = [];
      _motionDataList = [];
      _mergedSequence = null;
    });

    try {
      // Step 1: Tokenize with Gemini
      final geminiService = GeminiService(validWords: _vocabMapper.thaiWords);
      final tokens = await geminiService.tokenize(inputText);
      final englishGloss = _vocabMapper.mapThaiToEnglish(tokens);

      // Step 2: Merge consecutive STILL
      final mergedSequence = VocabMapper.mergeConsecutiveStill(tokens, englishGloss);

      setState(() {
        _thaiTokens = tokens;
        _englishGloss = englishGloss;
        _mergedSequence = mergedSequence;
      });

      // Step 3: Auto-load motions (using merged gloss to reduce API calls)
      setState(() {
        _isLoadingMotions = true;
      });

      final motions = await _motionLoader.preloadMotions(mergedSequence.mergedGloss);

      setState(() {
        _motionDataList = motions;
        _isLoading = false;
        _isLoadingMotions = false;
      });

      // แจ้งเตือนถ้ามี gloss ที่หา motion ไม่เจอ
      if (motions.length < mergedSequence.mergedGloss.length) {
        final missing = mergedSequence.mergedGloss.where((g) {
          final expectedGloss = g.isEmpty ? 'STILL' : g;
          return !motions.any((m) => m.gloss == expectedGloss);
        }).toList();
        if (missing.isNotEmpty) {
          setState(() {
            _errorMessage =
                'ไม่พบ motion สำหรับ: ${missing.map((g) => g.isEmpty ? "(STILL)" : g).join(", ")}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: $e';
        _isLoading = false;
        _isLoadingMotions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: !_isInitialized
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF2563EB),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'กำลังโหลดคลังคำศัพท์...',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // Modern App Bar with gradient
                SliverAppBar(
                  expandedHeight: 120,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: const Text(
                      'Thai Sign Language - Mocap',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF3B82F6),
                            Color(0xFF1D4ED8),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -50,
                            top: -50,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -30,
                            bottom: -30,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Input Section
                        _buildInputSection(),

                        const SizedBox(height: 24),

                        // Error Message
                        if (_errorMessage != null) _buildErrorMessage(),

                        // Results Section
                        if (_thaiTokens.isNotEmpty) ...[
                          _buildResultsSection(),
                        ],

                        // Loading Motions
                        if (_isLoadingMotions) _buildLoadingMotions(),

                        // Motion Data Section
                        if (_motionDataList.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildMotionSection(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.translate,
                  color: Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'แปลงข้อความเป็นภาษามือ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: 'พิมพ์ข้อความภาษาไทยที่นี่...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(
                Icons.edit_note,
                color: Colors.grey.shade400,
              ),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF3B82F6), width: 2),
              ),
            ),
            maxLines: 1,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _processText,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF93C5FD),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'ประมวลผล',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFDC2626),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ดึงรายการคำที่ไม่พบใน vocab
  List<String> _getUnknownWords() {
    return _thaiTokens
        .where((word) => VocabMapper.isUnknownWord(word))
        .map((word) => VocabMapper.extractWord(word))
        .toList();
  }

  Widget _buildResultsSection() {
    final unknownWords = _getUnknownWords();

    return Column(
      children: [
        // แสดง warning ถ้ามีคำที่ไม่พบใน vocab

        _buildThaiTokensCard(),
        const SizedBox(height: 16),
        _buildEnglishGlossCard(),
        const SizedBox(height: 16),
        if (unknownWords.isNotEmpty) _buildUnknownWordsWarning(unknownWords),
      ],
    );
  }

  Widget _buildUnknownWordsWarning(List<String> unknownWords) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD97706),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ไม่พบ motion สำหรับคำเหล่านี้',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unknownWords.map((w) => '"$w"').join(', '),
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'คำเหล่านี้จะแสดงเป็นท่ายืนนิ่ง (STILL)',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThaiTokensCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.text_fields,
                    color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'คำภาษาไทย',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  Text(
                    'Thai Tokens',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _thaiTokens.map((word) {
              final isUnknown = VocabMapper.isUnknownWord(word);
              final displayWord =
                  isUnknown ? VocabMapper.extractWord(word) : word;

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isUnknown
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnknown
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF3B82F6).withAlpha(76),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // if (isUnknown) ...[
                    //   const Icon(
                    //     Icons.help_outline,
                    //     color: Color(0xFFDC2626),
                    //     size: 14,
                    //   ),
                    //   const SizedBox(width: 4),
                    // ],
                    Text(
                      displayWord,
                      style: TextStyle(
                        color: isUnknown
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnglishGlossCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.code, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'รหัสท่าทาง',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    'English Gloss',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_englishGloss.length, (index) {
              final gloss = _englishGloss[index];
              final thaiWord = _thaiTokens[index];
              final isUnknown = VocabMapper.isUnknownWord(thaiWord);

              // ถ้าเป็นคำที่ไม่พบ จะแสดงเป็น STILL
              final displayGloss = gloss.isEmpty ? 'STILL' : gloss;

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isUnknown
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUnknown
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF10B981).withAlpha(76),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // if (isUnknown) ...[
                    //   const Icon(
                    //       Icons.accessibility_new,
                    //     color: Color(0xFFDC2626),
                    //     size: 14,
                    //   ),
                    //   const SizedBox(width: 4),
                    // ],
                    Text(
                      displayGloss,
                      style: TextStyle(
                        color: isUnknown
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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

  Widget _buildLoadingMotions() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'กำลังโหลด Motion Data...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'กรุณารอสักครู่',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motion Data พร้อมใช้งาน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'โหลดสำเร็จทั้งหมด',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._motionDataList.map((motion) => _buildMotionCard(motion)),
        const SizedBox(height: 24),

        // Play Animation Button
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                    motionDataList: _motionDataList,
                    thaiTokens: _thaiTokens,
                    mergedSequence: _mergedSequence!,
                    originalText: _textController.text.trim(),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_filled, size: 28, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'เล่น Animation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMotionCard(MotionData motion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.accessibility_new,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  motion.gloss,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  motion.isStill ? 'ท่ายืนนิ่ง' : 'ท่าทางภาษามือ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.layers,
                  color: Color(0xFF3B82F6),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${motion.totalFrames}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
