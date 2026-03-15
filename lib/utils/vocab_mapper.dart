import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/motion_models.dart';

/// ผลลัพธ์จากการ merge consecutive STILL (รองรับ WordToken)
class MergedTokenSequence {
  /// กลุ่มคำภาษาไทยสำหรับแสดงผล - แต่ละ element คือ list ของคำที่ map กับ clip นั้น
  /// เช่น [["ประเทศอังกฤษ"], ["ไป", "หนังสือ"], ["สอน"]]
  final List<List<String>> thaiGroups;

  /// WordToken ที่ merge แล้ว สำหรับ lookup motion (มี word + variant)
  /// Unknown tokens จะถูก merge เป็น STILL token เดียว
  final List<WordToken> mergedTokens;

  /// mapping จาก clip index → original indices ใน tokens เดิม
  /// เช่น [[0], [1, 2], [3]] หมายความว่า clip 1 มาจาก original index 1 และ 2
  final List<List<int>> originalIndices;

  MergedTokenSequence({
    required this.thaiGroups,
    required this.mergedTokens,
    required this.originalIndices,
  });

  /// คำแสดงผลทั้งหมด (รวม [Unknown] suffix)
  List<String> get displayWords => mergedTokens.map((t) => t.displayWord).toList();
}

/// ผลลัพธ์จากการ merge consecutive STILL (Legacy - รองรับ String)
class MergedSequence {
  /// กลุ่มคำภาษาไทยสำหรับแสดงผล - แต่ละ element คือ list ของคำที่ map กับ clip นั้น
  /// เช่น [["ประเทศอังกฤษ"], ["ไป", "หนังสือ"], ["สอน"]]
  final List<List<String>> thaiGroups;

  /// คำภาษาไทยที่ merge แล้ว สำหรับ lookup motion ใน R2
  /// เช่น ["ประเทศอังกฤษ", "", "สอน"] (empty string = STILL)
  final List<String> mergedThaiWords;

  /// mapping จาก clip index → original indices ใน thaiTokens เดิม
  /// เช่น [[0], [1, 2], [3]] หมายความว่า clip 1 มาจาก original index 1 และ 2
  final List<List<int>> originalIndices;

  MergedSequence({
    required this.thaiGroups,
    required this.mergedThaiWords,
    required this.originalIndices,
  });
}

class VocabMapper {
  List<String> _thaiWords = [];
  Map<String, dynamic> _glossMap = {};
  bool _isLoaded = false;

