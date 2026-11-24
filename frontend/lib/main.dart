import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/l10n/locale_provider.dart';
import 'package:frontend/core/routing/app_router.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/font_scale_provider.dart';
import 'package:frontend/core/theme/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  runApp(const ProviderScope(child: OverseeApp()));
}

class OverseeApp extends ConsumerWidget {
  const OverseeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final seedColor = ref.watch(seedColorProvider);
    final locale = ref.watch(localeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    AppColors.applySeedColor(seedColor);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.buildLightTheme(seedColor),
      darkTheme: AppTheme.buildDarkTheme(seedColor),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(fontScale.appScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
