import 'package:intl/intl.dart';

class SmartNamerService {
  static final List<MapEntry<RegExp, String>> _documentPatterns = [
    // Tax & Government Forms
    MapEntry(RegExp(r'\b(1040|w2|w-2|w4|w-4|1099|tax\s*return|irs|individual\s*income)\b', caseSensitive: false), 'Form-1040-Tax-Return'),
    MapEntry(RegExp(r'\b(to\s*khai|quyet\s*toan\s*thue|dong\s*thue|thue\s*gtgt|thue\s*tncn|tax\s*declaration)\b', caseSensitive: false), 'To-Khai-Thue'),

    // Contracts & Agreements
    MapEntry(RegExp(r'\b(thue\s*nha|thue\s*dat|thue\s*mat\s*bang|lease|rent|rental)\b', caseSensitive: false), 'Hop-Dong-Thue-Nha'),
    MapEntry(RegExp(r'\b(lao\s*dong|employment|labor|nhan\s*su)\b', caseSensitive: false), 'Hop-Dong-Lao-Dong'),
    MapEntry(RegExp(r'\b(mua\s*ban|purchase|sales|chuyen\s*nhuong)\b', caseSensitive: false), 'Hop-Dong-Mua-Ban'),
    MapEntry(RegExp(r'\b(dich\s*vu|service|cung\s*ung)\b', caseSensitive: false), 'Hop-Dong-Dich-Vu'),
    MapEntry(RegExp(r'\b(hop\s*dong|contract|agreement|thoa\s*thuan|hdkt|hdld)\b', caseSensitive: false), 'Hop-Dong-Kinh-Te'),

    // Invoices, Receipts & Financial Documents
    MapEntry(RegExp(r'\b(hoa\s*don|invoice|gtgt|vat|bill|e-invoice)\b', caseSensitive: false), 'Hoa-Don-GTGT'),
    MapEntry(RegExp(r'\b(phieu\s*thu|receipt|receipts|phieu\s*xac\s*nhan\s*thu)\b', caseSensitive: false), 'Phieu-Thu-Tien'),
    MapEntry(RegExp(r'\b(phieu\s*chi|payment\s*voucher|phieu\s*chi\s*tien)\b', caseSensitive: false), 'Phieu-Chi-Tien'),
    MapEntry(RegExp(r'\b(bien\s*lai|chung\s*tu|giay\s*bao\s*co|giay\s*bao\s*no)\b', caseSensitive: false), 'Chung-Tu-Thanh-Toan'),
    MapEntry(RegExp(r'\b(bao\s*cao\s*tai\s*chinh|financial\s*statement|balance\s*sheet)\b', caseSensitive: false), 'Bao-Cao-Tai-Chinh'),
    MapEntry(RegExp(r'\b(bang\s*ke|bang\s*luong|payroll|payslip)\b', caseSensitive: false), 'Bang-Luong-Chi-Tiet'),

    // Identification & Personal Records
    MapEntry(RegExp(r'\b(can\s*cuoc\s*cong\s*dan|cccd|the\s*can\s*cuoc|identity\s*card|id\s*card)\b', caseSensitive: false), 'Can-Cuoc-Cong-Dan'),
    MapEntry(RegExp(r'\b(chung\s*minh\s*nhan\s*dan|cmnd|chung\s*minh\s*thu)\b', caseSensitive: false), 'Chung-Minh-Nhan-Dan'),
    MapEntry(RegExp(r'\b(ho\s*chieu|passport)\b', caseSensitive: false), 'Ho-Chieu-Passport'),
    MapEntry(RegExp(r'\b(bang\s*lai|driver|gplx|giay\s*phep\s*lai\s*xe|driving\s*licence)\b', caseSensitive: false), 'Giay-Phep-Lai-Xe'),
    MapEntry(RegExp(r'\b(so\s*ho\s*khau|ho\s*khau|household\s*registration)\b', caseSensitive: false), 'So-Ho-Khau'),
    MapEntry(RegExp(r'\b(giay\s*khai\s*sinh|birth\s*certificate)\b', caseSensitive: false), 'Giay-Khai-Sinh'),
    MapEntry(RegExp(r'\b(the\s*sinh\s*vien|student\s*card)\b', caseSensitive: false), 'The-Sinh-Vien'),
    MapEntry(RegExp(r'\b(the\s*bao\s*hiem|bhyt|insurance\s*card)\b', caseSensitive: false), 'The-Bao-Hiem-Y-Te'),

    // Minutes, Certificates & Applications
    MapEntry(RegExp(r'\b(bien\s*ban\s*ban\s*giao|handover\s*minutes)\b', caseSensitive: false), 'Bien-Ban-Ban-Giao'),
    MapEntry(RegExp(r'\b(bien\s*ban\s*nghiem\s*thu|acceptance\s*minutes)\b', caseSensitive: false), 'Bien-Ban-Nghiem-Thu'),
    MapEntry(RegExp(r'\b(bien\s*ban|minutes|meeting\s*minutes)\b', caseSensitive: false), 'Bien-Ban-Lam-Viec'),
    MapEntry(RegExp(r'\b(giay\s*chung\s*nhan|certificate|chung\s*chi|chung\s*nhan)\b', caseSensitive: false), 'Giay-Chung-Nhan'),
    MapEntry(RegExp(r'\b(bang\s*tot\s*nghiep|diploma|degree)\b', caseSensitive: false), 'Bang-Tot-Nghiep'),
    MapEntry(RegExp(r'\b(bang\s*diem|hoc\s*ba|transcript)\b', caseSensitive: false), 'Bang-Diem-Hoc-Tap'),
    MapEntry(RegExp(r'\b(don\s*xin\s*viec|job\s*application|cv|resume)\b', caseSensitive: false), 'Don-Xin-Viec'),
    MapEntry(RegExp(r'\b(don\s*xin|application|de\s*nghi|to\s*trinh)\b', caseSensitive: false), 'Don-Xin-Phep'),
    MapEntry(RegExp(r'\b(quyet\s*dinh|decision|resolution)\b', caseSensitive: false), 'Quyet-Dinh'),
    MapEntry(RegExp(r'\b(thong\s*bao|notice|announcement)\b', caseSensitive: false), 'Thong-Bao-Van-Ban'),
    MapEntry(RegExp(r'\b(don\s*thuoc|benh\s*an|medical\s*record|prescription)\b', caseSensitive: false), 'Ho-So-Benh-An'),
  ];

