import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/l10n/locale_provider.dart';
import 'package:frontend/shared/layout/app_header.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('App Languages (English & Vietnamese)', () {
    test('AppLocalizations supports en and vi with accurate translations', () {
      const en = AppLocalizations(AppLocalizations.en);
      const vi = AppLocalizations(AppLocalizations.vi);

      expect(AppLocalizations.supportedLocales, containsAll([const Locale('en'), const Locale('vi')]));
      expect(en.viewTitle('Overview'), 'Overview');
      expect(vi.viewTitle('Overview'), 'Tổng quan');
      expect(en.myOngoingJobs, 'My Ongoing Jobs');
      expect(vi.myOngoingJobs, 'Công việc đang làm của tôi');
    });

    testWidgets('TopBar language toggle switches live between EN and VI', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final locale = ref.watch(localeProvider);
              return MaterialApp(
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const Scaffold(
                  appBar: AppHeader(
                    workspaceId: 'ws-1',
                    projectId: 'proj-1',
                    projectName: 'Oversee Platform',
                    currentViewTitle: 'Overview',
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('topbar_language_toggle')),
          matching: find.text('EN'),
        ),
        findsOneWidget,
      );
      expect(find.text('Overview'), findsOneWidget);

      await tester.tap(find.byKey(const Key('topbar_language_toggle')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('topbar_language_toggle')),
          matching: find.text('VI'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tổng quan'), findsOneWidget);
    });
  });
}
