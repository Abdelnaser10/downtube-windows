enum DownloadStatus {
  idle,
  downloading,
  processing,
  ready,
  error,
}

class DownloadTask {
  final DownloadStatus status;
  final String progress;
  final String speed;
  final String eta;
  final String? downloadId;
  final String? error;
  final String? filePath;

  DownloadTask({
    this.status = DownloadStatus.idle,
    this.progress = '0%',
    this.speed = '',
    this.eta = '',
    this.downloadId,
    this.error,
    this.filePath,
  });

  DownloadTask copyWith({
    DownloadStatus? status,
    String? progress,
    String? speed,
    String? eta,
    String? downloadId,
    String? error,
    String? filePath,
  }) {
    return DownloadTask(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      downloadId: downloadId ?? this.downloadId,
      error: error ?? this.error,
      filePath: filePath ?? this.filePath,
    );
  }

  double get progressValue {
    final cleaned = progress.replaceAll('%', '').trim();
    final val = double.tryParse(cleaned) ?? 0;
    return (val / 100).clamp(0.0, 1.0);
  }
}
