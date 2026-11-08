import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_mesh_flutter/core/theme/app_theme.dart';
import 'package:offline_mesh_flutter/features/onboarding/onboarding_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OfflineMeshApp()));
}

class OfflineMeshApp extends ConsumerWidget {
  const OfflineMeshApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Mesh Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      home: const OnboardingGate(),
    );
  }
}
