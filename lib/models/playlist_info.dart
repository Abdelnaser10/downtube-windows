/// Playlist models + batch-download runtime state
/// (feature parity with the Android/DownTube playlists).
library;

class PlaylistEntry {
  final String url;
  final String title;
  final int duration; // seconds, 0 when unknown

  const PlaylistEntry({
    required this.url,
    required this.title,
    required this.duration,
  });
}

class PlaylistInfo {
  final String title;
  final String thumbnail;
  final List<PlaylistEntry> entries;

  const PlaylistInfo({
    required this.title,
    required this.thumbnail,
    required this.entries,
  });
}

enum PlaylistItemStatus { done, failed, skipped }

class PlaylistItemResult {
  final String title;
  final PlaylistItemStatus status;
  final String? error;

  const PlaylistItemResult({
    required this.title,
    required this.status,
    this.error,
  });
}

/// Cooperative cancel flag for batch downloads. The current stream stops
/// mid-download, its partial file is deleted, and everything already
/// finished stays on disk (Android behavior).
class CancelToken {
  bool requested = false;
}

/// Thrown when a batch is cancelled mid-stream.
class PlaylistCancelled implements Exception {
  const PlaylistCancelled();

  @override
  String toString() => 'Cancelled by user';
}
