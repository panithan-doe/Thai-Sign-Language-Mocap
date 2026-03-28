import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/motion_loader.dart';
import '../utils/vocab_mapper.dart';
import '../constants/api_constants.dart';
import 'player_screen.dart';
import 'dictionary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final VocabMapper _vocabMapper = VocabMapper();
  late final MotionLoader _motionLoader;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _motionLoader = MotionLoader(
      baseUrl: ApiConstants.cloudflareR2StorageBaseUrl,
      localPath: ApiConstants.motionLocalPath,
      useLocal: ApiConstants.useLocalMotionStorage,
    );
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
    });

    try {
      // Step 1: Tokenize with Gemini (return List<WordToken> พร้อม variant)
      final geminiService = GeminiService(glossMap: _vocabMapper.glossMap);
      final tokens = await geminiService.tokenize(inputText);

      // Step 2: Merge consecutive unknown tokens into STILL
      final mergedSequence = VocabMapper.mergeConsecutiveStillTokens(tokens);

      // Step 3: Load motions using tokens (with variant support)
      final motions = await _motionLoader.preloadMotionsFromTokens(mergedSequence.mergedTokens);

      setState(() {
        _isLoading = false;
      });

      // ตรวจสอบเพื่อดัก Error กรณีไม่พบข้อมูลใดๆ เลย
      if (motions.isEmpty && mergedSequence.mergedTokens.isNotEmpty) {
        setState(() {
          _errorMessage = 'ไม่พบข้อมูล Motion สำหรับข้อความนี้';
        });
        return;
      }

      // นำทางไปยัง PlayerScreen ทันทีเมื่อโหลดเสร็จ
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              motionDataList: motions,
              tokens: tokens,
              mergedSequence: mergedSequence,
              originalText: inputText,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _isInitialized
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DictionaryScreen(),
                  ),
                );
                // Refresh vocab หลังกลับมา (กรณีมีการลบ/แก้ไขคำ)
                if (mounted) {
                  await _vocabMapper.loadVocab(forceRefresh: true);
                  setState(() {});
                }
              },
              backgroundColor: const Color(0xFF3B82F6),
              icon: const Icon(Icons.book, color: Colors.white),
              label: const Text(
                'คำศัพท์ในระบบ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}