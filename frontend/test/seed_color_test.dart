import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/shared/widgets/seed_color_picker.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AppColors.resetSeedColor();
  });

  tearDown(() {
    AppColors.resetSeedColor();
  });

  group('SeedColorNotifier & AppColors Tests', () {
    test('default violet preserves exact Figma hex values', () {
      AppColors.applySeedColor(AppColors.defaultSeedColor);
      expect(AppColors.primarySolidLight, const Color(0xFF7253D5));
      expect(AppColors.primaryDark, const Color(0xFF7054CF));
      expect(AppColors.primaryLight, const Color(0xFFA292FF));
      expect(AppColors.accentSoftLight, const Color(0xFFEEE8FB));
      expect(AppColors.accentSoftDark, const Color(0xFF29243E));
    });

    test('setSeedColor updates AppColors, AppTheme, and persists to SharedPreferences', () async {
      const emerald = Color(0xFF059669);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(seedColorProvider.notifier).setSeedColor(emerald);

      expect(container.read(seedColorProvider), emerald);
      expect(AppColors.currentSeedColor, emerald);
      expect(AppColors.primarySolidLight, isNot(const Color(0xFF7253D5)));

      final lightTheme = AppTheme.buildLightTheme(emerald);
      expect(lightTheme.colorScheme.primary, AppColors.primarySolidLight);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AppConstants.seedColorKey), emerald.toARGB32());

      await container.read(seedColorProvider.notifier).resetToDefault();
      expect(container.read(seedColorProvider), AppColors.defaultSeedColor);
      expect(AppColors.primarySolidLight, const Color(0xFF7253D5));
    });
  });

  group('SeedColorSelector Widget Tests', () {
    testWidgets('selecting a preset updates seedColorProvider and validates custom hex', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              final seed = ref.watch(seedColorProvider);
              AppColors.applySeedColor(seed);
              return MaterialApp(
                theme: AppTheme.buildLightTheme(seed),
                home: const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: SeedColorSelector(),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Ocean preset
      await tester.tap(find.text('Ocean'));
      await tester.pumpAndSettle();
      expect(capturedRef.read(seedColorProvider), const Color(0xFF2563EB));
      expect(find.text('Reset to Default Violet'), findsOneWidget);

      // Invalid hex shows validation message
      await tester.enterText(find.byType(TextField), 'not-a-hex');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.textContaining('valid 6-digit hex'), findsOneWidget);

      // Valid custom hex applies synchronously
      await tester.enterText(find.byType(TextField), '#E11D48');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(capturedRef.read(seedColorProvider), const Color(0xFFE11D48));
    });
  });
}
