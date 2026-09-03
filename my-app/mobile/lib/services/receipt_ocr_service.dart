import 'dart:math';

class ReceiptOcrResult {
  final double totalAmount;
  final int totalContainers;
  final String? storeName;
  final double confidence;
  final List<String> rawLines;

  const ReceiptOcrResult({
    required this.totalAmount,
    this.totalContainers = 0,
    this.storeName,
    this.confidence = 0.0,
    this.rawLines = const [],
  });

  bool get isValid => totalAmount > 0;

  Map<String, dynamic> toJson() => {
        'totalAmount': totalAmount,
        'totalContainers': totalContainers,
        'storeName': storeName,
        'confidence': confidence,
      };
}

class ReceiptOcrService {
  static const List<String> _totalKeywords = [
    'att utbetala',
    'summa',
    'pantbelopp',
    'pant total',
    'totalt',
    'total',
    'slutsumma',
  ];

  static const List<String> _storeKeywords = [
    'tomra',
    'returpack',
    'ica',
    'coop',
    'hemköp',
    'willys',
    'city gross',
    'lidl',
    'pantstation',
  ];

  /// Parses raw text extracted from an image or camera frame into a structured [ReceiptOcrResult].
  static ReceiptOcrResult parseReceiptText(String text) {
    if (text.trim().isEmpty) {
      return const ReceiptOcrResult(totalAmount: 0.0);
    }

    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    double detectedTotal = 0.0;
    int detectedContainers = 0;
    String? detectedStore;
    double confidence = 0.5;

    // 1. Identify Store
    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final store in _storeKeywords) {
        if (lower.contains(store)) {
          detectedStore = store.toUpperCase();
          confidence = min(1.0, confidence + 0.15);
          break;
        }
      }
      if (detectedStore != null) break;
    }

    // 2. Scan for total line keywords (from bottom to top, as total is typically near footer)
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final lower = line.toLowerCase();

      for (final keyword in _totalKeywords) {
        if (lower.contains(keyword)) {
          final amount = _extractAmount(line);
          if (amount != null && amount > 0) {
            detectedTotal = amount;
            confidence = min(1.0, confidence + 0.35);
            break;
          }
          // If amount is on the next line
          if (i + 1 < lines.length) {
            final nextAmount = _extractAmount(lines[i + 1]);
            if (nextAmount != null && nextAmount > 0) {
              detectedTotal = nextAmount;
              confidence = min(1.0, confidence + 0.3);
              break;
            }
          }
        }
      }
      if (detectedTotal > 0) break;
    }

    // 3. Fallback: search for largest currency amount (kr, sek, :-)
    if (detectedTotal == 0.0) {
      double maxFound = 0.0;
      for (final line in lines) {
        final amount = _extractAmount(line);
        if (amount != null && amount > maxFound) {
          maxFound = amount;
        }
      }
      if (maxFound > 0) {
        detectedTotal = maxFound;
        confidence = 0.4;
      }
    }

    // 4. Extract container count if present (e.g. "15 st", "24 burkar", "Antal: 12")
    final countRegex = RegExp(
      r'(\d+)\s*(?:st|burk|pet|flask|antal)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = countRegex.firstMatch(line);
      if (match != null) {
        final count = int.tryParse(match.group(1)!);
        if (count != null && count > detectedContainers) {
          detectedContainers = count;
        }
      }
    }

    return ReceiptOcrResult(
      totalAmount: detectedTotal,
      totalContainers: detectedContainers,
      storeName: detectedStore,
      confidence: detectedTotal > 0 ? confidence : 0.0,
      rawLines: lines,
    );
  }

  /// Extracts numeric amount from a line like "SUMMA 45,50 KR", "75.00 SEK", "95:-"
  static double? _extractAmount(String line) {
    var clean = line.replaceAll(':-', '.00');

    final pattern = RegExp(r'(\d+[,\.]\d{2})|(\b\d{1,4}\b(?=\s*(?:kr|sek)))', caseSensitive: false);
    final match = pattern.firstMatch(clean);
    if (match != null) {
      var raw = (match.group(1) ?? match.group(2))!.replaceAll(',', '.');
      final val = double.tryParse(raw);
      if (val != null && val > 0 && val < 10000) {
        return val;
      }
    }
    return null;
  }

  /// Generates a realistic mock receipt text for testing & web emulator runs
  static String generateSampleReceiptText({
    String store = 'ICA Kvantum',
    double amount = 48.0,
    int cans = 18,
    int petBottles = 15,
  }) {
    return '''
================================
         $store
       PANTKVITTO
================================
Returpack Pantstation #402
Datum: 2026-09-03 14:32

BURKAR 1.00 kr x $cans      ${cans.toStringAsFixed(2)} kr
PET 2.00 kr x $petBottles         ${(petBottles * 2).toStringAsFixed(2)} kr
--------------------------------
Antal förpackningar: ${cans + petBottles} st
SUMMA: ${amount.toStringAsFixed(2)} SEK
ATT UTBETALA: ${amount.toStringAsFixed(2)} KR
================================
   Tack för att du pantar!
''';
  }
}
