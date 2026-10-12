import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'presentation/auth_gate.dart';

class AssociationApp extends StatelessWidget {
  const AssociationApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'جمعية التكافل',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b5b), brightness: Brightness.light),
          scaffoldBackgroundColor: const Color(0xfff7faf8),
          appBarTheme: const AppBarTheme(centerTitle: true),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        ),
        home: const AuthGate(),
      );
}
