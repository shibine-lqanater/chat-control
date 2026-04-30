import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme_provider.dart';
import 'core/offline_server.dart';
import 'core/offline_client.dart';
import 'core/online_client.dart';
import 'core/network_discovery.dart';
import 'core/webrtc_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final themeProvider = ThemeProvider(prefs);
  final offlineServer = OfflineServer();
  final offlineClient = OfflineClient();
  final onlineClient = OnlineClient();
  final discoveryService = NetworkDiscoveryService();
  final rtcService = WebRTCService();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'SA')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: offlineServer),
          ChangeNotifierProvider.value(value: offlineClient),
          ChangeNotifierProvider.value(value: onlineClient),
          ChangeNotifierProvider.value(value: rtcService),
          Provider.value(value: discoveryService),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'app_name'.tr(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue,
        textTheme: context.locale.languageCode == 'ar'
            ? GoogleFonts.cairoTextTheme(ThemeData.light().textTheme)
            : GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        textTheme: context.locale.languageCode == 'ar'
            ? GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme)
            : GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const HomeScreen(),
    );
  }
}
