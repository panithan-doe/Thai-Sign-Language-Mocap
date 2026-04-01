import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/motion_models.dart';

class GeminiService {
  final Map<String, dynamic> glossMap;

  /// validWords เก็บ keys ของ glossMap สำหรับ validation
  late final Set<String> _validWordsSet;

  /// API keys สำหรับการหมุนเวียนใช้งาน
  late final List<String> _apiKeys;

  /// ตำแหน่งปัจจุบันสำหรับ round-robin rotation
  int _currentKeyIndex = 0;

  GeminiService({required this.glossMap}) {
    _validWordsSet = glossMap.keys.toSet();
    _apiKeys = ApiConstants.geminiApiKeys;

    if (_apiKeys.isEmpty) {
      throw Exception('No Gemini API keys configured. Please add GEMINI_API_KEYS to .env');
    }

    print('GeminiService initialized with ${_apiKeys.length} API key(s)');
  }

  /// Get next API key using round-robin rotation
  String _getNextApiKey() {
    final key = _apiKeys[_currentKeyIndex];
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
    return key;
  }

  /// Tokenize ข้อความและ return List<WordToken> พร้อม variant ที่เลือก
  Future<List<WordToken>> tokenize(String inputText) async {
    final prompt = _buildPrompt(inputText);

    // เลือก API key แบบ round-robin
    final apiKey = _getNextApiKey();
    final endpoint = ApiConstants.geminiEndpointWithKey(apiKey);

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'topK': 1,
          'topP': 1,
          'maxOutputTokens': 8192,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
      print('=== GEMINI RESPONSE ===');
      print('Raw response: $text');
      final result = _parseResponse(text);
      print('Parsed result: $result');

      // Validate: ตรวจสอบและแก้ไขคำที่ไม่ถูกต้อง
      final validatedResult = _validateTokens(result);
      print('Validated result: $validatedResult');
      return validatedResult;
    } else {
      // ตรวจสอบ quota exceeded / rate limit errors
      final bodyLower = response.body.toLowerCase();
      if (response.statusCode == 429 ||
          bodyLower.contains('quota') ||
          bodyLower.contains('rate limit') ||
          bodyLower.contains('resource exhausted')) {
        throw Exception('ระบบมีการใช้งานเกินขีดจำกัดชั่วคราว กรุณาลองใหม่อีกครั้งในภายหลัง');
      }
      throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Validate WordToken ที่ Gemini return มา
  /// - ถ้า Gemini บอก unknown แต่คำมีใน glossMap → แก้เป็น known
  /// - ถ้าคำไม่มีใน glossMap → mark เป็น unknown
  /// - ถ้า variant ไม่มีจริง → fallback เป็น v1
  List<WordToken> _validateTokens(List<WordToken> tokens) {
    return tokens.map((token) {
      // ตรวจสอบว่าคำมีอยู่ใน glossMap หรือไม่
      final wordExists = _validWordsSet.contains(token.word);

      if (!wordExists) {
        // คำไม่มีใน vocabulary → mark เป็น unknown
        if (!token.isUnknown) {
          print('Word not in vocabulary: ${token.word} -> marking as unknown');
        }
        return WordToken.unknown(token.word);
      }

      // คำมีอยู่ใน vocabulary
      if (token.isUnknown) {
        // Gemini บอก unknown แต่คำมีจริง → แก้เป็น known
        print('Gemini marked "${token.word}" as unknown but it exists -> correcting to known');
      }

      // ตรวจสอบว่า variant มีอยู่จริงหรือไม่
      final wordVariants = glossMap[token.word] as Map<String, dynamic>?;
      String finalVariant = token.variant;
      if (wordVariants != null && !wordVariants.containsKey(token.variant)) {
        print('Variant ${token.variant} not found for ${token.word} -> fallback to v1');
        finalVariant = 'v1';
      }

      return WordToken(word: token.word, variant: finalVariant, isUnknown: false);
    }).toList();
  }

String _buildPrompt(String inputText) {
  final glossMapJson = jsonEncode(glossMap);

  return '''
    คุณคือผู้เชี่ยวชาญด้านภาษามือไทย (Thai Sign Language - TSL) และนักภาษาศาสตร์
    หน้าที่ของคุณคือรับประโยคภาษาไทยทั่วไป เลือกเฉพาะคำที่สื่อความหมาย และแปลงเป็น "ลำดับคำ (Gloss)" พร้อมเลือก variant ที่เหมาะสมกับบริบท

    **กฎการทำงาน (Strict Rules):**

    1. **ไวยากรณ์ (TSL Grammar) - ลำดับคำตามโครงสร้างภาษามือไทย:**
      - **เวลา** → ถ้านำมาด้านหน้า จะอยู่หน้าสุด (ก่อนสถานที่) หรือหลังสุดของประโยคก็ได้ แต่จะไม่อยู่หลังคำปฏิเสธ
      - **สถานที่** → อยู่ถัดจากเวลา (ถ้ามี) หรือหน้าสุด (ถ้าไม่มีเวลา)
      - **แกนหลักประโยค** → เรียงเป็น: **ประธาน + กรรม + กริยา (S+O+V) ** หรือ **กรรม + ประธาน + กริยา (O+S+V) ** ก็ได้
      - **คำคุณศัพท์** → วางต่อท้ายคำนามที่ถูกขยายเสมอ (เช่น ใหญ่, หอม, ดุ)
      - **คำวิเศษณ์** → วางต่อท้ายคำกริยาที่ถูกขยายเสมอ (เช่น ช้า, เร็ว, ดัง)
      - **คำปฏิเสธ** (เช่น ไม่, ไม่ใช่, ไม่ได้, ไม่มี, อย่า) → อยู่ด้านหลังประโยคเสมอ

      **ลำดับทั้งหมด:** "เวลา → สถานที่ → แกนหลักประโยค (S-O-V หรือ O-S-V) → คำปฏิเสธ" หรือ "สถานที่ → แกนหลักประโยค (S-O-V หรือ O-S-V) → เวลา → คำปฏิเสธ"
      
      **ตัวอย่าง:**
      - Input: "ฉันไม่กินข้าวที่โรงเรียนเมื่อวาน"
      - Output: ["เมื่อวาน", "โรงเรียน", "ข้าว", "ฉัน", "กิน", "ไม่"]
      - อธิบาย: เวลา (เมื่อวาน) → สถานที่ (โรงเรียน) → กรรม (ข้าว) → ประธาน (ฉัน) → กริยา (กิน) → ปฏิเสธ (ไม่)
      
      - Input: "เขาซื้อรถสีแดงคันใหม่ที่กรุงเทพเมื่อวาน"
      - Output: ["เมื่อวาน", "กรุงเทพ", "รถ", "สีแดง", "ใหม่", "เขา", "ซื้อ"]
      - อธิบาย: เวลา (เมื่อวาน) → สถานที่ (กรุงเทพ) → กรรม (รถ) → คุณศัพท์ (สีแดง, ใหม่) → ประธาน (เขา) → กริยา (ซื้อ)
      
      - Input: "พรุ่งนี้ฉันจะไปโรงพยาบาล"
      - Output: ["พรุ่งนี้", "โรงพยาบาล", "ฉัน", "ไป"]
      - อธิบาย: เวลา (พรุ่งนี้) → สถานที่ (โรงพยาบาล) → ประธาน (ฉัน) → กริยา (ไป)

    2. **ห้ามตัดคำประเภท: คำนาม, คำกริยา, คำสรรพนาม, คำวิเศษณ์, คำคุณศัพท์ ออกจากผลลัพธ์**

    3. **ตัดคำฟุ่มเฟือย (Stopword Removal):** ห้ามใส่คำบุพบท, คำสันธาน, คำอุทาน, และคำลงท้าย (เช่น ครับ, ค่ะ, นะ, จ๊ะ, ที่, ใน, กับ, และ, แต่, จะ) ลงในผลลัพธ์เด็ดขาด

    4. **บังคับใช้คลังคำศัพท์ (Strict Vocabulary Matching):** คุณต้องเลือกใช้คำศัพท์ที่มี key อยู่ใน [Vocabulary JSON] เท่านั้น

    5. **ถ้าคำใน inputText ตรงกับ key ใน JSON ให้เลือก key นั้นได้เลย**

    6. **จัดการคำพ้องความหมาย (Synonyms):** หากผู้ใช้พิมพ์คำที่ไม่มีใน JSON แต่มีความหมายใกล้เคียงกับ key ให้แปลงเป็น key นั้น เช่น รับประทาน → กิน, คำศัพท์ → คำ

    7. **คำที่ไม่พบ (Unknown Word):** หากหาคำไม่ได้เลย ให้ใส่ "unknown": true

    8. **ประโยคที่มีคำว่า "ยัง":** มักจะเป็นไปได้ 2 กรณี คือประโยคคำถามจะอยู่ท้ายประโยค ("คุณกินข้าวหรือยัง" → ข้าว คุณ กิน ยัง) และประโยคบอกเล่าจะถูกตัดทิ้ง ("คุณยังไม่กินข้าว" → ข้าว คุณ กิน ไม่)

    **การเลือก Variant:**
    - แต่ละคำใน JSON มี variant (v1, v2, ...) พร้อมคำอธิบายบริบท
    - **ถ้าบริบทมีความหมาย** (เช่น v1="ฝูงชน", v2="แยกย้ายกันไป") → วิเคราะห์ประโยคแล้วเลือก variant ที่เหมาะสม
    - **ถ้าบริบทไม่มีความหมาย** (เช่น v1="ท่าที่ 1", v2="ท่าที่ 2") → ให้ใช้ v1

    **รูปแบบผลลัพธ์ (Output Format):**
    ตอบกลับเป็น JSON Array ของ Object เท่านั้น:
    [
      {"word": "วันนี้", "variant": "v2"},
      {"word": "โรงเรียน", "variant": "v1"},
      {"word": "ข้าว", "variant": "v1"},
      {"word": "ฉัน", "variant": "v1"},
      {"word": "กิน", "variant": "v2"},
      {"word": "ไม่", "variant": "v1"}
    ]

    - "word": คำภาษาไทยที่เลือก (key จาก JSON)
    - "variant": variant ที่เลือก (v1, v2, ...)
    - "unknown": true ถ้าหาคำไม่ได้

    ห้ามพิมพ์ \`\`\`json หรือคำอธิบายใดๆ ทั้งสิ้น ตอบแค่ JSON Array เท่านั้น

    **[Vocabulary JSON]:**
    $glossMapJson

    **ประโยคที่ต้องแปลง:**
    "$inputText"
    ''';
  }


  /// Parse response จาก Gemini เป็น List<WordToken>
  List<WordToken> _parseResponse(String responseText) {
    // Clean the response text
    String cleaned = responseText.trim();

    // Remove markdown code blocks if present (handle various formats)
    // Pattern: ```json or ``` at start/end
    cleaned = cleaned.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*$', multiLine: true), '');
    cleaned = cleaned.trim();

    // Find JSON array - look for [ and ]
    final startIndex = cleaned.indexOf('[');
    final endIndex = cleaned.lastIndexOf(']');

    if (startIndex == -1) {
      throw Exception('No JSON array found. Cleaned response: $cleaned');
    }

    String jsonStr;
    if (endIndex == -1 || endIndex < startIndex) {
      // ไม่มี ] หรือ ] อยู่ก่อน [ → response อาจถูกตัด ให้ลองเพิ่ม ] เข้าไป
      print('Warning: JSON array may be incomplete, attempting to fix...');
      jsonStr = '${cleaned.substring(startIndex)}]';
    } else {
      jsonStr = cleaned.substring(startIndex, endIndex + 1);
    }

    try {
      final List<dynamic> parsed = jsonDecode(jsonStr);
      return parsed.map((item) {
        if (item is Map<String, dynamic>) {
          return WordToken.fromJson(item);
        } else if (item is String) {
          // Backward compatibility: ถ้าเป็น string ธรรมดา
          if (item.contains('[Unknown]')) {
            return WordToken.unknown(item);
          }
          return WordToken(word: item, variant: 'v1');
        }
        throw Exception('Unexpected item type: ${item.runtimeType}');
      }).toList();
    } catch (e) {
      // ลองแก้ไข JSON ที่ไม่สมบูรณ์ (object สุดท้ายถูกตัด)
      final fixedJson = _tryFixIncompleteJson(jsonStr);
      if (fixedJson != null) {
        try {
          final List<dynamic> parsed = jsonDecode(fixedJson);
          return parsed.map((item) {
            if (item is Map<String, dynamic>) {
              return WordToken.fromJson(item);
            } else if (item is String) {
              if (item.contains('[Unknown]')) {
                return WordToken.unknown(item);
              }
              return WordToken(word: item, variant: 'v1');
            }
            throw Exception('Unexpected item type: ${item.runtimeType}');
          }).toList();
        } catch (_) {
          // ยังไม่ได้อีก ให้ throw error เดิม
        }
      }
      throw Exception('JSON parse error: $e. Raw JSON: $jsonStr');
    }
  }

  /// พยายามแก้ไข JSON ที่ไม่สมบูรณ์ (ตัด object สุดท้ายที่ไม่สมบูรณ์ออก)
  String? _tryFixIncompleteJson(String jsonStr) {
    // หา comma สุดท้ายก่อน object ที่ไม่สมบูรณ์
    final lastCompleteObjectEnd = jsonStr.lastIndexOf('},');
    if (lastCompleteObjectEnd != -1) {
      // ตัดตรง }, แล้วเพิ่ม ] ปิด
      return '${jsonStr.substring(0, lastCompleteObjectEnd + 1)}]';
    }

    // หา } สุดท้าย
    final lastBrace = jsonStr.lastIndexOf('}');
    if (lastBrace != -1) {
      return '${jsonStr.substring(0, lastBrace + 1)}]';
    }

    return null;
  }
}
