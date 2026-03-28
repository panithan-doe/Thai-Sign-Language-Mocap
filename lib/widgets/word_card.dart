import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import 'word_preview_dialog.dart';

/// Card widget สำหรับแสดงคำพร้อม variants และปุ่มจัดการ
class WordCard extends StatelessWidget {
  final String word;
  final Map<String, dynamic> variants;
  final Future<void> Function(String word, String variant) onDeleted;
  final Future<void> Function(String word, String variant) onUpdated;

  const WordCard({
    super.key,
    required this.word,
    required this.variants,
    required this.onDeleted,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final variantEntries = variants.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: คำภาษาไทย
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.text_fields,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    word,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${variants.length} variant${variants.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body: รายการ variants
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: variantEntries.map((entry) {
                final variant = entry.key;
                final context = entry.value.toString();
                return _VariantItem(
                  word: word,
                  variant: variant,
                  context: context,
                  onDeleted: onDeleted,
                  onUpdated: onUpdated,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget สำหรับแสดง variant แต่ละตัว
class _VariantItem extends StatelessWidget {
  final String word;
  final String variant;
  final String context;
  final Future<void> Function(String word, String variant) onDeleted;
  final Future<void> Function(String word, String variant) onUpdated;

  const _VariantItem({
    required this.word,
    required this.variant,
    required this.context,
    required this.onDeleted,
    required this.onUpdated,
  });

  Future<void> _showPreview(BuildContext context) async {
    await showWordPreview(
      context,
      word: word,
      variant: variant,
      wordContext: this.context,
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final controller = TextEditingController(text: this.context);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('แก้ไขบริบท $variant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คำ: $word',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                // labelText: 'บริบท/ความหมาย',
                border: OutlineInputBorder(),
                hintText: 'ใส่บริบทหรือความหมายของคำ',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != this.context) {
      await _updateContext(context, result);
    }
  }

  Future<void> _updateContext(BuildContext context, String newContext) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final backendService = BackendService();

    try {
      // แสดง loading
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('กำลังอัปเดต...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final response = await backendService.updateWord(
        word: word,
        variant: variant,
        newContext: newContext,
      );

      scaffoldMessenger.hideCurrentSnackBar();

      if (response['status'] == 'SUCCESS') {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'อัปเดตสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        await onUpdated(word, variant);
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'เกิดข้อผิดพลาด'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('คุณแน่ใจหรือไม่ว่าต้องการลบ?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'คำ: $word',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Variant: $variant'),
                  Text('บริบท: $context'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ การลบจะไม่สามารถกู้คืนได้',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteVariant(context);
    }
  }

  Future<void> _deleteVariant(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final backendService = BackendService();

    try {
      // แสดง loading
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('กำลังลบ...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final response = await backendService.deleteWord(word, variant);

      scaffoldMessenger.hideCurrentSnackBar();

      if (response['status'] == 'SUCCESS') {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'ลบสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        await onDeleted(word, variant);
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'เกิดข้อผิดพลาด'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Variant badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              variant,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Context text
          Expanded(
            child: Text(
              this.context,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview button
              IconButton(
                onPressed: () => _showPreview(context),
                icon: const Icon(Icons.play_circle_outline),
                color: const Color(0xFF3B82F6),
                tooltip: 'ดู Animation',
                iconSize: 22,
              ),

              // Edit button
              IconButton(
                onPressed: () => _showEditDialog(context),
                icon: const Icon(Icons.edit_outlined),
                color: Colors.orange.shade700,
                tooltip: 'แก้ไข',
                iconSize: 22,
              ),

              // Delete button
              IconButton(
                onPressed: () => _showDeleteConfirmation(context),
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade700,
                tooltip: 'ลบ',
                iconSize: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
