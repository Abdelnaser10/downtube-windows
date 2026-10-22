import 'package:flutter/material.dart';
import '../models/download_task.dart';

class DownloadProgressBar extends StatelessWidget {
  final DownloadTask task;

  const DownloadProgressBar({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    if (task.status == DownloadStatus.idle) {
      return const SizedBox.shrink();
    }

    if (task.status == DownloadStatus.error) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE53E3E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE53E3E).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFC8181)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.error ?? 'Unknown error occurred',
                style: const TextStyle(color: Color(0xFFFC8181)),
              ),
            ),
          ],
        ),
      );
    }

    final isProcessing = task.status == DownloadStatus.processing;
    final isReady = task.status == DownloadStatus.ready;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isReady
                        ? Icons.check_circle_rounded
                        : isProcessing
                            ? Icons.settings_rounded
                            : Icons.download_rounded,
                    color: isReady ? const Color(0xFF48BB78) : const Color(0xFF667EEA),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isReady
                        ? 'Download Complete!'
                        : isProcessing
                            ? 'Processing & Merging...'
                            : 'Downloading...',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (!isProcessing && !isReady)
                Text(
                  task.progress,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667EEA),
                    fontSize: 15,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: isProcessing
                  ? const LinearProgressIndicator(
                      backgroundColor: Color(0xFF2A2A4A),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                    )
                  : LinearProgressIndicator(
                      value: task.progressValue,
                      backgroundColor: const Color(0xFF2A2A4A),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isReady ? const Color(0xFF48BB78) : const Color(0xFF667EEA),
                      ),
                    ),
            ),
          ),
          if (!isProcessing && !isReady && task.speed.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🚀  ${task.speed}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF48BB78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '⏱️  ${task.eta}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667EEA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}
