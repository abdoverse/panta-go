import 'package:flutter_test/flutter_test.dart';
import 'package:panta/services/receipt_ocr_service.dart';

void main() {
  group('ReceiptOcrService', () {
    test('parses Swedish Pantkvitto receipt total and store', () {
      const receipt = '''
================================
         ICA SUPERMARKET
           PANTKVITTO
================================
BURKAR 1.00 kr x 15        15.00 kr
PET 2.00 kr x 10           20.00 kr
--------------------------------
Antal förpackningar: 25 st
SUMMA: 35.00 SEK
ATT UTBETALA: 35.00 KR
================================
''';

      final result = ReceiptOcrService.parseReceiptText(receipt);
      expect(result.isValid, isTrue);
      expect(result.totalAmount, 35.00);
      expect(result.totalContainers, 25);
      expect(result.storeName, 'ICA');
      expect(result.confidence, greaterThan(0.7));
    });

    test('handles Swedish dash currency notation 48:-', () {
      const receipt = '''
TOMRA PANTSTATION
Totalt antal burkar: 24
ATT UTBETALA: 48:-
Tack for din insats!
''';

      final result = ReceiptOcrService.parseReceiptText(receipt);
      expect(result.isValid, isTrue);
      expect(result.totalAmount, 48.00);
      expect(result.storeName, 'TOMRA');
    });

    test('handles empty or unrecognized input safely', () {
      final result = ReceiptOcrService.parseReceiptText('');
      expect(result.isValid, isFalse);
      expect(result.totalAmount, 0.0);
    });
  });
}
