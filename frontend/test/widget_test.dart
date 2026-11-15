import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('OverseeApp renders foundation home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OverseeApp()));
    await tester.pumpAndSettle();

    expect(find.text('Oversee'), findsOneWidget);
    expect(find.text('Frontend Foundation Initialized'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);

    // Verify theme toggle button exists and can be tapped
    final themeToggleBtn = find.byTooltip('Toggle Theme');
    expect(themeToggleBtn, findsOneWidget);
    await tester.tap(themeToggleBtn);
    await tester.pumpAndSettle();
  });
}
