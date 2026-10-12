import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ArabicPdfHelper {
  static final Map<int, List<int>> _arabicMap = {
    0x0621: [0xFE80, 0xFE80, 0xFE80, 0xFE80], // ء
    0x0622: [0xFE81, 0xFE82, 0xFE81, 0xFE82], // آ
    0x0623: [0xFE83, 0xFE84, 0xFE83, 0xFE84], // أ
    0x0624: [0xFE85, 0xFE86, 0xFE85, 0xFE86], // ؤ
    0x0625: [0xFE87, 0xFE88, 0xFE87, 0xFE88], // إ
    0x0626: [0xFE89, 0xFE8A, 0xFE8B, 0xFE8C], // ئ
    0x0627: [0xFE8D, 0xFE8E, 0xFE8D, 0xFE8E], // ا
    0x0628: [0xFE8F, 0xFE90, 0xFE91, 0xFE92], // ب
    0x0629: [0xFE93, 0xFE94, 0xFE93, 0xFE94], // ة
    0x062A: [0xFE95, 0xFE96, 0xFE97, 0xFE98], // ت
    0x062B: [0xFE99, 0xFE9A, 0xFE9B, 0xFE9C], // ث
    0x062C: [0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0], // ج
    0x062D: [0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4], // ح
    0x062E: [0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8], // خ
    0x062F: [0xFEA9, 0xFEAA, 0xFEA9, 0xFEAA], // د
    0x0630: [0xFEAB, 0xFEAC, 0xFEAB, 0xFEAC], // ذ
    0x0631: [0xFEAD, 0xFEAE, 0xFEAD, 0xFEAE], // ر
    0x0632: [0xFEAF, 0xFEB0, 0xFEAF, 0xFEB0], // ز
    0x0633: [0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4], // س
    0x0634: [0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8], // ش
    0x0635: [0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC], // ص
    0x0636: [0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0], // ض
    0x0637: [0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4], // ط
    0x0638: [0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8], // ظ
    0x0639: [0xFEC9, 0xFECA, 0xFECB, 0xFECC], // ع
    0x063A: [0xFECD, 0xFECE, 0xFECF, 0xFED0], // غ
    0x0641: [0xFED1, 0xFED2, 0xFED3, 0xFED4], // ف
    0x0642: [0xFED5, 0xFED6, 0xFED7, 0xFED8], // ق
    0x0643: [0xFED9, 0xFEDA, 0xFEDB, 0xFEDC], // ك
    0x0644: [0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0], // ل
    0x0645: [0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4], // م
    0x0646: [0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8], // ن
    0x0647: [0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC], // ه
    0x0648: [0xFEED, 0xFEEE, 0xFEED, 0xFEEE], // و
    0x0649: [0xFEEF, 0xFEF0, 0xFEEF, 0xFEF0], // ى
    0x064A: [0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4], // ي
  };

  static final Set<int> _nonRightConnectors = {
    0x0621, 0x0622, 0x0623, 0x0624, 0x0625, 0x0627,
    0x0629, 0x062F, 0x0630, 0x0631, 0x0632, 0x0648, 0x0649
  };

  static bool _isArabic(int code) {
    return (code >= 0x0600 && code <= 0x06FF) || (code >= 0xFE70 && code <= 0xFEFF);
  }

  /// Reshapes Arabic string for PDF layout
  static String reshape(String text) {
    if (text.isEmpty) return text;
    
    final runes = text.runes.toList();
    final resultRunes = <int>[];

    for (int i = 0; i < runes.length; i++) {
      final current = runes[i];

      if (!_isArabic(current) || !_arabicMap.containsKey(current)) {
        resultRunes.add(current);
        continue;
      }

      final prev = i > 0 ? runes[i - 1] : 0;
      final next = i < runes.length - 1 ? runes[i + 1] : 0;

      final prevConnects = prev != 0 && _isArabic(prev) && _arabicMap.containsKey(prev) && !_nonRightConnectors.contains(prev);
      final nextConnects = next != 0 && _isArabic(next) && _arabicMap.containsKey(next);

      int formIndex = 0; // Isolated
      if (prevConnects && nextConnects && !_nonRightConnectors.contains(current)) {
        formIndex = 3; // Medial
      } else if (prevConnects) {
        formIndex = 1; // Final
      } else if (nextConnects && !_nonRightConnectors.contains(current)) {
        formIndex = 2; // Initial
      } else {
        formIndex = 0; // Isolated
      }

      final forms = _arabicMap[current]!;
      resultRunes.add(forms[formIndex]);
    }

    return String.fromCharCodes(resultRunes);
  }

  /// Loads the primary Arabic font for PDF documents
  static Future<pw.Font> loadArabicFont() async {
    try {
      final bytes = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      return pw.Font.ttf(bytes);
    } catch (_) {
      try {
        final bytes = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
        return pw.Font.ttf(bytes);
      } catch (_) {
        return pw.Font.helvetica();
      }
    }
  }

  /// Loads the bold Arabic font for PDF documents
  static Future<pw.Font> loadArabicBoldFont() async {
    try {
      final bytes = await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      return pw.Font.ttf(bytes);
    } catch (_) {
      try {
        final bytes = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
        return pw.Font.ttf(bytes);
      } catch (_) {
        return pw.Font.helveticaBold();
      }
    }
  }
}
