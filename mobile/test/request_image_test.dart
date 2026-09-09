import 'package:flutter_test/flutter_test.dart';
import 'package:panta/features/dashboard/widgets/helper_job_card.dart';
import 'package:panta/features/dashboard/widgets/user_request_card.dart';
import 'package:panta/services/request_api_service.dart';

void main() {
  group('Request Image URL Sanitization & Resolution Tests', () {
    const awsConsoleUrl =
        'https://269172689438-eywgkjb7.eu-north-1.console.aws.amazon.com/s3/object/panta-request-images?region=eu-north-1&prefix=requests/20260909190032-85a15cb9/images/original.jpg';

    test('RequestApiService.parseImageUrl converts AWS Console URL to /api/v1/images/ path', () {
      final parsed = RequestApiService.parseImageUrl(awsConsoleUrl);
      expect(parsed, '/api/v1/images/requests/20260909190032-85a15cb9/images/original.jpg');
    });

    test('RequestApiService.parseImageUrl ignores generic asset and empty string', () {
      expect(RequestApiService.parseImageUrl('assets/images/generic.png'), isNull);
      expect(RequestApiService.parseImageUrl(''), isNull);
      expect(RequestApiService.parseImageUrl(null), isNull);
    });

    test('RequestImage.resolveUrl resolves relative and AWS console URLs', () {
      final resolvedConsole = RequestImage.resolveUrl(awsConsoleUrl);
      expect(resolvedConsole, isNotNull);
      expect(resolvedConsole!.contains('.console.aws.amazon.com'), isFalse);
      expect(resolvedConsole.endsWith('/api/v1/images/requests/20260909190032-85a15cb9/images/original.jpg'), isTrue);

      final resolvedRelative = RequestImage.resolveUrl('/api/v1/images/requests/test/photo.jpg');
      expect(resolvedRelative, isNotNull);
      expect(resolvedRelative!.endsWith('/api/v1/images/requests/test/photo.jpg'), isTrue);
      expect(resolvedRelative.startsWith('http'), isTrue);
    });

    test('HelperRequestImage.resolveUrl resolves relative and AWS console URLs', () {
      final resolvedConsole = HelperRequestImage.resolveUrl(awsConsoleUrl);
      expect(resolvedConsole, isNotNull);
      expect(resolvedConsole!.contains('.console.aws.amazon.com'), isFalse);
      expect(resolvedConsole.endsWith('/api/v1/images/requests/20260909190032-85a15cb9/images/original.jpg'), isTrue);

      final resolvedRelative = HelperRequestImage.resolveUrl('/api/v1/images/requests/test/photo.jpg');
      expect(resolvedRelative, isNotNull);
      expect(resolvedRelative!.endsWith('/api/v1/images/requests/test/photo.jpg'), isTrue);
      expect(resolvedRelative.startsWith('http'), isTrue);
    });
  });
}
