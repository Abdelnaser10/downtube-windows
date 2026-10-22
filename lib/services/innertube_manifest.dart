// Our own innertube manifest fetch: the VISIONOS client.
//
// Why: youtube_explode's default (ANDROID) stream URLs carry no solved "n"
// parameter and no usable rate-bypass, so googlevideo caps them after a few
// MB. yt-dlp solves the same problem by preferring the VISIONOS (Apple
// Vision Pro) player client: it needs no JS challenges, no PO tokens and no
// watch-page cookies, and it returns signed direct URLs that serve the
// full file length at full speed. The request shape here was derived from
// yt-dlp 2026.8's youtube extractor (extractor/youtube/_base.py → client
// 'visionos') and re-verified against its captured traffic.
import 'dart:convert';
import 'package:http/http.dart' as http;

/// One downloadable media stream (video-only, audio-only or muxed).
class DtStream {
  DtStream({
    required this.itag,
    required this.url,
    required this.container,
    required this.qualityLabel,
    required this.width,
    required this.height,
    required this.isAudio,
    required this.bitrate,
    required this.contentLength,
  });

  final int itag;
  final Uri url;
  final String container; // 'mp4' | 'm4a' | 'webm'
  final String qualityLabel; // '480p', ...
  final int width;
  final int height;
  final bool isAudio;
  final int bitrate; // bits per second
  final int contentLength; // bytes
}

/// Basic video metadata parsed straight from the player response, so the
/// metadata round-trip can never be slower than the manifest itself.
class DtVideoMeta {
  DtVideoMeta({
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.durationSeconds,
  });

  final String title;
  final String author;
  final String thumbnailUrl;
  final int durationSeconds;
}

/// Everything fetchVideoInfo / the download paths need for one video,
/// produced by a single innertube player request.
class DtBundle {
  DtBundle({required this.meta, required this.manifest});

  final DtVideoMeta? meta;
  final DtManifest manifest;
}

/// Format set for one video, split the way the service consumes it.
class DtManifest {
  DtManifest({
    required this.muxed,
    required this.videoOnly,
    required this.audioOnly,
  });

  final List<DtStream> muxed;
  final List<DtStream> videoOnly;
  final List<DtStream> audioOnly;
}

class InnertubeManifestClient {
  InnertubeManifestClient({http.Client? client}) : _http = client ?? http.Client();

  static const _visionosUa =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 '
      '(KHTML, like Gecko) Version/26.0 Safari/605.1.15';
  static const _watchUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  final http.Client _http;
  String? _visitorData;

