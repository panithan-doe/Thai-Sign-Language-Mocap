import 'dart:convert';
import 'package:flutter/services.dart';

/// ผลลัพธ์จากการ merge consecutive STILL
class MergedSequence {
  /// กลุ่มคำภาษาไทยสำหรับแสดงผล - แต่ละ element คือ list ของคำที่ map กับ clip นั้น
  /// เช่น [["ประเทศอังกฤษ"], ["ไป", "หนังสือ"], ["สอน"]]
  final List<List<String>> thaiGroups;

  /// English gloss ที่ merge แล้ว สำหรับ lookup motion
  /// เช่น ["ENGLISH", "", "TEACH"] (empty string = STILL)
  final List<String> mergedGloss;

  /// mapping จาก clip index → original indices ใน thaiTokens เดิม
  /// เช่น [[0], [1, 2], [3]] หมายความว่า clip 1 มาจาก original index 1 และ 2
  final List<List<int>> originalIndices;

  MergedSequence({
    required this.thaiGroups,
    required this.mergedGloss,
    required this.originalIndices,
  });
}

class VocabMapper {
  Map<String, String> _thaiToEnglish = {};
  List<String> _thaiWords = [];
  bool _isLoaded = false;

  Future<void> loadVocab() async {
    if (_isLoaded) return;

    final jsonString = await rootBundle.loadString('thai_eng_vocab.json');
    final List<dynamic> vocabList = jsonDecode(jsonString);

    for (final item in vocabList) {
      final thai = item['thai'] as String;
      final english = item['english'] as String;
      _thaiToEnglish[thai] = english;
      _thaiWords.add(thai);
    }

    _isLoaded = true;

  }

  List<String> get thaiWords => _thaiWords;

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

  List<String> mapThaiToEnglish(List<String> thaiWords) {
    return thaiWords.map((word) {
      // ถ้าเป็น empty string → ส่งต่อเป็น empty string (สำหรับ STILL animation)
      if (word.isEmpty) {
        return '';
      }
      // ถ้าคำมี [Unknown] suffix → ใช้ STILL animation
      if (isUnknownWord(word)) {
        return ''; // empty string จะถูก map เป็น STILL ใน motion_loader
      }
      return _thaiToEnglish[word] ?? '';
    }).toList();
  }

  String? getEnglish(String thaiWord) {
    return _thaiToEnglish[thaiWord];
  }

  /// Merge consecutive STILL (unknown words) into a single STILL
  ///
  /// Input:
  /// - thaiTokens: ["ประเทศอังกฤษ", "ไป [Unknown]", "หนังสือ [Unknown]", "สอน"]
  /// - englishGloss: ["ENGLISH", "", "", "TEACH"]
  ///
  /// Output (MergedSequence):
  /// - thaiGroups: [["ประเทศอังกฤษ"], ["ไป", "หนังสือ"], ["สอน"]]
  /// - mergedGloss: ["ENGLISH", "", "TEACH"]
  /// - originalIndices: [[0], [1, 2], [3]]
  static MergedSequence mergeConsecutiveStill(
    List<String> thaiTokens,
    List<String> englishGloss,
  ) {
    final List<List<String>> thaiGroups = [];
    final List<String> mergedGloss = [];
    final List<List<int>> originalIndices = [];

    List<String> currentGroup = [];
    List<int> currentIndices = [];

    for (int i = 0; i < englishGloss.length; i++) {
      final gloss = englishGloss[i];
      final thaiWord = thaiTokens[i];
      // ดึงคำภาษาไทยจริงๆ (ไม่รวม [Unknown] suffix)
      final cleanThaiWord = extractWord(thaiWord);

      if (gloss.isEmpty) {
        // เป็น unknown/STILL → สะสมลงใน group
        currentGroup.add(cleanThaiWord);
        currentIndices.add(i);
      } else {
        // เป็นคำปกติ → ถ้ามี group สะสมอยู่ ให้ flush ก่อน
        if (currentGroup.isNotEmpty) {
          thaiGroups.add(List.from(currentGroup));
          mergedGloss.add(''); // empty string = STILL
          originalIndices.add(List.from(currentIndices));
          currentGroup.clear();
          currentIndices.clear();
        }

        // เพิ่มคำปกติ
        thaiGroups.add([cleanThaiWord]);
        mergedGloss.add(gloss);
        originalIndices.add([i]);
      }
    }

    // ถ้ามี group หลงเหลือที่ท้าย sequence
    if (currentGroup.isNotEmpty) {
      thaiGroups.add(List.from(currentGroup));
      mergedGloss.add(''); // empty string = STILL
      originalIndices.add(List.from(currentIndices));
    }

    return MergedSequence(
      thaiGroups: thaiGroups,
      mergedGloss: mergedGloss,
      originalIndices: originalIndices,
    );
  }
}
