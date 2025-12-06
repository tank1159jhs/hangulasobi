import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/progress_service.dart';
import 'services/speech_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 서비스 초기화
  await ProgressService().initialize();
  await SpeechService().initialize();
  
  runApp(const HangulAsobiApp());
}

class HangulAsobiApp extends StatelessWidget {
  const HangulAsobiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: '한글놀이 (Hangul Asobi)',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'NotoSans', // 한글 폰트
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.pink.shade200,
                brightness: Brightness.light,
              ),
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  // 향후 테마 관리용
  void toggleTheme() {
    notifyListeners();
  }
}
