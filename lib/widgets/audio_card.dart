import 'package:flutter/material.dart';

class AudioCard extends StatelessWidget {
  final String bitrate;
  final String label;
  final String size;
  final bool isSelected;
  final VoidCallback onTap;

  const AudioCard({
    super.key,
    required this.bitrate,
    required this.label,
    required this.size,
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
          color: isSelected ? const Color(0xFF764BA2).withValues(alpha: 0.15) : const Color(0xFF1A1A2E),
          border: Border.all(
            color: isSelected ? const Color(0xFF764BA2) : const Color(0xFF2A2A4A),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF764BA2).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$bitrate kbps',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF764BA2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF888899),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              size,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB794F4),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'MP3',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF555577),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
