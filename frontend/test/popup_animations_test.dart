import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/shared/widgets/app_dialog.dart';

void main() {
  group('Popup 150ms display & vanish animations', () {
    test('standard popup animation duration is 150ms', () {
      expect(kAppPopupAnimationDuration, const Duration(milliseconds: 150));
      expect(kAppPopupAnimationStyle.duration, const Duration(milliseconds: 150));
      expect(kAppPopupAnimationStyle.reverseDuration, const Duration(milliseconds: 150));
    });

    testWidgets('showAnimatedDialog displays and vanishes smoothly over 150ms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showAnimatedDialog<void>(
                    context: context,
                    builder: (ctx) => const Dialog(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Animated Popup Content'),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.text('Animated Popup Content'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Animated Popup Content'), findsOneWidget);

      // Dismiss and verify vanish completes after 150ms
      Navigator.of(tester.element(find.text('Animated Popup Content'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.text('Animated Popup Content'), findsNothing);
    });
  });
}
