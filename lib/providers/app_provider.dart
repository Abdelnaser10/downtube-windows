import 'package:flutter/material.dart';
import '../models/video_info.dart';
import '../models/download_task.dart';
import '../models/playlist_info.dart';
import '../services/youtube_service.dart';

/// Snapshot of the playlist pane + batch run state.
class PlaylistState {
  final PlaylistInfo? info;
  final bool isFetching;
  final String selectedHeight; // video tab batch quality
  final String selectedBitrate; // audio tab batch quality
  final String? error;

  // Batch run
  final bool running;
  final bool finished;
  final bool wasStopped;
  final int currentIndex;
  final int total;
  final String currentLabel; // e.g. "Video 3/12 — Title" or final summary
  final String currentStage; // '', 'merging', 'converting'
  final double combinedProgress; // 0..1
  final String speed;
  final List<PlaylistItemResult> results;

  const PlaylistState({
    this.info,
    this.isFetching = false,
    this.selectedHeight = '720',
    this.selectedBitrate = '192',
    this.error,
    this.running = false,
    this.finished = false,
    this.wasStopped = false,
    this.currentIndex = 0,
    this.total = 0,
    this.currentLabel = '',
    this.currentStage = '',
    this.combinedProgress = 0,
    this.speed = '',
    this.results = const [],
  });

  PlaylistState copyWith({
    PlaylistInfo? info,
    bool? isFetching,
    String? selectedHeight,
    String? selectedBitrate,
    String? error,
    bool clearError = false,
    bool? running,
    bool? finished,
    bool? wasStopped,
    int? currentIndex,
    int? total,
    String? currentLabel,
    String? currentStage,
    double? combinedProgress,
    String? speed,
    List<PlaylistItemResult>? results,
  }) {
    return PlaylistState(
      info: info ?? this.info,
      isFetching: isFetching ?? this.isFetching,
      selectedHeight: selectedHeight ?? this.selectedHeight,
      selectedBitrate: selectedBitrate ?? this.selectedBitrate,
      error: clearError ? null : (error ?? this.error),
      running: running ?? this.running,
      finished: finished ?? this.finished,
      wasStopped: wasStopped ?? this.wasStopped,
      currentIndex: currentIndex ?? this.currentIndex,
      total: total ?? this.total,
      currentLabel: currentLabel ?? this.currentLabel,
      currentStage: currentStage ?? this.currentStage,
      combinedProgress: combinedProgress ?? this.combinedProgress,
      speed: speed ?? this.speed,
      results: results ?? this.results,
    );
  }
}

class AppProvider extends ChangeNotifier {
  final YouTubeService _ytService = YouTubeService();

  // URL input
  String _url = '';
  String get url => _url;

  // Video info
  VideoInfo? _videoInfo;
  VideoInfo? get videoInfo => _videoInfo;
  bool _isFetchingInfo = false;
  bool get isFetchingInfo => _isFetchingInfo;

  // Selection state
  VideoFormat? _selectedFormat;
  VideoFormat? get selectedFormat => _selectedFormat;
  String _selectedAudioQuality = '192';
  String get selectedAudioQuality => _selectedAudioQuality;

  // Download state
  DownloadTask _downloadTask = DownloadTask();
  DownloadTask get downloadTask => _downloadTask;

  // Playlist state
  PlaylistState _playlist = const PlaylistState();
  PlaylistState get playlist => _playlist;
  final CancelToken _playlistCancelToken = CancelToken();

  // Error
  String? _error;
  String? get error => _error;

  // Downloaded file path
  String? _downloadedFilePath;
  String? get downloadedFilePath => _downloadedFilePath;

  void setUrl(String url) {
    _url = url;
  }

  void selectFormat(VideoFormat format) {
    _selectedFormat = format;
    notifyListeners();
  }

  void selectAudioQuality(String quality) {
    _selectedAudioQuality = quality;
    notifyListeners();
  }

  String playlistIdOf(String url) => YouTubeService.extractPlaylistId(url) ?? '';

  void selectPlaylistHeight(String height) {
    _playlist = _playlist.copyWith(selectedHeight: height);
    notifyListeners();
  }

