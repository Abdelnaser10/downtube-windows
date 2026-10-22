import 'dart:io';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'services/youtube_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _runSelfTestIfRequested();
  runApp(const MyApp());
}

/// Headless verification mode, used during development/release checks:
/// set DOWNTUBE_SELFTEST=1 and the app exercises the download engine end
/// to end, writes a report next to the project, then exits. Normal users
/// never trigger it and get the regular GUI.
Future<void> _runSelfTestIfRequested() async {
  if (Platform.environment['DOWNTUBE_SELFTEST'] != '1') return;
  final log = StringBuffer();
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) {
    log.writeln('${r.level.name} [${r.loggerName}] ${r.message}'
        '${r.error != null ? ' — ${r.error}' : ''}');
  });
  try {
    final svc = YouTubeService();
    const url = 'https://youtu.be/bXgu5--fg5E';
    final info = await svc.fetchVideoInfo(url);
    log.writeln('INFO "${info.title}" formats=${info.formats.length}');
    final sw = Stopwatch()..start();

    // 480p = video-only → real FFmpeg copy-merge path
    final f480 = info.formats
        .firstWhere((f) => f.quality.contains('480') && !f.hasAudio);
    final mp4 = await svc.downloadVideo(
      url: url,
      formatId: f480.formatId,
      onProgress: (double p, String s) {},
      onStage: (s) => log.writeln('STAGE $s'),
    );
    final mp4Len = await File(mp4).length();
    log.writeln('MP4 OK ${(mp4Len / 1048576).toStringAsFixed(1)} MB '
        'in ${sw.elapsed}');
    try {
      await File(mp4).delete();
    } catch (_) {}

    // 128 kbps MP3 = always-transcoded audio path
    sw.reset();
    final mp3 = await svc.downloadAudio(
      url: url,
      quality: '128',
      onProgress: (double p, String s) {},
      cancelToken: null,
    );
    final mp3Len = await File(mp3).length();
    log.writeln('MP3 OK ${(mp3Len / 1048576).toStringAsFixed(1)} MB '
        'in ${sw.elapsed}');
    try {
      await File(mp3).delete();
    } catch (_) {}

    log.writeln('SELFTEST PASS');
  } catch (e) {
    log.writeln('SELFTEST FAIL: $e');
  }
  try {
    await File(r'D:\Ramsis\abdelnaser\projects\youtube-downloader\flutter_app\selftest.log')
        .writeAsString(log.toString());
  } catch (_) {}
  exit(0);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        title: 'DownTube',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF1A1A2E),
            primary: Color(0xFF667EEA),
            secondary: Color(0xFF764BA2),
          ),
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.dark().textTheme,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
