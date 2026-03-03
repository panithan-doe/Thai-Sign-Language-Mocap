import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class GeminiService {
  final List<String> validWords;

  GeminiService({required this.validWords});

  Future<List<String>> tokenize(String inputText) async {
    // Debug: Log the valid words being sent

    final prompt = _buildPrompt(inputText);

    final response = await http.post(
      Uri.parse(ApiConstants.geminiEndpoint),
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
          'maxOutputTokens': 2048,
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
      return result;
    } else {
      throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
    }
  }

  String _buildPrompt(String inputText) {
    final wordListStr = validWords.join(', ');

    return '''
      คุณคือผู้เชี่ยวชาญด้านภาษามือไทย (Thai Sign Language - TSL) และนักภาษาศาสตร์
      หน้าที่ของคุณคือรับประโยคภาษาไทยทั่วไป และแปลงเป็น "ลำดับคำ (Gloss)" เพื่อนำไปเล่นข้อมูลการเคลื่อนไหวแบบต่อเนื่อง

      **กฎการทำงาน (Strict Rules):**
      1. **ไวยากรณ์ (TSL Grammar):** ให้สลับตำแหน่งคำตามโครงสร้างภาษามือไทย มักเรียงลำดับเป็น: เวลา + สถานที่ + ประธาน + กรรม + กริยา + สรรพนาม (หรือ หัวเรื่อง + คำอธิบาย)
      2. **ห้ามตัดคำประเภท คำนาม คำกริยา คำสรรพนาม และคำวิเศษณ์ ออกจากผลลัพธ์**
      3. **ตัดคำฟุ่มเฟือย (Stopword Removal):** ห้ามใส่คำบุพบท, คำสันธาน, คำอุทาน, และคำลงท้าย (เช่น ครับ, ค่ะ, นะ, จ๊ะ) ลงในผลลัพธ์เด็ดขาด
      4. **บังคับใช้คลังคำศัพท์ (Strict Vocabulary Matching):** คุณต้องเลือกใช้คำศัพท์ที่มีอยู่ใน [Vocabulary List] ที่แนบมาให้เท่านั้น
      5. **ถ้าเกิดว่าคำที่มีอยู่ใน inputText ตรงเป๊ะๆ กับคำนั้นๆ ที่มีอยู่ใน [Vocabulary List] ให้เลือกคำใน Vocabulary List คำนั้นมาได้เลย เพราะว่าคำใน inputText มันตรงกับคำใน [Vocabulary List]**
      6. **จัดการคำพ้องความหมาย (Synonyms):** หากผู้ใช้พิมพ์คำที่ไม่มีใน List แต่มีความหมายเหมือนหรือใกล้เคียงกับคำใน List ให้แปลงเป็นคำใน List ทันที (เช่น ผู้ใช้พิมพ์ "รับประทาน" หรือ "หม่ำ" ให้แปลงเป็น "กิน")
      7. **วิเคราะห์บริบท (Context-Aware Polysemy):** หากเจอคำที่มีหลายความหมาย ให้ดูบริบทของประโยคก่อนเลือกคำจาก List
      8. **คำที่ไม่พบ (Unknown Word Fallback):** หากมีคำศัพท์เฉพาะ หรือคำที่หาความหมายเทียบเคียงใน List ไม่ได้เลยจริงๆ ให้ใส่คำนั้นพร้อมกับสัญลักษณ์ Unknown หรือตรวจไม่พบ ในรูปแบบ "word [Unknown]" ลงในผลลัพธ์ เพื่อให้ผู้ใช้ทราบว่าคำนั้นไม่พบใน List
       **หมายเหตุ:** 
       - ผลลัพธ์ต้องเป็นเพียง "ลำดับคำ (Gloss)" ที่แปลงแล้วเท่านั้น ห้ามใส่คำอธิบายหรือข้อความอื่นใดนอกจากลำดับคำที่แปลงแล้ว
       - คำที่แปลงแล้วต้องเป็นคำที่มีอยู่ใน [Vocabulary List] เท่านั้น หากคำใน inputText ตรงกับคำใน List ให้ใช้คำนั้นได้เลย
       - หากมีคำที่ไม่พบใน List หรือไม่สามารถแปลงได้ ให้ใส่ "word [Unknown]" ในผลลัพธ์เพื่อแจ้งให้ผู้ใช้ทราบว่าคำนั้นไม่พบและไม่สามารถแปลงได้

      9. **รูปแบบผลลัพธ์ (Output Format):** ตอบกลับเป็น JSON Array ของ String เท่านั้น ตัวอย่างเช่น ["ฉัน", "กรุงเทพ [Unknown]", "ข้าว", "กิน"] โดย "กรุงเทพ [Unknown]" หมายถึงคำที่ไม่พบใน List ห้ามพิมพ์เครื่องหมาย ```json หรือคำอธิบายใดๆ ทั้งสิ้น

      **[Vocabulary List]:**
      $wordListStr

      **ประโยคที่ต้องแปลง:**
      "$inputText"
      ''';
  }

  // 

  List<String> _parseResponse(String responseText) {
    // Clean the response text
    String cleaned = responseText.trim();

    // Remove markdown code blocks if present
    cleaned = cleaned.replaceAll(RegExp(r'```json\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*'), '');
    cleaned = cleaned.trim();

    // Try to find JSON array in response (greedy matching to get full array)
    final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(cleaned);
    if (jsonMatch == null) {
      throw Exception('Invalid response format. Raw response: $responseText');
    }

    final jsonStr = jsonMatch.group(0)!;

    try {
      final List<dynamic> parsed = jsonDecode(jsonStr);
      return parsed.map((e) => e.toString()).toList();
    } catch (e) {
      throw Exception('JSON parse error: $e. Raw JSON: $jsonStr');
    }
  }
}
