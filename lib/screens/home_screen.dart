import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/download_task.dart';
import '../widgets/quality_card.dart';
import '../widgets/audio_card.dart';
import '../widgets/progress_bar.dart';
import '../models/playlist_info.dart';
import '../models/video_info.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _urlController = TextEditingController();
  int _selectedTab = 0; // 0 = Video, 1 = MP3

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  DESKTOP LAYOUT (sidebar + content)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MOBILE LAYOUT (bottom nav + content)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141427),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.download_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'DownTube',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF48BB78),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LOCAL',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141427),
          border: Border(
              top: BorderSide(color: Color(0xFF2A2A4A), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (i) => setState(() => _selectedTab = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF667EEA),
          unselectedItemColor: const Color(0xFF555577),
          selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.video_library_rounded),
              label: 'Video',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.music_note_rounded),
              label: 'MP3',
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SIDEBAR (Desktop only)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF141427),
        border: Border(
            right: BorderSide(color: Color(0xFF2A2A4A), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.download_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DownTube',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('Ultra Fast',
                          style: TextStyle(
                              color: Color(0xFF48BB78),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _sidebarItem(
            icon: Icons.video_library_rounded,
            label: 'Video Download',
            isSelected: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
          _sidebarItem(
            icon: Icons.music_note_rounded,
            label: 'MP3 Download',
            isSelected: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF667EEA).withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: isSelected
                        ? const Color(0xFF667EEA)
                        : Colors.grey.shade500),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade400,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MAIN CONTENT (shared between desktop + mobile)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMainContent() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isDesktop ? 32 : 16,
        vertical: _isDesktop ? 20 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF141427),
        border: _isDesktop
            ? const Border(
                bottom: BorderSide(color: Color(0xFF2A2A4A), width: 1))
            : null,
      ),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E38),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A2A4A)),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Icon(Icons.link_rounded,
                            color: Color(0xFF667EEA), size: 20),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Paste YouTube URL here...',
                            hintStyle: TextStyle(color: Color(0xFF555577)),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onSubmitted: (_) {
                            provider.setUrl(_urlController.text);
                            provider.fetchInfo();
                          },
                          onChanged: (val) => provider.setUrl(val),
                        ),
                      ),
                      if (_urlController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.grey),
                          onPressed: () {
                            _urlController.clear();
                            provider.setUrl('');
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: provider.isFetchingInfo ||
                          _urlController.text.trim().isEmpty
                      ? null
                      : () {
                          provider.setUrl(_urlController.text);
                          provider.fetchInfo();
                        },
                  icon: provider.isFetchingInfo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded, size: 20),
                  label: Text(
                      provider.isFetchingInfo ? 'Fetching...' : 'Get Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.error != null && provider.videoInfo == null) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                color: const Color(0xFFE53E3E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFE53E3E).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFE53E3E), size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(provider.error!,
                        style: const TextStyle(color: Color(0xFFFC8181))),
                  ),
                ],
              ),
            ),
          );
        }

        if (provider.videoInfo == null && provider.playlist.info == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.video_library_outlined,
                    size: 80, color: Colors.grey.shade700),
                const SizedBox(height: 20),
                Text('Paste a YouTube video or playlist URL above to get started',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Downloads directly to your device',
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ],
            ),
          );
        }

        // ── Playlist pane (active regardless of the selected tab, like the app) ──
        if (provider.playlist.info != null) {
          return _buildPlaylistBody(provider);
        }

        final video = provider.videoInfo!;

        // Show completed download snackbar
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (provider.downloadTask.status == DownloadStatus.ready &&
              provider.downloadedFilePath != null) {
            final path = provider.downloadedFilePath!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Saved to: $path'),
                backgroundColor: const Color(0xFF48BB78),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
            provider.resetDownload();
          }
        });

        return SingleChildScrollView(
          padding: EdgeInsets.all(_isDesktop ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVideoHeader(video),
              const SizedBox(height: 24),
              if (provider.downloadTask.status != DownloadStatus.idle) ...[
                DownloadProgressBar(task: provider.downloadTask),
                const SizedBox(height: 24),
              ],
              if (provider.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53E3E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFFC8181), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(provider.error!,
                            style:
                                const TextStyle(color: Color(0xFFFC8181))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (_selectedTab == 0)
                _buildVideoDownloadPanel(provider)
              else
                _buildMp3DownloadPanel(provider, video.duration),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoHeader(dynamic video) {
    if (_isDesktop) {
      // Desktop: side-by-side
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(video.thumbnail,
                width: 280, height: 158, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                    width: 280,
                    height: 158,
                    color: const Color(0xFF1E1E38),
                    child: const Icon(Icons.broken_image,
                        size: 40, color: Colors.grey))),
          ),
          const SizedBox(width: 24),
          Expanded(child: _buildVideoMeta(video)),
        ],
      );
    } else {
      // Mobile: stacked
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(video.thumbnail,
                width: double.infinity, height: 200, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: const Color(0xFF1E1E38),
                    child: const Icon(Icons.broken_image,
                        size: 40, color: Colors.grey))),
          ),
          const SizedBox(height: 16),
          _buildVideoMeta(video),
        ],
      );
    }
  }

  Widget _buildVideoMeta(dynamic video) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(video.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: _isDesktop ? 20 : 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_formatDuration(video.duration),
                  style: const TextStyle(
                      color: Color(0xFF667EEA),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Text('${video.formats.length} formats',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  // ═══════════════════════════════════════════════════════════════
  //  VIDEO DOWNLOAD PANEL
  // ═══════════════════════════════════════════════════════════════
  Widget _buildVideoDownloadPanel(AppProvider provider) {
    final isDownloading =
        provider.downloadTask.status == DownloadStatus.downloading ||
            provider.downloadTask.status == DownloadStatus.processing;

    return Opacity(
      opacity: isDownloading ? 0.5 : 1.0,
      child: IgnorePointer(
        ignoring: isDownloading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Video Quality',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _isDesktop ? 200 : 170,
                mainAxisExtent: 100,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: provider.videoInfo!.formats.length,
              itemBuilder: (context, index) {
                final format = provider.videoInfo!.formats[index];
                return QualityCard(
                  format: format,
                  isSelected: provider.selectedFormat == format,
                  onTap: () => provider.selectFormat(format),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: provider.selectedFormat == null
                    ? null
                    : () => provider.startVideoDownload(),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download Video',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48BB78),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF2A2A4A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MP3 DOWNLOAD PANEL
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMp3DownloadPanel(AppProvider provider, int durationSecs) {
    final audioQualities = [
      {'bitrate': '320', 'label': 'Best Quality'},
      {'bitrate': '192', 'label': 'High Quality'},
      {'bitrate': '128', 'label': 'Standard'},
      {'bitrate': '64', 'label': 'Smaller File'},
    ];

    final isDownloading =
        provider.downloadTask.status == DownloadStatus.downloading ||
            provider.downloadTask.status == DownloadStatus.processing;

    return Opacity(
      opacity: isDownloading ? 0.5 : 1.0,
      child: IgnorePointer(
        ignoring: isDownloading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Audio Quality',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _isDesktop ? 200 : 170,
                mainAxisExtent: 120,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: audioQualities.length,
              itemBuilder: (context, index) {
                final q = audioQualities[index];
                final bitrate = q['bitrate']!;
                final label = q['label']!;
                final sizeMb =
                    (int.parse(bitrate) * durationSecs) / 8 / 1024;
                final sizeText = sizeMb >= 1
                    ? '~${sizeMb.toStringAsFixed(1)} MB'
                    : '~${(sizeMb * 1024).toStringAsFixed(0)} KB';

                return AudioCard(
                  bitrate: bitrate,
                  label: label,
                  size: sizeText,
                  isSelected: provider.selectedAudioQuality == bitrate,
                  onTap: () => provider.selectAudioQuality(bitrate),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: () => provider.startMp3Download(),
                  icon: const Icon(Icons.music_note_rounded),
                  label: const Text(
                    'Download Audio',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PLAYLIST PANE (feature parity with the Android app)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPlaylistBody(AppProvider provider) {
    final info = provider.playlist.info!;
    final running = provider.playlist.running;

    return SingleChildScrollView(
      padding: EdgeInsets.all(_isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlaylistHeader(info),
          const SizedBox(height: 24),
          if (running || provider.playlist.finished) ...[
            _buildPlaylistProgressPanel(provider),
            const SizedBox(height: 24),
          ],
          if (provider.playlist.results.isNotEmpty) ...[
            _buildPlaylistResults(provider),
            const SizedBox(height: 24),
          ],
          Opacity(
            opacity: running ? 0.5 : 1.0,
            child: IgnorePointer(
              ignoring: running,
              child: _selectedTab == 0
                  ? _buildPlaylistVideoChoices(provider)
                  : _buildPlaylistMp3Choices(provider, info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistHeader(PlaylistInfo info) {
    final cover = _isDesktop
        ? SizedBox(
            width: 280,
            height: 158,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                info.thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1E1E38),
                  child: const Icon(Icons.video_library_outlined,
                      size: 40, color: Colors.grey),
                ),
              ),
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              info.thumbnail,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200,
                color: const Color(0xFF1E1E38),
                child: const Icon(Icons.video_library_outlined,
                    size: 40, color: Colors.grey),
              ),
            ),
          );

    final meta = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(info.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: _isDesktop ? 20 : 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF764BA2).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${info.entries.length} videos',
                  style: const TextStyle(
                      color: Color(0xFFB794F4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Saved to Downloads\\YouTubeDownloader',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );

    if (_isDesktop) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        cover,
        const SizedBox(width: 24),
        Expanded(child: meta),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      cover,
      const SizedBox(height: 16),
      meta,
    ]);
  }

  Widget _buildPlaylistVideoChoices(AppProvider provider) {
    final heights = AppProvider.playlistHeights;
    final state = provider.playlist;
    final totals = state.videoTotals;
    final measuring = state.measureTotal > 0 && state.measuredCount < state.measureTotal;

    String fileSizeFor(int h) {
      final t = totals[h];
      if (t != null) return t;
      if (measuring) {
        return 'measuring… ${state.measuredCount}/${state.measureTotal}';
      }
      return 'best match per video';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Video Quality (applies to every video)',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _isDesktop ? 200 : 170,
            mainAxisExtent: 100,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: heights.length,
          itemBuilder: (context, index) {
            final h = heights[index];
            return QualityCard(
              format: VideoFormat(
                formatId: 'playlist_$h',
                quality: '${h}p',
                ext: 'mp4',
                resolution: 'varies per video',
                filesize: fileSizeFor(h),
                hasAudio: false,
              ),
              isSelected: state.selectedHeight == '$h',
              onTap: () => provider.selectPlaylistHeight('$h'),
            );
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => provider.startPlaylistDownload(isVideo: true),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download All Videos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF48BB78),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF2A2A4A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistMp3Choices(AppProvider provider, PlaylistInfo info) {
    const qualityDefs = [
      {'bitrate': '320', 'label': 'Best Quality'},
      {'bitrate': '192', 'label': 'High Quality'},
      {'bitrate': '128', 'label': 'Standard'},
      {'bitrate': '64', 'label': 'Smaller File'},
    ];
    final state = provider.playlist;

    // Total estimate only when every duration is known (honest, like Android)
    final durations = info.entries.map((e) => e.duration).toList();
    final allKnown = durations.every((d) => d > 0);
    final totalSecs = durations.fold<int>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Audio Quality (applies to every video)',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _isDesktop ? 200 : 170,
            mainAxisExtent: 120,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: qualityDefs.length,
          itemBuilder: (context, index) {
            final q = qualityDefs[index];
            final bitrate = q['bitrate']!;
            final label = q['label']!;

            String sizeText = '';
            if (allKnown) {
              final sizeMb = (int.parse(bitrate) * totalSecs) / 8 / 1024;
              sizeText = sizeMb >= 1024
                  ? '~${(sizeMb / 1024).toStringAsFixed(2)} GB total'
                  : '~${sizeMb.toStringAsFixed(1)} MB total';
            }

            return AudioCard(
              bitrate: bitrate,
              label: label,
              size: sizeText,
              isSelected: state.selectedBitrate == bitrate,
              onTap: () => provider.selectPlaylistBitrate(bitrate),
            );
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: () => provider.startPlaylistDownload(isVideo: false),
              icon: const Icon(Icons.music_note_rounded),
              label: const Text(
                'Download All MP3s',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Converted one by one with FFmpeg${allKnown ? '' : ' (some durations unknown — totals hidden)'}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPlaylistProgressPanel(AppProvider provider) {
    final state = provider.playlist;

    IconData headlineIcon;
    Color headlineColor;
    String percentText;

    if (state.finished) {
      headlineIcon = state.wasStopped
          ? Icons.stop_circle_rounded
          : Icons.check_circle_rounded;
      headlineColor = state.wasStopped
          ? const Color(0xFFF6AD55)
          : const Color(0xFF48BB78);
      percentText = '${(state.combinedProgress * 100).toStringAsFixed(0)}%';
    } else {
      headlineIcon = state.currentStage == 'converting'
          ? Icons.settings_rounded
          : state.currentStage == 'merging'
              ? Icons.merge_rounded
              : Icons.download_rounded;
      headlineColor = const Color(0xFF667EEA);
      percentText = '${(state.combinedProgress * 100).toStringAsFixed(1)}%';
    }

    final label = state.currentLabel.isNotEmpty
        ? state.currentLabel
        : (state.running ? 'Working…' : '');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(headlineIcon, color: headlineColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                percentText,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: headlineColor,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: state.combinedProgress,
                backgroundColor: const Color(0xFF2A2A4A),
                valueColor: AlwaysStoppedAnimation<Color>(headlineColor),
              ),
            ),
          ),
          if (state.running && state.speed.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '🚀  ${state.speed}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF48BB78),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (state.running) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: state.currentLabel.startsWith('Stopping')
                    ? null
                    : () => provider.cancelPlaylistDownload(),
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: Text(
                  state.currentLabel.startsWith('Stopping')
                      ? 'Stopping after the current item…'
                      : 'Stop — keeps everything already saved',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF6AD55),
                  disabledForegroundColor:
                      const Color(0xFFF6AD55).withValues(alpha: 0.4),
                  side: const BorderSide(color: Color(0xFFF6AD55), width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaylistResults(AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Playlist items',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.playlist.results.length,
          itemBuilder: (context, index) {
            final r = provider.playlist.results[index];
            final (icon, color, statusText) = switch (r.status) {
              PlaylistItemStatus.done => (
                  Icons.check_circle_rounded,
                  const Color(0xFF48BB78),
                  'saved'
                ),
              PlaylistItemStatus.failed => (
                  Icons.error_rounded,
                  const Color(0xFFFC8181),
                  'failed'
                ),
              PlaylistItemStatus.skipped => (
                  Icons.do_not_disturb_on_rounded,
                  const Color(0xFF555577),
                  'skipped'
                ),
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                border: Border.all(color: const Color(0xFF2A2A4A)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r.title,
                        style: const TextStyle(
                            color: Color(0xFFCCCCCC), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(statusText, style: TextStyle(color: color, fontSize: 11)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
