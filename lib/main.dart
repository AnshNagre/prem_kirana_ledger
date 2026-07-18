import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_dashboard.dart';
import 'state/ledger_provider.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const PremKiranaLedgerApp());
}

class PremKiranaLedgerApp extends StatelessWidget {
  const PremKiranaLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LedgerProvider(),
      child: Consumer<LedgerProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'Prem Kirana Ledger',
            debugShowCheckedModeBanner: false,
            themeMode: provider.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const HomeDashboard(),
          );
        },
      ),
    );
  }
}
