import 'package:flutter/material.dart';

/// Widget สำหรับแสดงตัวอักษรไทยแบบ horizontal scrollable
/// ใช้สำหรับกรองคำในพจนานุกรม
class ThaiAlphabetFilter extends StatelessWidget {
  final String? selectedLetter;
  final void Function(String?) onLetterSelected;

  const ThaiAlphabetFilter({
    super.key,
    this.selectedLetter,
    required this.onLetterSelected,
  });

  /// รายการตัวอักษรไทยพยัญชนะทั้งหมด
  static const List<String> thaiConsonants = [
    'ก', 'ข', 'ฃ', 'ค', 'ฅ', 'ฆ', 'ง',
    'จ', 'ฉ', 'ช', 'ซ', 'ฌ', 'ญ',
    'ฎ', 'ฏ', 'ฐ', 'ฑ', 'ฒ', 'ณ',
    'ด', 'ต', 'ถ', 'ท', 'ธ', 'น',
    'บ', 'ป', 'ผ', 'ฝ', 'พ', 'ฟ', 'ภ', 'ม',
    'ย', 'ร', 'ฤ', 'ล', 'ฦ', 'ว',
    'ศ', 'ษ', 'ส', 'ห', 'ฬ', 'อ', 'ฮ',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(
                'กรองตามตัวอักษร',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              if (selectedLetter != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onLetterSelected(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ล้างตัวกรอง',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.close, size: 14, color: Colors.red.shade700),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Scrollable letter chips
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // ปุ่ม "ทั้งหมด"
              _buildLetterChip(
                context,
                label: 'ทั้งหมด',
                value: null,
                isSelected: selectedLetter == null,
              ),
              const SizedBox(width: 6),

              // ปุ่มตัวอักษรไทย
              ...thaiConsonants.map((letter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildLetterChip(
                    context,
                    label: letter,
                    value: letter,
                    isSelected: selectedLetter == letter,
                  ),
                );
              }),

              // ปุ่ม "อื่นๆ" (สำหรับคำที่ขึ้นต้นด้วยตัวอักษรอื่น)
              _buildLetterChip(
                context,
                label: '#',
                value: '#',
                isSelected: selectedLetter == '#',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLetterChip(
    BuildContext context, {
    required String label,
    required String? value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => onLetterSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