  void selectPlaylistBitrate(String bitrate) {
    _playlist = _playlist.copyWith(selectedBitrate: bitrate);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════
  //  FETCH INFO (routes videos vs playlists, like the Android app)
  // ═══════════════════════════════════════════════════════
  Future<void> fetchInfo() async {
    final url = _url.trim();
    if (url.isEmpty) {
      _error = 'Please enter a YouTube URL';
      notifyListeners();
      return;
    }

    final playlistId = YouTubeService.extractPlaylistId(url);
    if (playlistId != null) {
      // YouTube Mixes ("RD…") are unviewable as playlists — when the URL also
      // carries a video, fall back to that single video (Android behavior).
      if (playlistId.startsWith('RD')) {
        final isWatch = url.contains('watch?v=') || url.contains('youtu.be/');
        if (isWatch) {
          _playlist = const PlaylistState();
          notifyListeners();
          return fetchVideoInfo();
        }
        _error = 'YouTube Mixes cannot be downloaded as playlists.';
        _playlist = const PlaylistState();
        _videoInfo = null;
        notifyListeners();
        return;
      }
      return _fetchPlaylist();
    }

    _playlist = const PlaylistState();
    notifyListeners();
    return fetchVideoInfo();
  }

  // ═══════════════════════════════════════════════════════
  //  FETCH VIDEO INFO
  // ═══════════════════════════════════════════════════════
  Future<void> fetchVideoInfo() async {
    if (_url.trim().isEmpty) {
      _error = 'Please enter a YouTube URL';
      notifyListeners();
      return;
    }

    _isFetchingInfo = true;
    _error = null;
    _videoInfo = null;
    _selectedFormat = null;
    _downloadTask = DownloadTask();
    notifyListeners();

    try {
      _videoInfo = await _ytService.fetchVideoInfo(_url.trim());
      _error = null;
    } catch (e) {
      _error = _parseError(e);
      _videoInfo = null;
    } finally {
      _isFetchingInfo = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════
  //  FETCH PLAYLIST INFO
  // ═══════════════════════════════════════════════════════
  Future<void> _fetchPlaylist() async {
    _isFetchingInfo = true;
    _error = null;
    _videoInfo = null;
    _selectedFormat = null;
    _downloadTask = DownloadTask();
    _playlist = const PlaylistState(isFetching: true, error: null);
    notifyListeners();

    try {
      final info = await _ytService.fetchPlaylistInfo(_url.trim());
      _playlist = PlaylistState(info: info);
      _error = null;
    } catch (e) {
      _playlist = const PlaylistState();
      _error = _parseError(e);
    } finally {
      _isFetchingInfo = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════
  //  DOWNLOAD VIDEO
  // ═══════════════════════════════════════════════════════
  Future<void> startVideoDownload() async {
    if (_selectedFormat == null || _url.trim().isEmpty) return;

    _downloadTask = DownloadTask(status: DownloadStatus.downloading);
    _downloadedFilePath = null;
    _error = null;
    notifyListeners();

    try {
      final filePath = await _ytService.downloadVideo(
        url: _url.trim(),
        formatId: _selectedFormat!.formatId,
        onProgress: (progress, speed) {
          _downloadTask = DownloadTask(
            status: DownloadStatus.downloading,
            progress: '${(progress * 100).toStringAsFixed(1)}%',
            speed: speed,
            eta: '',
          );
          notifyListeners();
        },
      );

      _downloadedFilePath = filePath;
      _downloadTask = DownloadTask(
        status: DownloadStatus.ready,
        progress: '100%',
      );
      notifyListeners();
    } catch (e) {
      _downloadTask = DownloadTask(
        status: DownloadStatus.error,
        error: _parseError(e),
      );
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════
  //  DOWNLOAD AUDIO
  // ═══════════════════════════════════════════════════════
  Future<void> startMp3Download() async {
    if (_url.trim().isEmpty) return;

    _downloadTask = DownloadTask(status: DownloadStatus.downloading);
    _downloadedFilePath = null;
    _error = null;
    notifyListeners();

    try {
      final filePath = await _ytService.downloadAudio(
        url: _url.trim(),
        quality: _selectedAudioQuality,
        onProgress: (progress, speed) {
          _downloadTask = DownloadTask(
            status: DownloadStatus.downloading,
            progress: '${(progress * 100).toStringAsFixed(1)}%',
            speed: speed,
            eta: '',
          );
          notifyListeners();
        },
      );

      _downloadedFilePath = filePath;
      _downloadTask = DownloadTask(
        status: DownloadStatus.ready,
        progress: '100%',
      );
      notifyListeners();
    } catch (e) {
      _downloadTask = DownloadTask(
        status: DownloadStatus.error,
        error: _parseError(e),
      );
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════
  //  PLAYLIST BATCH DOWNLOAD
  //  - downloads entries one by one
  //  - keeps every finished file when stopped
  //  - skips failing entries and lists them in the summary
  // ═══════════════════════════════════════════════════════
  Future<void> startPlaylistDownload({required bool isVideo}) async {
    final info = _playlist.info;
    if (info == null || _playlist.running) return;

    final entries = info.entries;
    final total = entries.length;

    _playlistCancelToken.requested = false;
    _error = null;
    _playlist = _playlist.copyWith(
      running: true,
      finished: false,
      wasStopped: false,
      clearError: true,
      currentIndex: 0,
      total: total,
      results: [],
      currentLabel: 'Starting…',
      currentStage: '',
      combinedProgress: 0,
      speed: '',
    );
    notifyListeners();

    // Warm the FFmpeg cache once (also reports availability in the label)
    await _ytService.findFfmpeg();

    var stopped = false;

    for (var i = 0; i < total; i++) {
      if (_playlistCancelToken.requested) {
        stopped = true;
        break;
      }
      final entry = entries[i];
      final kind = isVideo ? 'Video' : 'Track';
      _playlist = _playlist.copyWith(
        currentIndex: i,
        currentLabel: '$kind ${i + 1}/$total — ${entry.title}',
        currentStage: '',
        speed: '',
      );
      notifyListeners();

      try {
        if (isVideo) {
          await _ytService.downloadPlaylistVideo(
            url: entry.url,
            maxHeight: int.tryParse(_playlist.selectedHeight) ?? 720,
            onProgress: (p, s) => _onPlaylistItemProgress(i, total, p, s),
            onStage: (stage) => _onPlaylistItemStage(stage, i, total),
            cancelToken: _playlistCancelToken,
          );
        } else {
          await _ytService.downloadAudio(
            url: entry.url,
            quality: _playlist.selectedBitrate,
            onProgress: (p, s) => _onPlaylistItemProgress(i, total, p, s),
            onStage: (stage) => _onPlaylistItemStage(stage, i, total),
            cancelToken: _playlistCancelToken,
          );
        }
        _playlist = _playlist.copyWith(
          results: [
            ..._playlist.results,
            PlaylistItemResult(title: entry.title, status: PlaylistItemStatus.done),
          ],
        );
      } on PlaylistCancelled {
        // Stop pressed mid-stream: partial file already deleted.
        _playlist = _playlist.copyWith(
          results: [
            ..._playlist.results,
            PlaylistItemResult(title: entry.title, status: PlaylistItemStatus.skipped),
          ],
        );
        stopped = true;
        break;
      } catch (e) {
        // Skip failing videos, keep the loop alive (Android parity)
        _playlist = _playlist.copyWith(
          results: [
            ..._playlist.results,
            PlaylistItemResult(
              title: entry.title,
              status: PlaylistItemStatus.failed,
              error: _parseError(e),
            ),
          ],
        );
      }

      _playlist = _playlist.copyWith(
        combinedProgress: (i + 1) / total,
        currentLabel: '',
      );
    }

    final doneCount =
        _playlist.results.where((r) => r.status == PlaylistItemStatus.done).length;
    final failedCount =
        _playlist.results.where((r) => r.status == PlaylistItemStatus.failed).length;

    String summary;
    if (stopped) {
      summary = 'Stopped — $doneCount of $total saved';
    } else if (failedCount > 0) {
      summary = 'Complete — $doneCount of $total saved ($failedCount unavailable)';
    } else {
      summary = 'Complete — $doneCount of $total saved';
    }

    _playlist = _playlist.copyWith(
      running: false,
      finished: true,
      wasStopped: stopped,
      currentLabel: summary,
      currentStage: '',
      speed: '',
      combinedProgress: stopped ? _playlist.combinedProgress : 1.0,
    );
    notifyListeners();
  }

  void _onPlaylistItemProgress(int index, int total, double itemProgress, String speed) {
    if (!_playlist.running) return;
    _playlist = _playlist.copyWith(
      combinedProgress: (index + itemProgress) / total,
      speed: speed,
    );
    notifyListeners();
  }

  void _onPlaylistItemStage(String stage, int index, int total) {
    if (!_playlist.running) return;
    const stageNames = {'merging': 'Merging', 'converting': 'Converting to MP3'};
    _playlist = _playlist.copyWith(
      currentStage: stage,
      currentLabel:
          '${stageNames[stage] ?? stage} ${index + 1}/$total — ${_playlist.info!.entries[index].title}',
      speed: '',
    );
    notifyListeners();
  }

  /// Request a stop: everything already finished stays on disk.
  void cancelPlaylistDownload() {
    if (!_playlist.running) return;
    _playlistCancelToken.requested = true;
    _playlist = _playlist.copyWith(currentLabel: 'Stopping after the current item…');
    notifyListeners();
  }

  void resetDownload() {
    _downloadTask = DownloadTask();
    _downloadedFilePath = null;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    // Clean up exception wrapping
    if (msg.startsWith('Exception: ')) {
      return msg.substring(11);
    }
    return msg;
  }

  @override
  void dispose() {
    _ytService.dispose();
    super.dispose();
  }
}
