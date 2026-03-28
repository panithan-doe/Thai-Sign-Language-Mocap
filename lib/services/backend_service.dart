import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_constants.dart';

/// Service สำหรับเชื่อมต่อกับ Python Backend API
class BackendService {
  /// Base URL ของ Backend API
  String get baseUrl => ApiConstants.backendApiUrl;

  /// เพิ่มคำใหม่เข้าระบบ
  ///
  /// Parameters:
  /// - word: คำภาษาไทย (เช่น "เกิน")
  /// - context: บริบท/ความหมาย (เช่น "มากเกินไป")
  /// - videoUrl: URL ของวิดีโอ
  /// - sourceType: ประเภทแหล่งที่มา ("th-sl" หรือ "direct")
  ///
  /// Returns:
  /// Map with keys: status, word, variant, context, message, motion_url
  Future<Map<String, dynamic>> addWord({
    required String word,
    required String context,
    required String videoUrl,
    String sourceType = 'th-sl',
  }) async {
    final url = Uri.parse('$baseUrl/api/add-word');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'word': word,
          'context': context,
          'video_url': videoUrl,
          'source_type': sourceType,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Unknown error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('ไม่สามารถเชื่อมต่อ Backend ได้ กรุณาตรวจสอบว่า Server กำลังทำงานอยู่');
      }
      rethrow;
    }
  }

  /// ดึงข้อมูลของคำ
  Future<Map<String, dynamic>> getWordInfo(String word) async {
    final url = Uri.parse('$baseUrl/api/word/$word');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get word info: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('ไม่สามารถเชื่อมต่อ Backend ได้');
      }
      rethrow;
    }
  }

  /// ดึงรายการคำทั้งหมด
  Future<List<String>> getAllWords() async {
    final url = Uri.parse('$baseUrl/api/words');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<String>.from(data['words'] ?? []);
      } else {
        throw Exception('Failed to get words: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('ไม่สามารถเชื่อมต่อ Backend ได้');
      }
      rethrow;
    }
  }

  /// ตรวจสอบว่า motion.json มีอยู่หรือไม่
  Future<bool> checkMotionExists(String word, String variant) async {
    final url = Uri.parse('$baseUrl/api/check-motion/$word/$variant');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// ตรวจสอบสถานะของ Backend
  Future<bool> healthCheck() async {
    final url = Uri.parse('$baseUrl/');

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// ดึง gloss_map ทั้งหมด (คำทั้งหมดพร้อม variants)
  ///
  /// Returns:
  /// Map with keys: total_words, gloss_map
  /// gloss_map มี structure: {"คำ": {"v1": "บริบท1", "v2": "บริบท2"}, ...}
  Future<Map<String, dynamic>> getGlossMap() async {
    final url = Uri.parse('$baseUrl/api/gloss-map');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get gloss map: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('ไม่สามารถเชื่อมต่อ Backend ได้');
      }
      rethrow;
    }
  }

  /// ลบคำและ variant ที่ระบุ
  ///
  /// Parameters:
  /// - word: คำภาษาไทย (เช่น "เกิน")
  /// - variant: variant ที่ต้องการลบ (เช่น "v1")
  ///
  /// Returns:
  /// Map with keys: status, message
  Future<Map<String, dynamic>> deleteWord(String word, String variant) async {
    final url = Uri.parse('$baseUrl/api/word/$word/$variant');

    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Unknown error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('ไม่สามารถเชื่อมต่อ Backend ได้');
      }
      rethrow;
    }
  }

  /// อัปเดตบริบทของคำ
  ///
  /// Parameters:
  /// - word: คำภาษาไทย (เช่น "เกิน")
  /// - variant: variant ที่ต้องการแก้ไข (เช่น "v1")
  /// - newContext: บริบทใหม่
  ///
  /// Returns:
  /// Map with keys: status, message
  Future<Map<String, dynamic>> updateWord({
    required String word,
    required String variant,
    required String newContext,
  }) async {
    final url = Uri.parse('$baseUrl/api/word/$word/$variant');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'new_context': newContext,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Unknown error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('ไม่สามารถเชื่อมต่อ Backend ได้');
      }
      rethrow;
    }
  }

  /// เพิ่มคำใหม่พร้อมอัปโหลดไฟล์วิดีโอ
  ///
  /// Parameters:
  /// - word: คำภาษาไทย (เช่น "เกิน")
  /// - context: บริบท/ความหมาย (เช่น "มากเกินไป")
  /// - fileBytes: ข้อมูลไฟล์วิดีโอ (Uint8List)
  /// - fileName: ชื่อไฟล์ (เช่น "video.mp4")
  ///
  /// Returns:
  /// Map with keys: status, word, variant, context, message, motion_url
  Future<Map<String, dynamic>> addWordWithFile({
    required String word,
    required String context,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final url = Uri.parse('$baseUrl/api/add-word-upload');

    try {
      // สร้าง multipart request
      final request = http.MultipartRequest('POST', url);

      // เพิ่ม form fields
      request.fields['word'] = word;
      request.fields['context'] = context;

      // หา MIME type จาก extension
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'mp4' => MediaType('video', 'mp4'),
        'mov' => MediaType('video', 'quicktime'),
        'avi' => MediaType('video', 'x-msvideo'),
        'webm' => MediaType('video', 'webm'),
        _ => MediaType('video', 'mp4'),
      };

      // เพิ่มไฟล์
      request.files.add(
        http.MultipartFile.fromBytes(
          'video_file',
          fileBytes,
          filename: fileName,
          contentType: mimeType,
        ),
      );

      // ส่ง request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Unknown error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('ไม่สามารถเชื่อมต่อ Backend ได้ กรุณาตรวจสอบว่า Server กำลังทำงานอยู่');
      }
      rethrow;
    }
  }
}
