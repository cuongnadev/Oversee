import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/theme/font_scale_provider.dart';
import 'package:frontend/shared/widgets/seed_color_picker.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dual App & Content Pane Font Size (additive ±10%)', () {
    test('defaults to 100% app and 90% content pane', () {
      const state = FontScaleState();
      expect(state.appPercent, 100);
      expect(state.contentPercent, 90);
      expect(state.appScale, 1.0);
      expect(state.contentScale, 0.9);
      expect(state.effectiveContentScale, closeTo(0.9, 1e-9));
    });

    test('decreasing by 10% then increasing by 10% returns exact 100% (never 99%)', () async {
      final notifier = FontScaleNotifier();
      await notifier.decreaseAppFontSize();
      expect(notifier.state.appPercent, 90);

      await notifier.increaseAppFontSize();
      expect(notifier.state.appPercent, 100);

      await notifier.increaseContentFontSize();
      expect(notifier.state.contentPercent, 100);

      await notifier.decreaseContentFontSize();
      expect(notifier.state.contentPercent, 90);
    });

    testWidgets('SeedColorPickerDialog stages font scale changes until Confirm is tapped',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: SeedColorPickerDialog()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Decrease whole app font size from 100% -> 90% (staged, not committed yet)
      await tester.tap(find.byKey(const Key('app_font_decrease_btn')));
      await tester.pump();
      expect(find.text('90%'), findsNWidgets(2));
      expect(container.read(fontScaleProvider).appPercent, 100);

      // Confirm applies staged change -> 90%
      await tester.tap(find.byKey(const Key('font_size_confirm_btn')));
      await tester.pumpAndSettle();
      expect(container.read(fontScaleProvider).appPercent, 90);

      // Increase by +10% and confirm -> exact 100%, not 99%
      await tester.tap(find.byKey(const Key('app_font_increase_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('font_size_confirm_btn')));
      await tester.pumpAndSettle();
      expect(container.read(fontScaleProvider).appPercent, 100);
    });
  });
}
