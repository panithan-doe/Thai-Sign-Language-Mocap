import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../widgets/thai_alphabet_filter.dart';
import '../widgets/word_card.dart';
import '../utils/vocab_mapper.dart';
import 'add_word_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final BackendService _backendService = BackendService();
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic> _glossMap = {};
  List<MapEntry<String, dynamic>> _filteredWords = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedLetter;

  final VocabMapper _vocabMapper = VocabMapper();

  // สระนำหน้าที่ต้องข้ามเพื่อหาพยัญชนะต้น (เหมือน motion_loader.dart)
  static const Set<String> _leadingVowels = {'เ', 'แ', 'โ', 'ไ', 'ใ'};

  @override
  void initState() {
    super.initState();
    _loadGlossMap();
    _searchController.addListener(_filterWords);
  }

  /// หาพยัญชนะต้นของคำไทย (ข้ามสระนำหน้า เ-, แ-, โ-, ไ-, ใ-)
  /// เช่น "เวียดนาม" → "ว", "แม่" → "ม", "แก้ว" → "ก"
  String _getInitialConsonant(String word) {
    if (word.isEmpty) return '';

    // ถ้าตัวแรกเป็นสระนำหน้า ให้ใช้ตัวที่ 2 (ถ้ามี)
    if (_leadingVowels.contains(word[0]) && word.length > 1) {
      return word[1];
    }
    return word[0];
  }

  Future<void> _loadGlossMap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _backendService.getGlossMap();
      final glossMap = response['gloss_map'] as Map<String, dynamic>;

      setState(() {
        _glossMap = glossMap;
        _filteredWords = glossMap.entries.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูลได้: $e';
        _isLoading = false;
      });
    }
  }

  void _filterWords() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredWords = _glossMap.entries.where((entry) {
        final word = entry.key.toLowerCase();

        // Filter by search query
        if (query.isNotEmpty && !word.contains(query)) {
          return false;
        }

        // Filter by selected letter
        if (_selectedLetter != null) {
          if (_selectedLetter == '#') {
            // Non-Thai characters
            final initialConsonant = _getInitialConsonant(word);
            if (initialConsonant.isEmpty) return true;
            final isThaiChar = initialConsonant.codeUnitAt(0) >= 0x0E01 &&
                              initialConsonant.codeUnitAt(0) <= 0x0E5B;
            return !isThaiChar;
          } else {
            // Specific Thai letter (ใช้พยัญชนะต้นแทนตัวอักษรแรก)
            final initialConsonant = _getInitialConsonant(word);
            return initialConsonant == _selectedLetter!.toLowerCase();
          }
        }

        return true;
      }).toList();

      // Sort alphabetically
      _filteredWords.sort((a, b) => a.key.compareTo(b.key));
    });
  }

  void _onLetterSelected(String? letter) {
    setState(() {
      _selectedLetter = letter;
      _filterWords();
    });
  }

  Future<void> _onWordDeleted(String word, String variant) async {
    // Reload gloss map after deletion
    await _loadGlossMap();
    // Refresh vocab mapper cache
    await _vocabMapper.loadVocab(forceRefresh: true);
  }

  Future<void> _onWordUpdated(String word, String variant) async {
    // Reload gloss map after update
    await _loadGlossMap();
    // Refresh vocab mapper cache
    await _vocabMapper.loadVocab(forceRefresh: true);
  }

  Future<void> _navigateToAddWord() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddWordScreen(),
      ),
    );
    // Refresh gloss map และ vocab เมื่อเพิ่มคำใหม่สำเร็จ
    if (result == true && mounted) {
      await _loadGlossMap();
      await _vocabMapper.loadVocab(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text(
                'คำศัพท์ในระบบ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                children: [
                  // Gradient background
                  Container(
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
                  ),
                  // ปุ่มเพิ่มคำศัพท์ (มุมล่างขวา)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: TextButton.icon(
                      onPressed: _navigateToAddWord,
                      icon: const Icon(Icons.add, color: Colors.white, size: 20),
                      label: const Text(
                        'เพิ่มคำศัพท์ใหม่',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาคำศัพท์...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey.shade400,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey.shade400),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ),

          // Thai Alphabet Filter
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ThaiAlphabetFilter(
                selectedLetter: _selectedLetter,
                onLetterSelected: _onLetterSelected,
              ),
            ),
          ),

          // Word count header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.book, color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'พบ ${_filteredWords.length} คำ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // if (_selectedLetter != null) ...[
                  //   const SizedBox(width: 8),
                  //   Container(
                  //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  //     decoration: BoxDecoration(
                  //       color: const Color(0xFF3B82F6).withOpacity(0.1),
                  //       borderRadius: BorderRadius.circular(8),
                  //     ),
                  //     child: Text(
                  //       _selectedLetter == '#' ? 'อื่นๆ' : 'ตัว $_selectedLetter',
                  //       style: const TextStyle(
                  //         fontSize: 12,
                  //         color: Color(0xFF3B82F6),
                  //         fontWeight: FontWeight.w600,
                  //       ),
                  //     ),
                  //   ),
                  // ],
                ],
              ),
            ),
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2563EB)),
                    SizedBox(height: 16),
                    Text(
                      'กำลังโหลดพจนานุกรม...',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: Center(
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
                        onPressed: _loadGlossMap,
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
              ),
            )
          else if (_filteredWords.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      color: Colors.grey.shade400,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ไม่พบคำศัพท์',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ลองค้นหาด้วยคำอื่น',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = _filteredWords[index];
                    final word = entry.key;
                    final variants = entry.value as Map<String, dynamic>;

                    return WordCard(
                      word: word,
                      variants: variants,
                      onDeleted: _onWordDeleted,
                      onUpdated: _onWordUpdated,
                    );
                  },
                  childCount: _filteredWords.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