  /// โหลดคลังคำศัพท์จาก gloss_map.json บน R2
  /// forceRefresh: บังคับโหลดใหม่จาก R2 (สำหรับหลังเพิ่มคำใหม่)
  Future<void> loadVocab({bool forceRefresh = false}) async {
    if (_isLoaded && !forceRefresh) return;

    // โหลดจาก Cloudflare R2 (เพิ่ม timestamp เพื่อป้องกัน browser cache)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final r2Url = '${ApiConstants.cloudflareR2StorageBaseUrl}/gloss_map.json?t=$timestamp';
    final response = await http.get(Uri.parse(r2Url));

    if (response.statusCode != 200) {
      throw Exception('ไม่สามารถโหลดคลังคำศัพท์ได้ (status: ${response.statusCode})');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    _glossMap = data['gloss_map'] as Map<String, dynamic>;

    // ดึงเฉพาะ keys (คำภาษาไทย) จาก gloss_map
    _thaiWords = _glossMap.keys.toList();
    _isLoaded = true;
  }

  List<String> get thaiWords => _thaiWords;

  /// Full glossMap พร้อมบริบทของแต่ละคำ
  Map<String, dynamic> get glossMap => _glossMap;

  /// ตรวจสอบว่าคำมี [Unknown] suffix หรือไม่
  static bool isUnknownWord(String word) {
    return word.contains('[Unknown]');
  }

  /// ดึงคำจริงออกจากคำที่มี [Unknown] suffix
  /// เช่น "กรุงเทพ [Unknown]" -> "กรุงเทพ"
  static String extractWord(String word) {
    if (isUnknownWord(word)) {
      return word.replaceAll(' [Unknown]', '').replaceAll('[Unknown]', '').trim();
    }
    return word;
  }

  /// Merge consecutive unknown tokens into a single STILL
  ///
  /// Input:
  /// - tokens: [WordToken(ครู, v1), WordToken(ไป, unknown), WordToken(หนังสือ, unknown), WordToken(สอน, v2)]
  ///
  /// Output (MergedTokenSequence):
  /// - thaiGroups: [["ครู"], ["ไป", "หนังสือ"], ["สอน"]]
  /// - mergedTokens: [WordToken(ครู, v1), WordToken(STILL), WordToken(สอน, v2)]
  /// - originalIndices: [[0], [1, 2], [3]]
  static MergedTokenSequence mergeConsecutiveStillTokens(List<WordToken> tokens) {
    final List<List<String>> thaiGroups = [];
    final List<WordToken> mergedTokens = [];
    final List<List<int>> originalIndices = [];

    List<String> currentGroup = [];
    List<int> currentIndices = [];

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      if (token.isUnknown) {
        // เป็น unknown/STILL → สะสมลงใน group
        currentGroup.add(token.word);
        currentIndices.add(i);
      } else {
        // เป็นคำปกติ → ถ้ามี group สะสมอยู่ ให้ flush ก่อน
        if (currentGroup.isNotEmpty) {
          thaiGroups.add(List.from(currentGroup));
          // สร้าง STILL token (word ว่าง)
          mergedTokens.add(WordToken(word: '', variant: 'v1', isUnknown: true));
          originalIndices.add(List.from(currentIndices));
          currentGroup.clear();
          currentIndices.clear();
        }

        // เพิ่มคำปกติ
        thaiGroups.add([token.word]);
        mergedTokens.add(token);
        originalIndices.add([i]);
      }
    }

    // ถ้ามี group หลงเหลือที่ท้าย sequence
    if (currentGroup.isNotEmpty) {
      thaiGroups.add(List.from(currentGroup));
      mergedTokens.add(WordToken(word: '', variant: 'v1', isUnknown: true));
      originalIndices.add(List.from(currentIndices));
    }

    return MergedTokenSequence(
      thaiGroups: thaiGroups,
      mergedTokens: mergedTokens,
      originalIndices: originalIndices,
    );
  }

  /// Legacy: Merge consecutive STILL (unknown words) into a single STILL
  /// รองรับ List<String> แบบเดิม
  static MergedSequence mergeConsecutiveStill(List<String> thaiTokens) {
    final List<List<String>> thaiGroups = [];
    final List<String> mergedThaiWords = [];
    final List<List<int>> originalIndices = [];

    List<String> currentGroup = [];
    List<int> currentIndices = [];

    for (int i = 0; i < thaiTokens.length; i++) {
      final thaiWord = thaiTokens[i];
      // ดึงคำภาษาไทยจริงๆ (ไม่รวม [Unknown] suffix)
      final cleanThaiWord = extractWord(thaiWord);
      final isUnknown = isUnknownWord(thaiWord);

      if (isUnknown) {
        // เป็น unknown/STILL → สะสมลงใน group
        currentGroup.add(cleanThaiWord);
        currentIndices.add(i);
      } else {
        // เป็นคำปกติ → ถ้ามี group สะสมอยู่ ให้ flush ก่อน
        if (currentGroup.isNotEmpty) {
          thaiGroups.add(List.from(currentGroup));
          mergedThaiWords.add(''); // empty string = STILL
          originalIndices.add(List.from(currentIndices));
          currentGroup.clear();
          currentIndices.clear();
        }

        // เพิ่มคำปกติ - ใช้ cleanThaiWord สำหรับ lookup
        thaiGroups.add([cleanThaiWord]);
        mergedThaiWords.add(cleanThaiWord);
        originalIndices.add([i]);
      }
    }

    // ถ้ามี group หลงเหลือที่ท้าย sequence
    if (currentGroup.isNotEmpty) {
      thaiGroups.add(List.from(currentGroup));
      mergedThaiWords.add(''); // empty string = STILL
      originalIndices.add(List.from(currentIndices));
    }

    return MergedSequence(
      thaiGroups: thaiGroups,
      mergedThaiWords: mergedThaiWords,
      originalIndices: originalIndices,
    );
  }
}
