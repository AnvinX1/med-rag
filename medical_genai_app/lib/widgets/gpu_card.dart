import 'package:flutter/material.dart';
import '../models.dart';

class GpuCard extends StatelessWidget {
  final GpuInfo gpu;

  const GpuCard({super.key, required this.gpu});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.developer_board, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'GPU ${gpu.index}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  gpu.name,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // VRAM
            _progressRow(
              context,
              'VRAM',
              '${gpu.memoryUsedMb.toStringAsFixed(0)} / ${gpu.memoryTotalMb.toStringAsFixed(0)} MB',
              gpu.memoryPercent / 100,
              _getMemColor(gpu.memoryPercent),
            ),
            const SizedBox(height: 10),

            // Utilization
            _progressRow(
              context,
              'Utilization',
              '${gpu.utilization.toStringAsFixed(0)}%',
              gpu.utilization / 100,
              _getUtilColor(gpu.utilization),
            ),
            const SizedBox(height: 12),

            // Temp & Power
            Row(
              children: [
                _infoChip(
                  Icons.thermostat,
                  '${gpu.temperature.toStringAsFixed(0)}°C',
                  _getTempColor(gpu.temperature),
                ),
                const SizedBox(width: 8),
                _infoChip(
                  Icons.bolt,
                  '${gpu.powerDraw.toStringAsFixed(1)}W',
                  Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressRow(
    BuildContext context,
    String label,
    String value,
    double progress,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withAlpha(150),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            backgroundColor: cs.surfaceContainerHighest,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMemColor(double percent) {
    if (percent > 80) return Colors.red;
    if (percent > 50) return Colors.orange;
    return Colors.green;
  }

  Color _getUtilColor(double percent) {
    if (percent > 80) return Colors.red;
    if (percent > 50) return Colors.orange;
    return Colors.teal;
  }

  Color _getTempColor(double temp) {
    if (temp > 80) return Colors.red;
    if (temp > 60) return Colors.orange;
    return Colors.blue;
  }
}
