import 'dart:async';
import 'dart:io';
// The challenge-solver type is not publicly exported by the fork yet.
// ignore: implementation_imports
import 'package:youtube_explode_dart/src/reverse_engineering/challenges/js_challenge.dart'
    show BaseJSChallengeSolver;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_info.dart';
import '../models/playlist_info.dart';
import 'innertube_manifest.dart';

/// Universal YouTube service that downloads directly on-device
/// using youtube_explode_dart (no server needed).
/// Works on all platforms: Android, iOS, Windows, macOS, Linux.
///
/// On desktop platforms FFmpeg is auto-detected when available:
/// video-only selections are properly merged (1080p+ unlocked) and
/// audio downloads are transcoded to real MP3 files.
///
/// When a JS challenge solver is provided, YouTube's `n`/signature
/// challenges are solved in-app, which lifts the few-MB serving cap the
/// server applies to unsolved (throttled) media URLs.
class YouTubeService {
  YouTubeService({BaseJSChallengeSolver? jsSolver})
      : _yt = YoutubeExplode(jsSolver: jsSolver);

  final YoutubeExplode _yt;
  final _innertube = InnertubeManifestClient();
  String? _ffmpegPath;

  /// Last fetched bundle (metadata + manifest). Reused so the download tap
  /// right after "Get Qualities" — and the info fetch itself when a quality
  /// was already probed — needs no further network round-trips. Media URLs
  /// stay valid for ~6h; a stale cache is detected by the retry helper.
  DtBundle? _lastBundle;
  String? _lastBundleId;

  // ═══════════════════════════════════════════════════════════════
  //  UNIFIED MANIFEST RESOLUTION
  // ═══════════════════════════════════════════════════════════════

  /// Resolve everything needed about one video — metadata (title, artwork,
  /// duration) plus the format manifest — from a single network request.
  ///
  /// Primary source is our own innertube VISIONOS client (see
  /// innertube_manifest.dart): direct signed URLs, full file length, no
  /// server-side serving quota. The youtube_explode manifest is used only
  /// as a fallback (and to expose muxed streams on machines without
  /// FFmpeg, given visionos serves adaptive streams only).
  Future<DtBundle> _getBundle(
    String videoIdValue, {
    bool forceRefresh = false,
  }) async {
    final cached = _lastBundle;
    if (!forceRefresh && cached != null && _lastBundleId == videoIdValue) {
      return cached;
    }

    DtBundle? dt;
    final hasMergeTools = await hasFfmpeg();
    try {
      dt = await _innertube.getBundle(videoIdValue);
    } catch (_) {}

    // visionos worked and FFmpeg is not available → enrich with muxed
    // streams so downloads remain possible without the merge step.
    if (dt != null && !hasMergeTools) {
      try {
        final lib = await _yt.videos.streamsClient
            .getManifest(VideoId(videoIdValue));
        dt = DtBundle(
          meta: dt.meta,
          manifest: DtManifest(
            muxed: [...lib.muxed.map(_dtFromLibMuxed), ...dt.manifest.muxed],
            videoOnly: dt.manifest.videoOnly,
            audioOnly: dt.manifest.audioOnly,
          ),
        );
      } catch (_) {}
    }

    if (dt == null) {
      // Library fallback. Its watch-page visit also provides the metadata
      // when the innertube response carried no videoDetails.
      final lib = await _yt.videos.streamsClient
          .getManifest(VideoId(videoIdValue));
      final libVideo = lib.videoOnly.map(_dtFromLibVideoOnly).toList();
      if (libVideo.isEmpty) {
        throw Exception('No downloadable streams found for this video');
      }
      var title = '';
      var author = '';
      var thumbnail = '';
      var duration = 0;
      try {
        final video = await _yt.videos.get(VideoId(videoIdValue));
        title = video.title;
        author = video.author;
        thumbnail = video.thumbnails.highResUrl;
        duration = video.duration?.inSeconds ?? 0;
      } catch (_) {}
      dt = DtBundle(
        meta: DtVideoMeta(
          title: title,
          author: author,
          thumbnailUrl: thumbnail,
          durationSeconds: duration,
        ),
        manifest: DtManifest(
          muxed: lib.muxed.map(_dtFromLibMuxed).toList(),
          videoOnly: libVideo,
          audioOnly: lib.audioOnly.map(_dtFromLibAudioOnly).toList(),
        ),
      );
    }

    _lastBundle = dt;
    _lastBundleId = videoIdValue;
    return dt;
  }