  /// Fetch metadata + manifest through the VISIONOS innertube client, or
  /// null when the video is not usable through it (bot gate, kids content, …).
  Future<DtBundle?> getBundle(String videoId) async {
    final visitor = _visitorData ??= await _fetchVisitorData(videoId);

    Map<String, dynamic> payload;
    try {
      final res = await _http
          .post(
            Uri.parse(
                'https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': _visionosUa,
              'Origin': 'https://www.youtube.com',
              'X-Youtube-Client-Name': '101',
              'X-Youtube-Client-Version': '1.02',
              'X-Goog-Visitor-Id': ?visitor,
            },
            body: jsonEncode({
              'context': {
                'client': {
                  'clientName': 'VISIONOS',
                  'clientVersion': '1.02',
                  'deviceMake': 'Apple',
                  'deviceModel': 'RealityDevice17,1',
                  'userAgent': _visionosUa,
                  'osName': 'visionOS',
                  'osVersion': '26.5.23O471',
                  'hl': 'en',
                  'timeZone': 'UTC',
                  'utcOffsetMinutes': 0,
                },
              },
              'videoId': videoId,
              'contentCheckOk': true,
              'racyCheckOk': true,
            }),
          )
          .timeout(const Duration(seconds: 30));
      payload = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final playability = payload['playabilityStatus'];
    if (playability is! Map<String, dynamic> || playability['status'] != 'OK') {
      return null;
    }
    final manifest = _parse(payload);
    // A cached visitor token may have expired — retry once with a fresh one.
    if (manifest == null && _visitorData != null) {
      _visitorData = await _fetchVisitorData(videoId);
      return getBundle(videoId);
    }
    if (manifest == null) return null;
    return DtBundle(meta: _parseMeta(payload), manifest: manifest);
  }

  /// Titles and artwork straight from the same player response — no extra
  /// metadata request needed.
  DtVideoMeta? _parseMeta(Map<String, dynamic> payload) {
    final vd = payload['videoDetails'];
    if (vd is! Map<String, dynamic>) return null;
    final title = vd['title'];
    if (title is! String || title.isEmpty) return null;

    var thumbnail = '';
    final thumbs = ((vd['thumbnail'] as Map<String, dynamic>?)?['thumbnails']
        as List?) ??
        const [];
    var bestWidth = -1;
    for (final t in thumbs) {
      if (t is! Map<String, dynamic>) continue;
      final u = t['url'];
      if (u is! String || u.isEmpty) continue;
      final w = _asInt(t['width']) ?? 0;
      if (w >= bestWidth) {
        bestWidth = w;
        thumbnail = u;
      }
    }

    return DtVideoMeta(
      title: title,
      author: (vd['author'] as String?) ?? '',
      thumbnailUrl: thumbnail,
      durationSeconds: _asInt(vd['lengthSeconds']) ?? 0,
    );
  }

  // Temporarily kept so the service compiles while it moves onto bundles.
  Future<DtManifest?> getManifest(String videoId) async =>
      (await getBundle(videoId))?.manifest;

  /// The dedicated visitor_id endpoint costs one ~90 ms round trip; the
  /// watch-page fallback costs a 1 MB+ download.
  Future<String?> _fetchVisitorData(String? videoId) async {
    try {
      final res = await _http
          .post(
            Uri.parse(
                'https://www.youtube.com/youtubei/v1/visitor_id?prettyPrint=false'),
            headers: {
              'Content-Type': 'application/json',
              'Origin': 'https://www.youtube.com',
            },
            body: jsonEncode({
              'context': {
                'client': {
                  'clientName': 'VISIONOS',
                  'clientVersion': '1.02',
                  'deviceMake': 'Apple',
                  'deviceModel': 'RealityDevice17,1',
                  'osName': 'visionOS',
                  'osVersion': '26.5.23O471',
                  'hl': 'en',
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 20));
      final payload = jsonDecode(res.body) as Map<String, dynamic>;
      final ctx = payload['responseContext'];
      if (ctx is Map<String, dynamic>) {
        final vd = ctx['visitorData'];
        if (vd is String && vd.isNotEmpty) return vd;
      }
    } catch (_) {}
    return _fetchVisitorDataFromWatchPage(videoId);
  }

  /// yt-dlp seeds the innertube visitor id from a plain watch-page visit.
  Future<String?> _fetchVisitorDataFromWatchPage(String? videoId) async {
    try {
      final page = (await _http
              .get(
                Uri.parse(
                    'https://www.youtube.com/watch?v=${videoId ?? 'dQw4w9WgXcQ'}&bpctr=9999999999&has_verified=1&hl=en'),
                headers: {'User-Agent': _watchUa},
              )
              .timeout(const Duration(seconds: 30)))
          .body;
      return RegExp(r'"visitorData":"([^"]+)"').firstMatch(page)?.group(1);
    } catch (_) {
      return null;
    }
  }

  DtManifest? _parse(Map<String, dynamic> payload) {
    final streaming = payload['streamingData'];
    if (streaming is! Map<String, dynamic>) return null;

    final muxed = <DtStream>[];
    final videoOnly = <DtStream>[];
    final audioOnly = <DtStream>[];

    for (final raw in [
      ...((streaming['formats'] as List?) ?? const []),
    ]) {
      if (raw is! Map<String, dynamic>) continue;
      final s = _dtStreamFrom(raw);
      if (s != null) muxed.add(s);
    }
    for (final raw in [
      ...((streaming['adaptiveFormats'] as List?) ?? const []),
    ]) {
      if (raw is! Map<String, dynamic>) continue;
      final s = _dtStreamFrom(raw);
      if (s == null) continue;
      if (s.isAudio) {
        audioOnly.add(s);
      } else {
        videoOnly.add(s);
      }
    }

    if (videoOnly.isEmpty) return null;
    return DtManifest(muxed: muxed, videoOnly: videoOnly, audioOnly: audioOnly);
  }

  DtStream? _dtStreamFrom(Map<String, dynamic> raw) {
    final urlRaw = raw['url'];
    if (urlRaw is! String || urlRaw.isEmpty) return null; // direct signed only
    Uri url;
    try {
      url = Uri.parse(urlRaw);
    } catch (_) {
      return null;
    }

    final mime = (raw['mimeType'] as String?) ?? '';
    final base = mime.split(';').first.trim();
    // Audio/mp4 is produced as plain .m4a (yt-dlp naming), matching the
    // library's AudioStreamInfo containers.
    final container = base == 'video/mp4'
        ? 'mp4'
        : base == 'video/webm'
            ? 'webm'
            : base == 'audio/mp4'
                ? 'm4a'
                : base == 'audio/webm' ? 'webm' : base.split('/').last;

    final isAudio = base.startsWith('audio/');
    final itag = raw['itag'];
    final bitrate = _asInt(raw['bitrate']) ?? 0;
    final length = _asInt(raw['contentLength']) ??
        int.tryParse(url.queryParameters['clen'] ?? '');
    if (itag is! int || bitrate <= 0) return null;
    if (length == null || length <= 0) return null;

    int width = _asInt(raw['width']) ?? 0;
    int height = _asInt(raw['height']) ?? 0;
    var label = raw['qualityLabel'] as String?;
    if (isAudio) {
      width = 0;
      height = 0;
    } else if (label == null || label.isEmpty) {
      label = height > 0 ? '${height}p' : 'video';
    }

    return DtStream(
      itag: itag,
      url: url,
      container: container,
      qualityLabel: label ?? 'video',
      width: width,
      height: height,
      isAudio: isAudio,
      bitrate: bitrate,
      contentLength: length,
    );
  }

  int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
