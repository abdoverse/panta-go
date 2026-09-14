import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:panta/core/localization/app_localizations.dart';
import 'package:panta/features/chat/chat_notification_banner.dart';
import 'package:panta/models/request_model.dart';
import 'package:panta/providers/panta_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('"I\'m at the Door" Arrival Alert (plan-65)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });
    test('RecyclingRequest stores arrivedAtDoor timestamp and supports copyWith', () {
      final now = DateTime.now();
      final req = RecyclingRequest(
        id: 'req-door-1',
        title: 'ICA Maxi cans',
        status: RequestStatus.accepted,
        scheduledFrom: now,
        scheduledTo: now.add(const Duration(hours: 1)),
        location: 'Stockholm',
        leaveAtDoor: true,
        doorInstructions: 'Code 1234, top floor',
      );

      expect(req.arrivedAtDoor, isNull);

      final arrivalTime = DateTime.now();
      final updated = req.copyWith(
        arrivedAtDoor: arrivalTime,
        milestone: 'arrived',
      );

      expect(updated.arrivedAtDoor, arrivalTime);
      expect(updated.milestone, 'arrived');
      expect(updated.leaveAtDoor, true);
      expect(updated.doorInstructions, 'Code 1234, top floor');
    });

    test('RecyclingRequest preserves arrival state across copyWith operations', () {
      final arrivalTime = DateTime(2026, 9, 4, 1, 30);
      final req = RecyclingRequest(
        id: 'req-door-2',
        title: 'Bottles',
        status: RequestStatus.accepted,
        scheduledFrom: arrivalTime,
        scheduledTo: arrivalTime,
        location: 'Solna',
        arrivedAtDoor: arrivalTime,
      );

      final completed = req.copyWith(status: RequestStatus.pickedUp);
      expect(completed.status, RequestStatus.pickedUp);
      expect(completed.arrivedAtDoor, arrivalTime);
    });

    test('PantaProvider processes helper-arrived-at-door realtime event and triggers alert', () async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final now = DateTime.now();
      final req = RecyclingRequest(
        id: 'req-door-realtime',
        title: 'Glass return',
        status: RequestStatus.accepted,
        scheduledFrom: now,
        scheduledTo: now.add(const Duration(hours: 1)),
        location: 'Stockholm',
      );
      provider.requests.add(req);

      expect(provider.requests.first.arrivedAtDoor, isNull);
      expect(provider.lastIncomingChatMessage, isNull);

      final arrivalEvent = '{"type":"helper-arrived-at-door","requestId":"req-door-realtime","title":"Ding-Dong! Helper is at your door 🛎️","message":"Erik is at your door."}';
      provider.handleRealtimeMessage(arrivalEvent);

      expect(provider.requests.first.arrivedAtDoor, isNotNull);
      expect(provider.requests.first.milestone, 'arrived');
      expect(provider.lastIncomingChatMessage, isNotNull);
      expect(provider.lastIncomingChatMessage!.text, 'Erik is at your door.');
      expect(provider.lastIncomingChatMessage!.senderName, 'Ding-Dong! Helper is at your door 🛎️');
    });

    test('PantaProvider processes push-notification realtime event and creates incoming message', () async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final pushEvent = '{"type":"push-notification","requestId":"req-push-1","title":"Alert","body":"Arrival push notification delivered"}';
      provider.handleRealtimeMessage(pushEvent);

      expect(provider.lastIncomingChatMessage, isNotNull);
      expect(provider.lastIncomingChatMessage!.text, 'Arrival push notification delivered');
    });

    test('PantaProvider processes batched newline-separated WebSocket payload with arrival event', () async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final now = DateTime.now();
      final req = RecyclingRequest(
        id: 'req-multi-line',
        title: 'Glass bottles',
        status: RequestStatus.accepted,
        scheduledFrom: now,
        scheduledTo: now.add(const Duration(hours: 1)),
        location: 'Stockholm',
      );
      provider.requests.add(req);

      final batchedMessage =
          '{"type":"helper-arrived-at-door","requestId":"req-multi-line","title":"Ding-Dong! Helper is at your door 🛎️","message":"Erik has arrived outside your door."}\n'
          '{"type":"push-notification","requestId":"req-multi-line","title":"Ding-Dong! Helper is at your door 🛎️","body":"Erik has arrived outside your door."}\n'
          '{"type":"chat-message","message":{"id":"msg-1","requestId":"req-multi-line","senderId":"helper-1","senderName":"Erik Helper","senderRole":"helper","text":"🛎️ Ding-Dong! I am at your door!","isPreset":true,"createdAt":"2026-09-15T00:00:00Z"}}\n'
          '{"type":"request-updated","request":{"id":"req-multi-line","title":"Glass bottles","status":"accepted","scheduledFrom":"2026-09-15T00:00:00Z","scheduledTo":"2026-09-15T01:00:00Z","location":"Stockholm","arrivedAtDoor":"2026-09-15T00:05:00Z","milestone":"arrived","etaMinutes":0}}';

      // Does not throw FormatException and successfully processes all chunks
      provider.handleRealtimeMessage(batchedMessage);

      expect(provider.requests.first.arrivedAtDoor, isNotNull);
      expect(provider.requests.first.milestone, 'arrived');
      expect(provider.lastIncomingChatMessage, isNotNull);
      expect(provider.lastIncomingChatMessage!.isArrivalAlert, isTrue);
    });

    test('Helper does not ring their own doorbell upon arrival broadcast', () async {
      final provider = PantaProvider();
      await provider.restoreSession();
      await provider.loginDirect(role: 'helper', username: 'Erik Helper', seedIfEmpty: false);

      final req = RecyclingRequest(
        id: 'req-helper-self',
        title: 'Bags',
        status: RequestStatus.accepted,
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Stockholm',
        helperId: provider.currentUserId,
      );
      provider.requests.add(req);

      final arrivalEvent = '{"type":"helper-arrived-at-door","requestId":"req-helper-self","title":"Ding-Dong! Helper is at your door 🛎️","message":"Erik is at your door."}';
      provider.handleRealtimeMessage(arrivalEvent);

      // Helper should NOT receive an incoming arrival chat banner for their own arrival
      expect(provider.lastIncomingChatMessage, isNull);
    });

    testWidgets('ChatNotificationListener displays golden DING-DONG banner for arrival alert', (tester) async {
      final provider = PantaProvider();
      await provider.restoreSession();

      final req = RecyclingRequest(
        id: 'req-banner-arrival',
        title: 'Glass bottles',
        scheduledFrom: DateTime.now(),
        scheduledTo: DateTime.now().add(const Duration(hours: 1)),
        location: 'Storgatan 4',
        status: RequestStatus.accepted,
      );
      provider.requests.add(req);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('sv')],
          home: ChangeNotifierProvider<PantaProvider>.value(
            value: provider,
            child: const ChatNotificationListener(
              child: Scaffold(
                body: Center(child: Text('Recycler Dashboard')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final arrivalEvent = '{"type":"helper-arrived-at-door","requestId":"req-banner-arrival","title":"Ding-Dong! Helper is at your door 🛎️","message":"Erik is at your door."}';
      provider.handleRealtimeMessage(arrivalEvent);

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('DING-DONG 🛎️'), findsOneWidget);
      expect(find.text('Ding-Dong! Helper is at your door 🛎️'), findsOneWidget);
      expect(find.text('Erik is at your door.'), findsOneWidget);
      expect(find.byIcon(Icons.doorbell_rounded), findsOneWidget);
    });
  });
}
