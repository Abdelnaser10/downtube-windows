class VideoFormat {
  final String formatId;
  final String quality;
  final String ext;
  final String resolution;
  final String filesize;
  final bool hasAudio;

  VideoFormat({
    required this.formatId,
    required this.quality,
    required this.ext,
    required this.resolution,
    required this.filesize,
    required this.hasAudio,
  });

  factory VideoFormat.fromJson(Map<String, dynamic> json) {
    return VideoFormat(
      formatId: json['format_id'] ?? '',
      quality: json['quality'] ?? 'unknown',
      ext: json['ext'] ?? 'mp4',
      resolution: json['resolution'] ?? 'unknown',
      filesize: json['filesize'] ?? 'Unknown',
      hasAudio: json['has_audio'] ?? false,
    );
  }
}

class VideoInfo {
  final String title;
  final String thumbnail;
  final int duration;
  final List<VideoFormat> formats;

  VideoInfo({
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.formats,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      title: json['title'] ?? 'Unknown',
      thumbnail: json['thumbnail'] ?? '',
      duration: json['duration'] ?? 0,
      formats: (json['formats'] as List<dynamic>?)
              ?.map((f) => VideoFormat.fromJson(f))
              .toList() ??
          [],
    );
  }
}
