import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// App version shown in the About section.
/// Keep in sync with pubspec.yaml.
const String kAppVersion = '1.1.0+2';

/// Minimal settings page: the save-folder control (same provider state as the
/// desktop strip on the home screen) plus an About block. Grows with the app —
/// future toggles (clipboard auto-detect, history, quality default) land here.
///
/// Rendered inside the home scaffold's content slot on both layouts, so it
/// must not bring its own Scaffold.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final h = _isDesktop ? 32.0 : 16.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(h, 24, h, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Text('Settings',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 20),
                _SectionLabel('Downloads'),
                _SaveFolderCard(),
                SizedBox(height: 24),
                _SectionLabel('About'),
                _AboutCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              color: Color(0xFF888899),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    );
  }
}

// Rounded card container shared by all settings tiles.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141427),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: child,
    );
  }
}

/// Save-to-folder tile — mirrored app state with the home-screen strip:
/// picking in either place updates both.
class _SaveFolderCard extends StatelessWidget {
  const _SaveFolderCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final custom =
              provider.customSaveDir != null && provider.customSaveDir!.isNotEmpty;
          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E38),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_rounded,
                    size: 20, color: Color(0xFF48BB78)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Save to folder',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Tooltip(
                      message: provider.saveDirDisplay,
                      child: Text(
                        provider.saveDirDisplay.isEmpty
                            ? 'Default Downloads folder'
                            : provider.saveDirDisplay +
                                (custom ? '' : '  (default)'),
                        style: const TextStyle(
                            color: Color(0xFF888899), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (custom)
                IconButton(
                  tooltip: 'Restore default Downloads folder',
                  icon: const Icon(Icons.restart_alt_rounded,
                      size: 18, color: Color(0xFF888899)),
                  onPressed: () => provider.setSaveFolder(''),
                ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await getDirectoryPath();
                  if (picked != null) await provider.setSaveFolder(picked);
                },
                icon: const Icon(Icons.edit_location_alt_rounded, size: 15),
                label: const Text('Change',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF667EEA),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final platform = Platform.isWindows
        ? 'Windows'
        : Platform.isAndroid
            ? 'Android'
            : Platform.operatingSystem;
    return _Card(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DownTube',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Version $kAppVersion — $platform',
                    style: const TextStyle(
                        color: Color(0xFF888899), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