  /// Titles may be missing from rare innertube responses; one library call
  /// fills the gap.
  Future<String> _resolveTitle(DtBundle bundle, VideoId videoId) async {
    final t = bundle.meta?.title;
    if (t != null && t.trim().isNotEmpty) return _sanitizeFilename(t);
    final video = await _yt.videos.get(videoId);
    return _sanitizeFilename(video.title);
  }

  /// Media URLs expire after a few hours; if a cached bundle turns stale the
  /// job is retried once with a freshly fetched manifest.
  Future<String> _withBundleRetry(
    String url,
    Future<String> Function(VideoId videoId, DtBundle bundle) job,
  ) async {
    final videoId = VideoId(url);
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      final bundle = await _getBundle(videoId.value, forceRefresh: attempt > 0);
      try {
        return await job(videoId, bundle);
      } on PlaylistCancelled {
        rethrow;
      } catch (e) {
        lastError = e;
        _lastBundle = null;
        _lastBundleId = null;
      }
    }
    throw lastError!;
  }

  DtStream _dtFromLibMuxed(MuxedStreamInfo s) => DtStream(
        itag: s.tag,
        url: s.url,
        container: s.container.name,
        qualityLabel: s.qualityLabel,
        width: s.videoResolution.width,
        height: s.videoResolution.height,
        isAudio: false,
        bitrate: s.bitrate.bitsPerSecond,
        contentLength: s.size.totalBytes,
      );

  DtStream _dtFromLibVideoOnly(VideoOnlyStreamInfo s) => DtStream(
        itag: s.tag,
        url: s.url,
        container: s.container.name,
        qualityLabel: s.qualityLabel,
        width: s.videoResolution.width,
        height: s.videoResolution.height,
        isAudio: false,
        bitrate: s.bitrate.bitsPerSecond,
        contentLength: s.size.totalBytes,
      );

  DtStream _dtFromLibAudioOnly(AudioStreamInfo s) => DtStream(
        itag: s.tag,
        url: s.url,
        container: s.container.name,
        qualityLabel: s.qualityLabel,
        width: 0,
        height: 0,
        isAudio: true,
        bitrate: s.bitrate.bitsPerSecond,
        contentLength: s.size.totalBytes,
      );

  // ═══════════════════════════════════════════════════════════════
  //  FFmpeg helpers (desktop only)
  // ═══════════════════════════════════════════════════════════════

  /// Locate ffmpeg. Returns the binary path, or null when unavailable.
  Future<String?> findFfmpeg() async {
    if (_ffmpegPath != null) return _ffmpegPath;
    if (Platform.isAndroid || Platform.isIOS) return null;

    final exeName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final sep = Platform.isWindows ? '\\' : '/';

    // 1) Bundled next to the app executable (or in its data folder)
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      for (final dir in [exeDir, '$exeDir${sep}data', '$exeDir${sep}flutter${sep}windows']) {
        final candidate = '$dir$sep$exeName';
        if (await File(candidate).exists()) {
          _ffmpegPath = candidate;
          return _ffmpegPath;
        }
      }
    } catch (_) {}

    // 2) On PATH
    try {
      if (Platform.isWindows) {
        final res = await Process.run('where', [exeName]);
        if (res.exitCode == 0) {
          final lines = res.stdout
              .toString()
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty);
          for (final p in lines) {
            if (await File(p).exists()) {
              _ffmpegPath = p;
              return _ffmpegPath;
            }
          }
        }
      } else {
        final res = await Process.run(exeName, ['-version']);
        if (res.exitCode == 0) {
          _ffmpegPath = exeName;
          return _ffmpegPath;
        }
      }
    } catch (_) {}

    // 3) Common Windows install locations
    if (Platform.isWindows) {
      final found = await _scanCommonFfmpegLocations();
      if (found != null) {
        _ffmpegPath = found;
        return _ffmpegPath;
      }
    }

    return null;
  }

  Future<bool> hasFfmpeg() async => await findFfmpeg() != null;

  Future<String?> _scanCommonFfmpegLocations() async {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    if (localAppData.isEmpty) return null;
    try {
      // WinGet Gyan.FFmpeg layout: ...\Gyan.FFmpeg<ver>\ffmpeg-<ver>\bin\ffmpeg.exe
      final wingetPackages = Directory('$localAppData\\Microsoft\\WinGet\\Packages');
      if (await wingetPackages.exists()) {
        await for (final pkg in wingetPackages.list()) {
          if (pkg is Directory && pkg.path.contains('Gyan.FFmpeg')) {
            await for (final sub in pkg.list(recursive: true)) {
              if (sub is Directory && sub.path.endsWith('\\bin')) {
                final candidate = '${sub.path}\\ffmpeg.exe';
                if (await File(candidate).exists()) return candidate;
              }
            }
          }
        }
      }
      // imageio-ffmpeg bundled binary (installed with the local Python backend)
      final pythonRoot = Directory('$localAppData\\Python');
      if (await pythonRoot.exists()) {
        await for (final py in pythonRoot.list()) {
          if (py is! Directory) continue;
          final ip = Directory('${py.path}\\Lib\\site-packages\\imageio_ffmpeg\\binaries');
          if (!await ip.exists()) continue;
          await for (final f in ip.list()) {
            if (f is File &&
                f.path.contains('ffmpeg') &&
                f.path.toLowerCase().endsWith('.exe')) {
              return f.path;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Transcode a downloaded audio/video file to MP3 in place.
  /// Returns the output path, or null when conversion failed.
  Future<String?> convertToMp3({
    required String inputPath,
    required String outputPath,
    required int bitrateKbps,
  }) async {
    final ffmpeg = await findFfmpeg();
    if (ffmpeg == null) return null;
    try {
      final res = await Process.run(ffmpeg, [
        '-y', '-i', inputPath, '-vn',
        '-codec:a', 'libmp3lame', '-b:a', '${bitrateKbps}k',
        outputPath,
      ]);
      if (res.exitCode != 0 || !await File(outputPath).exists()) return null;
      final src = File(inputPath);
      if (await src.exists()) await src.delete();
      return outputPath;
    } catch (_) {
      return null;
    }
  }

  /// Merge a video-only stream and an audio stream into one MP4
  /// (stream copy — no re-encode).
  /// Returns the output path, or null when merging failed.
  Future<String?> mergeIntoMp4({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    final ffmpeg = await findFfmpeg();
    if (ffmpeg == null) return null;
    try {
      final res = await Process.run(ffmpeg, [
        '-y', '-i', videoPath, '-i', audioPath,
        '-map', '0:v:0', '-map', '1:a:0', '-c', 'copy', '-shortest',
        outputPath,
      ]);
      if (res.exitCode != 0 || !await File(outputPath).exists()) return null;
      await File(videoPath).delete();
      await File(audioPath).delete();
      return outputPath;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  PLAYLISTS (feature parity with the Android app)
  // ═══════════════════════════════════════════════════════════════

  static final RegExp _listIdRegex = RegExp(r'[?&]list=([A-Za-z0-9_-]+)');

  /// Returns the playlist id when [url] points at a playlist, else null.
  static String? extractPlaylistId(String url) =>
      _listIdRegex.firstMatch(url)?.group(1);

  /// Fetch playlist metadata + every entry (title / watch URL / duration).
  Future<PlaylistInfo> fetchPlaylistInfo(String url) async {
    final id = extractPlaylistId(url);
    if (id == null) throw Exception('Not a playlist URL');
    try {
      final playlist = await _yt.playlists.get(id);
      final entries = <PlaylistEntry>[];
      await for (final v in _yt.playlists.getVideos(id)) {
        entries.add(PlaylistEntry(
          url: 'https://www.youtube.com/watch?v=${v.id.value}',
          title: v.title,
          duration: v.duration?.inSeconds ?? 0,
        ));
      }
      if (entries.isEmpty) {
        throw Exception(
            'No videos were found in this playlist (it may be empty or private).');
      }
      return PlaylistInfo(
        title: playlist.title,
        thumbnail: playlist.thumbnails.highResUrl,
        entries: entries,
      );
    } catch (e) {
      throw Exception('Failed to read playlist: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  FETCH VIDEO INFO
  // ═══════════════════════════════════════════════════════════════

  /// Fetch video info and available formats
  Future<VideoInfo> fetchVideoInfo(String url) async {
    try {
      final videoId = VideoId(url);
      // One manifest request provides the metadata AND every format.
      final bundle = await _getBundle(videoId.value);
      final manifest = bundle.manifest;

      final formats = <VideoFormat>[];
      final seenQualities = <String>{};

      // Get the best audio stream size for total size estimation
      int bestAudioSize = 0;
      for (final audio in manifest.audioOnly) {
        if (audio.contentLength > bestAudioSize) {
          bestAudioSize = audio.contentLength;
        }
      }

      // Collect muxed streams (video + audio combined)
      for (final stream in manifest.muxed) {
        final quality = stream.qualityLabel;
        if (seenQualities.contains(quality)) continue;
        seenQualities.add(quality);

        formats.add(VideoFormat(
          formatId: 'muxed_${stream.qualityLabel}_${stream.container}',
          quality: quality,
          ext: stream.container,
          resolution: '${stream.width}×${stream.height}',
          filesize: _formatSize(stream.contentLength),
          hasAudio: true,
        ));
      }

      // Collect video-only streams (higher quality options)
      for (final stream in manifest.videoOnly) {
        final quality = stream.qualityLabel;
        final key = '$quality-${stream.container}';
        if (seenQualities.contains(key)) continue;
        // Skip webm for simplicity (mp4 is more compatible)
        if (stream.container == 'webm') continue;
        seenQualities.add(key);

        // Total size = video + best audio (since we'll merge them)
        final totalSize = stream.contentLength + bestAudioSize;

        formats.add(VideoFormat(
          formatId: 'video_${stream.qualityLabel}_${stream.container}_${stream.itag}',
          quality: quality,
          ext: stream.container,
          resolution: '${stream.width}×${stream.height}',
          filesize: _formatSize(totalSize),
          hasAudio: false,
        ));
      }

      // Sort by resolution height descending (1080p first, like the Android app)
      formats.sort((a, b) {
        final aHeight = _parseHeight(a.resolution);
        final bHeight = _parseHeight(b.resolution);
        return bHeight.compareTo(aHeight);
      });

      var title = bundle.meta?.title ?? '';
      var thumbnail = bundle.meta?.thumbnailUrl ?? '';
      var duration = bundle.meta?.durationSeconds ?? 0;
      if (title.isEmpty || duration <= 0) {
        // videoDetails came through empty — one library call fills the gap.
        try {
          final video = await _yt.videos.get(videoId);
          title = video.title;
          thumbnail = video.thumbnails.highResUrl;
          duration = video.duration?.inSeconds ?? duration;
        } catch (_) {}
      }

      return VideoInfo(
        title: title,
        thumbnail: thumbnail,
        duration: duration,
        formats: formats,
      );
    } catch (e) {
      throw Exception('Failed to get video info: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  DOWNLOAD VIDEO (single)
  // ═══════════════════════════════════════════════════════════════

  /// Download a video (muxed, or video-only merged with audio when FFmpeg
  /// is available — unlocking 1080p+ on desktop).
  Future<String> downloadVideo({
    required String url,
    required String formatId,
    required Function(double progress, String speed) onProgress,
    void Function(String stage)? onStage,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _withBundleRetry(url, (videoId, bundle) async {
        final manifest = bundle.manifest;
        final title = await _resolveTitle(bundle, videoId);
        final dir = await _getDownloadsDir();

        if (formatId.startsWith('muxed_')) {
          // Muxed stream — single download, no merge needed
          final stream = _findMuxedStream(manifest, formatId);
          if (stream == null) throw Exception('Format not found');

          final filePath = '$dir/$title.${stream.container}';
          await _downloadStream(stream, filePath, onProgress,
              cancelToken: cancelToken);
          return filePath;
        } else {
          // Video-only selection
          final videoStream = _findVideoStream(manifest, formatId);
          if (videoStream == null) throw Exception('Format not found');

          // Desktop with FFmpeg: real video+audio merge (1080p+ works)
          if (await hasFfmpeg()) {
            final merged = await _downloadMergedPair(
              manifest: manifest,
              videoStream: videoStream,
              title: title,
              onProgress: onProgress,
              onStage: onStage,
              cancelToken: cancelToken,
            );
            if (merged != null) return merged;
          }

          // Try to find a muxed stream at the same quality
          final muxedFallback = manifest.muxed
              .where((m) => m.qualityLabel == videoStream.qualityLabel)
              .toList();

          if (muxedFallback.isNotEmpty) {
            // Use muxed version (has audio included)
            final filePath = '$dir/$title.${muxedFallback.first.container}';
            await _downloadStream(muxedFallback.first, filePath, onProgress,
                cancelToken: cancelToken);
            return filePath;
          }

          // No muxed version available — download video-only
          final filePath = '$dir/$title.${videoStream.container}';
          await _downloadStream(videoStream, filePath, onProgress,
              cancelToken: cancelToken);
          return filePath;
        }
      });
    } catch (e) {
      throw Exception('Download failed: $e');
    }
  }

  /// Download one playlist entry as a video at most [maxHeight] high.
  Future<String> downloadPlaylistVideo({
    required String url,
    required int maxHeight,
    required Function(double progress, String speed) onProgress,
    void Function(String stage)? onStage,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _withBundleRetry(url, (videoId, bundle) async {
        final manifest = bundle.manifest;
        final title = await _resolveTitle(bundle, videoId);
        final dir = await _getDownloadsDir();

        try {
          // Best mp4 video-only stream under the requested height
          DtStream? bestVideo;
          for (final v in manifest.videoOnly) {
            if (v.container != 'mp4') continue;
            if (v.height > maxHeight) continue;
            if (bestVideo == null ||
                v.height > bestVideo.height ||
                (v.height == bestVideo.height &&
                    v.contentLength > bestVideo.contentLength)) {
              bestVideo = v;
            }
          }
          if (bestVideo != null && await hasFfmpeg()) {
            final merged = await _downloadMergedPair(
              manifest: manifest,
              videoStream: bestVideo,
              title: title,
              onProgress: onProgress,
              onStage: onStage,
              cancelToken: cancelToken,
            );
            if (merged != null) return merged;
          }
        } on PlaylistCancelled {
          rethrow;
        }

        // Fallback: best muxed stream at/under the requested height
        DtStream? muxedBest;
        for (final m in manifest.muxed) {
          if (m.height > maxHeight) continue;
          if (muxedBest == null || m.height > muxedBest.height) {
            muxedBest = m;
          }
        }
        if (muxedBest == null) {
          final all = manifest.muxed.toList();
          if (all.isNotEmpty) {
            all.sort((a, b) => a.height.compareTo(b.height));
            muxedBest = all.last;
          }
        }
        if (muxedBest == null) throw Exception('No downloadable stream found');

        final filePath = '$dir/$title.${muxedBest.container}';
        await _downloadStream(muxedBest, filePath, onProgress,
            cancelToken: cancelToken);
        return filePath;
      });
    } on PlaylistCancelled {
      rethrow;
    } catch (e) {
      throw Exception('Download failed: $e');
    }
  }

  /// Internal helper: download a video-only stream + best audio, then merge.
  /// Returns null (cleaning up temps) when FFmpeg merge is not possible.
  Future<String?> _downloadMergedPair({
    required DtManifest manifest,
    required DtStream videoStream,
    required String title,
    required Function(double progress, String speed) onProgress,
    void Function(String stage)? onStage,
    CancelToken? cancelToken,
  }) async {
    final dir = await _getDownloadsDir();

    final audios = manifest.audioOnly
        .where((a) => a.container == 'm4a')
        .toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
    if (audios.isEmpty) {
      audios.addAll(manifest.audioOnly);
      audios.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    }
    if (audios.isEmpty) return null;
    final audio = audios.first;

    final videoPath = '$dir/$title.uvid.${videoStream.container}';
    final audioPath = '$dir/$title.uaud.${audio.container}';
    final outPath = '$dir/$title.mp4';

    final vBytes = videoStream.contentLength;
    final aBytes = audio.contentLength;
    final totalBytes = vBytes + aBytes;

    try {
      await _downloadStream(videoStream, videoPath,
          (p, s) => onProgress((p * vBytes) / totalBytes, s),
          cancelToken: cancelToken);
      onStage?.call('merging');
      await _downloadStream(audio, audioPath,
          (p, s) => onProgress((vBytes + p * aBytes) / totalBytes, s),
          cancelToken: cancelToken);

      onStage?.call('merging');
      final merged = await mergeIntoMp4(
          videoPath: videoPath, audioPath: audioPath, outputPath: outPath);
      if (merged != null) {
        onProgress(1.0, '');
        return merged;
      }
      // Merge failed — clean temps and let callers fall back
      try {
        if (await File(videoPath).exists()) await File(videoPath).delete();
        if (await File(audioPath).exists()) await File(audioPath).delete();
      } catch (_) {}
      return null;
    } catch (e) {
      // Clean up partial temps on cancel/error
      try {
        if (await File(videoPath).exists()) await File(videoPath).delete();
        if (await File(audioPath).exists()) await File(audioPath).delete();
      } catch (_) {}
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  DOWNLOAD AUDIO (single + playlist MP3)
  // ═══════════════════════════════════════════════════════════════

  /// Download audio and produce a REAL MP3 via FFmpeg when available;
  /// falls back to the raw audio stream (m4a/webm) otherwise.
  Future<String> downloadAudio({
    required String url,
    required String quality,
    required Function(double progress, String speed) onProgress,
    void Function(String stage)? onStage,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _withBundleRetry(url, (videoId, bundle) async {
        final manifest = bundle.manifest;
        final title = await _resolveTitle(bundle, videoId);
        final dir = await _getDownloadsDir();

        final audioStreams = manifest.audioOnly.toList()
          ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

        if (audioStreams.isEmpty) throw Exception('No audio streams found');

        final targetBitrate = int.tryParse(quality) ?? 192;

        // Desktop with FFmpeg: download the best audio, transcode to MP3
        if (await hasFfmpeg()) {
          final audioStream = audioStreams.first;
          final rawPath = '$dir/$title.xau.${audioStream.container}';
          try {
            await _downloadStream(audioStream, rawPath, onProgress,
                cancelToken: cancelToken);
          } catch (e) {
            try {
              if (await File(rawPath).exists()) await File(rawPath).delete();
            } catch (_) {}
            rethrow;
          }

          onStage?.call('converting');
          final mp3Path = '$dir/$title.mp3';
          final out = await convertToMp3(
              inputPath: rawPath, outputPath: mp3Path, bitrateKbps: targetBitrate);
          if (out == null) {
            try {
              if (await File(rawPath).exists()) await File(rawPath).delete();
            } catch (_) {}
            throw Exception('MP3 conversion failed (FFmpeg reported an error)');
          }
          onProgress(1.0, '');
          return out;
        }

        // No FFmpeg — pick the audio stream closest to the target bitrate
        final audioStream = audioStreams.reduce((closest, stream) {
          final closestDiff = (closest.bitrate ~/ 1000 - targetBitrate).abs();
          final streamDiff = (stream.bitrate ~/ 1000 - targetBitrate).abs();
          return streamDiff < closestDiff ? stream : closest;
        });

        final ext = audioStream.container;
        final filePath = '$dir/$title.$ext';

        await _downloadStream(audioStream, filePath, onProgress,
            cancelToken: cancelToken);
        return filePath;
      });
    } on PlaylistCancelled {
      rethrow;
    } catch (e) {
      throw Exception('Audio download failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  LOW-LEVEL STREAM DOWNLOAD
  // ═══════════════════════════════════════════════════════════════

  /// Download a stream to a file with progress tracking.
  ///
  /// Uses plain ranged HTTP requests instead of the library's stream
  /// downloader: YouTube (googlevideo) currently answers any single range
  /// request larger than a few MB with 403 on URLs whose `n` parameter is
  /// unsolved (throttled URLs), so fixed big chunks loop forever. We start
  /// at 2 MB chunks and halve on any server rejection until accepted.
  /// Every await is bounded by a timeout, so nothing can hang silently.
  ///
  /// When [cancelToken] fires mid-download the partial file is deleted
  /// and [PlaylistCancelled] is thrown.
  Future<void> _downloadStream(
    DtStream stream,
    String filePath,
    Function(double progress, String speed) onProgress, {
    CancelToken? cancelToken,
  }) async {
    const connectTimeout = Duration(seconds: 20);
    const stallTimeout = Duration(seconds: 30);

    final file = File(filePath);
    final totalSize = stream.contentLength;
    final url = stream.url;

    int receivedBytes = 0;
    DateTime lastUpdate = DateTime.now();
    int lastBytes = 0;

    void emitProgress() {
      final now = DateTime.now();
      final elapsed = now.difference(lastUpdate).inMilliseconds;
      if (elapsed >= 300) {
        final bytesPerSec = (receivedBytes - lastBytes) / elapsed * 1000;
        final speed = _formatSpeed(bytesPerSec);
        final progress = totalSize > 0 ? receivedBytes / totalSize : 0.0;
        onProgress(progress, speed);
        lastBytes = receivedBytes;
        lastUpdate = now;
      }
    }

    final client = HttpClient()
      ..connectionTimeout = connectTimeout;
    try {
      final sink = file.openWrite();
      try {
        if (totalSize <= 0) {
          // Unknown length — single unrestricted GET streamed straight to disk.
          final req = await client
              .getUrl(url)
              .timeout(connectTimeout);
          final res = await req.close().timeout(connectTimeout);
          if (res.statusCode >= 400) {
            throw HttpException('HTTP ${res.statusCode} for media stream');
          }
          await for (final chunk
              in res.timeout(stallTimeout, onTimeout: (sink) {
            sink.addError(TimeoutException('server stopped sending data'));
          })) {
            if (cancelToken?.requested == true) {
              throw const PlaylistCancelled();
            }
            sink.add(chunk);
            receivedBytes += chunk.length;
            emitProgress();
          }
        } else {
          // Known length — download in adaptive chunks and commit each
          // finished chunk, so a retry never re-downloads committed data.
          int chunkSize =
              2 * 1024 * 1024; // googlevideo rejects multi-MB ranges with 403
          while (receivedBytes < totalSize) {
            if (cancelToken?.requested == true) {
              throw const PlaylistCancelled();
            }
            final committed = await _fetchRange(
              client,
              url,
              from: receivedBytes,
              maxBytes: chunkSize,
              remaining: totalSize - receivedBytes,
              cancelToken: cancelToken,
            );
            sink.add(committed);
            receivedBytes += committed.length;
            emitProgress();
          }
        }
        await sink.flush();
        await sink.close();
        onProgress(1.0, '');
      } catch (e) {
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {}
        // Remove the partial file
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        rethrow;
      }
    } finally {
      client.close(force: true);
    }
  }

  /// Fetch one range from [from] fetch position. Starts with a chunk of at
  /// most [maxBytes]; if the server rejects a big range (4xx) the chunk is
  /// halved (min 128 KB) and retried. Stops reading at exactly the number
  /// of bytes the server confirms, never past [remaining].
  /// Stalled connections are aborted after 30 s and retried (3 tries).
  Future<List<int>> _fetchRange(
    HttpClient client,
    Uri url, {
    required int from,
    required int maxBytes,
    required int remaining,
    CancelToken? cancelToken,
  }) async {
    const connectTimeout = Duration(seconds: 20);
    const stallTimeout = Duration(seconds: 30);

    int chunkSize = maxBytes.clamp(128 * 1024, 8 * 1024 * 1024);
    int attempts = 0;

    while (true) {
      if (attempts++ >= 3) {
        throw Exception(
            'Download stalled: server kept rejecting the media range');
      }
      final end = from + (chunkSize > remaining ? remaining : chunkSize) - 1;
      final expect = end - from + 1;

      try {
        final req = await client.getUrl(url).timeout(connectTimeout);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-$end');
        final res = await req.close().timeout(connectTimeout);

        if (res.statusCode >= 400) {
          // Rejected range — halve and retry from the same position. The
          // body is tiny and the per-call client force-closes sockets.
          if (chunkSize <= 128 * 1024) {
            throw HttpException('HTTP ${res.statusCode} for media range');
          }
          chunkSize ~/= 2;
          attempts--; // a 403 with room to shrink isn't counted as a try
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }

        // Server ignored Range: a 200 body restarts from byte 0 — only
        // acceptable when we asked for exactly the whole remainder.
        final wantsFull = from == 0 && chunkSize >= remaining;
        if (res.statusCode != 206 && !(res.statusCode == 200 && wantsFull)) {
          throw HttpException('Unexpected HTTP ${res.statusCode}');
        }
        if (res.contentLength > expect) {
          // Server ignored the range end — slice defensively if it's a 200.
          throw HttpException('Server ignored range end');
        }

        final body = <int>[];
        await for (final chunk
            in res.timeout(stallTimeout, onTimeout: (sink) {
          sink.addError(TimeoutException('server stopped sending data'));
        })) {
          if (cancelToken?.requested == true) {
            throw const PlaylistCancelled();
          }
          body.addAll(chunk);
          if (body.length >= expect) break; // never trust past the range end
        }
        return body;
      } on PlaylistCancelled {
        rethrow;
      } on HttpException {
        rethrow;
      } catch (e) {
        // Timeout / connection drop — brief pause, then same range again.
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  DtStream? _findMuxedStream(DtManifest manifest, String formatId) {
    for (final stream in manifest.muxed) {
      final id = 'muxed_${stream.qualityLabel}_${stream.container}';
      if (id == formatId) return stream;
    }
    return null;
  }

  DtStream? _findVideoStream(DtManifest manifest, String formatId) {
    for (final stream in manifest.videoOnly) {
      final id = 'video_${stream.qualityLabel}_${stream.container}_${stream.itag}';
      if (id == formatId) return stream;
    }
    return null;
  }

  /// Get the appropriate downloads directory for the current platform
  Future<String> _getDownloadsDir() async {
    if (Platform.isAndroid) {
      // Use external storage Downloads folder on Android
      final dir = Directory('/storage/emulated/0/Download/YouTubeDownloader');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    } else if (Platform.isWindows) {
      // Use user's Downloads folder on Windows
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      if (userProfile.isNotEmpty) {
        final dir = Directory('$userProfile\\Downloads\\YouTubeDownloader');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir.path;
      }
      // Fallback to the current directory when USERPROFILE is unavailable
      return _fallbackDir('\\');
    } else if (Platform.isMacOS || Platform.isLinux) {
      // Use user's Downloads folder on macOS/Linux
      final home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        final dir = Directory('$home/Downloads/YouTubeDownloader');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir.path;
      }
      return _fallbackDir('/');
    } else {
      // iOS or other — fall back to the current directory
      return _fallbackDir('/');
    }
  }

  Future<String> _fallbackDir(String sep) async {
    final dir = Directory('${Directory.current.path}${sep}YouTubeDownloader');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  String _sanitizeFilename(String name) {
    // Remove filesystem-invalid characters but keep Unicode
    name = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Limit length to avoid path issues
    if (name.length > 100) name = name.substring(0, 100);
    return name.isNotEmpty ? name : 'video';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return 'Unknown';
    final mb = bytes / 1024 / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec > 1024 * 1024) {
      return '${(bytesPerSec / 1024 / 1024).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSec > 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${bytesPerSec.toStringAsFixed(0)} B/s';
  }

  int _parseHeight(String resolution) {
    // Parse "1920×1080" → 1080
    final parts = resolution.split('×');
    if (parts.length == 2) return int.tryParse(parts[1]) ?? 0;
    return 0;
  }

  void dispose() {
    _yt.close();
  }
}
