import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 移动端数据目录（桌面端用 exe 所在目录，见 DatabaseService.dataDirectory）
  DatabaseService.mobilePathProvider = () async =>
      (await getApplicationDocumentsDirectory()).path;

  runApp(const HermesCardsApp());
}

class HermesCardsApp extends StatelessWidget {
  const HermesCardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'Hermes Cards',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const MainShell(),
      ),
    );
  }
}
