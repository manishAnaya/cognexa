import 'package:material_ui/material_ui.dart';
import 'package:frontend/features/auth/presentation/screens/auth_gate.dart';
import 'theme/app_theme.dart';

class CognexaApp extends StatelessWidget {
  const CognexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognexa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(),
    );
  }
}
