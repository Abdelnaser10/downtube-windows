import 'package:flutter/material.dart';
import '../models/video_info.dart';

class QualityCard extends StatelessWidget {
  final VideoFormat format;
  final bool isSelected;
  final VoidCallback onTap;

  const QualityCard({
    super.key,
    required this.format,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF667EEA).withValues(alpha: 0.15) : const Color(0xFF1A1A2E),
          border: Border.all(
            color: isSelected ? const Color(0xFF667EEA) : const Color(0xFF2A2A4A),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            if (format.hasAudio)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF48BB78),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '🔊',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  format.quality,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '.${format.ext} • ${format.resolution}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888899),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  format.filesize,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667EEA),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
