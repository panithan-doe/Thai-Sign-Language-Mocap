/// Configuration for motion data preprocessing
class PreprocessingConfig {
  /// ระยะห่างสูงสุดที่จะ fill gap (เฟรม)
  /// แนะนำ: 10-15 เฟรม (0.2-0.3 วินาที ที่ 50 FPS)
  final int maxGapToFill;

  /// ขนาด window สำหรับ Median Filter
  /// แนะนำ: 5 หรือ 7 (คี่เสมอ)
  final int medianWindowSize;

  /// ขนาด window สำหรับ Savitzky-Golay Filter
  /// แนะนำ: 5 (สวิงแคบ) หรือ 9 (สวิงกว้าง)
  final int sgWindowSize;

  /// จำนวนรอบการ smooth ด้วย SG Filter
  /// แนะนำ: 1-3 รอบ
  final int sgPasses;

  /// เปิด/ปิด preprocessing
  final bool enabled;

  const PreprocessingConfig({
    this.maxGapToFill = 15,     // เพิ่มจาก 10 → 15 ตามตัวอย่าง
    this.medianWindowSize = 7,  // เพิ่มจาก 5 → 7 ตามตัวอย่าง
    this.sgWindowSize = 9,
    this.sgPasses = 2,
    this.enabled = true,
  });

  /// Preset: ไม่ประมวลผล (raw data)
  static const none = PreprocessingConfig(enabled: false);

  /// Preset: Smooth เบา (responsive)
  static const light = PreprocessingConfig(
    maxGapToFill: 10,
    medianWindowSize: 3,
    sgWindowSize: 3,
    sgPasses: 1,
  );

  /// Preset: Smooth ปกติ (แนะนำ)
  static const normal = PreprocessingConfig(
    maxGapToFill: 15,
    medianWindowSize: 7,
    sgWindowSize: 9,
    sgPasses: 2,
  );

  /// Preset: Smooth หนัก (very smooth)
  static const heavy = PreprocessingConfig(
    maxGapToFill: 20,
    medianWindowSize: 7,
    sgWindowSize: 9,
    sgPasses: 3,
  );
}