  /// Convert string to clean slug title (Title-Case-Hyphenated)
  static String toCleanSlug(String input) {
    if (input.trim().isEmpty) return 'Tai-Lieu-Scan';

    // Remove technical extensions and non-alphanumeric chars
    var clean = input.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    clean = clean.replaceAll(RegExp(r'[^a-zA-Z0-9\s_-]'), ' ');
    clean = clean.replaceAll('_', ' ').replaceAll('-', ' ');

    final words = clean
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .map((w) => w.substring(0, 1).toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : ''))
        .take(6)
        .toList();

    return words.isEmpty ? 'Tai-Lieu-Scan' : words.join('-');
  }

  /// Check if a raw string is a technical identifier, UUID, or camera hash
  static bool isTechnicalString(String text) {
    if (text.trim().isEmpty) return true;
    final clean = text.trim();

    // Long hex or numeric strings
    if (RegExp(r'[0-9a-fA-F]{12,}').hasMatch(clean)) return true;

    // Generic camera / screenshot filenames
    if (RegExp(r'^(img|image|photo|scan|screenshot|capture|dsc|pic|media|file|document|pasted|anh)[\d\s_-]*$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }

    // High ratio of digits/symbols
    int digitCount = 0;
    for (int i = 0; i < clean.length; i++) {
      final code = clean.codeUnitAt(i);
      if ((code >= 48 && code <= 57) || clean[i] == '-' || clean[i] == '_') {
        digitCount++;
      }
    }
    if (clean.length > 8 && (digitCount / clean.length) > 0.6) {
      return true;
    }

    return false;
  }

  /// Generates smart document name suggestions
  static List<String> generateSuggestions({
    String? hintText,
    int pageCount = 1,
  }) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HHmm').format(now);

    String baseCategory = 'Tai-Lieu-Scan';

    if (hintText != null && hintText.trim().isNotEmpty && !isTechnicalString(hintText)) {
      final norm = hintText.toLowerCase();
      for (final entry in _documentPatterns) {
        if (entry.key.hasMatch(norm)) {
          baseCategory = entry.value;
          break;
        }
      }
      if (baseCategory == 'Tai-Lieu-Scan') {
        baseCategory = toCleanSlug(hintText);
      }
    }

    final suggestions = <String>[
      '${baseCategory}_$todayStr',
      '$baseCategory-Doc',
      '${baseCategory}_$todayStr-$timeStr',
      baseCategory,
    ];

    if (pageCount > 1) {
      suggestions.insert(1, '${baseCategory}_$todayStr (${pageCount}P)');
    }

    return suggestions.toSet().toList();
  }
}
