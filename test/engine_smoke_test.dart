// Engine smoke tests: FFmpeg detection, playlist scan, real 144p download+merge.
// Runs under `dart test` with real network and the real local filesystem.
import 'dart:io';
import 'package:test/test.dart';
import 'package:downtube/services/youtube_service.dart';

void main() {
  final service = YouTubeService();

  test('extract playlist id + RD (mix) detection', () {
    expect(
      YouTubeService.extractPlaylistId(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=RDdQw4w9WgXcQ'),
      'RDdQw4w9WgXcQ',
    );
    expect(
      YouTubeService.extractPlaylistId(
          'https://www.youtube.com/playlist?list=PL9tY0BWXOZFuFEG_GtOBZ8-8wbkH-NVAr'),
      'PL9tY0BWXOZFuFEG_GtOBZ8-8wbkH-NVAr',
    );
    expect(
      YouTubeService.extractPlaylistId(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      null,
    );
  });

  test('FFmpeg is detected on this machine', () async {
    final p = await service.findFfmpeg();
    expect(p, isNotNull, reason: 'imageio-ffmpeg exists on this machine');
    expect(File(p!).existsSync(), isTrue);
  });

  test('fetch single-video info', () async {
    final info = await service
        .fetchVideoInfo('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    expect(info.title, isNotEmpty);
    expect(info.formats.length, greaterThan(0));
  }, timeout: Timeout(Duration(minutes: 2)));

  test('fetch playlist info (live playlist)', () async {
    final pl = await service.fetchPlaylistInfo(
        'https://www.youtube.com/playlist?list=PLcGkkXtask_eYr5C29azb7JHrEA2KsziK');
    expect(pl.title, isNotEmpty);
    expect(pl.entries.length, greaterThan(0));
    expect(
        pl.entries.first.url, startsWith('https://www.youtube.com/watch?v='));
    expect(pl.entries.first.title, isNotEmpty);
  }, timeout: Timeout(Duration(minutes: 3)));

  test('real 144p download + FFmpeg merge, then cleanup', () async {
    String? path;
    try {
      path = await service.downloadPlaylistVideo(
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        maxHeight: 144,
        onProgress: (p, s) {},
        onStage: (s) {},
      );
      final f = File(path);
      expect(await f.exists(), isTrue);
      expect(await f.length(), greaterThan(100 * 1024));
      expect(path.toLowerCase().endsWith('.mp4'), isTrue,
          reason: 'with FFmpeg present the result must be a merged MP4');
    } finally {
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    }
  }, timeout: Timeout(Duration(minutes: 4)));

  test('real MP3 conversion (64 kbps) + cleanup', () async {
    String? path;
    try {
      path = await service.downloadAudio(
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        quality: '64',
        onProgress: (p, s) {},
        onStage: (s) {},
      );
      final f = File(path);
      expect(await f.exists(), isTrue);
      expect(await f.length(), greaterThan(100 * 1024));
      expect(path.toLowerCase().endsWith('.mp3'), isTrue,
          reason: 'with FFmpeg present the result must be a real MP3');
    } finally {
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    }
  }, timeout: Timeout(Duration(minutes: 4)));
}
