import 'package:flutter/material.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../tasks/domain/models/task_entity.dart';

class HeatmapPainter extends CustomPainter {
  final Map<String, int> dailyCounts; // 'YYYY-MM-DD' -> count
  final TaskEntity task;
  final DateTime startDate; // The first day of the 52-week window (Monday)
  final int totalWeeks;
  final double cellSize;
  final double cellSpacing;
  final double cellRadius;
  final Color emptyColor;
  final String? hoveredDate;

  HeatmapPainter({
    required this.dailyCounts,
    required this.task,
    required this.startDate,
    this.totalWeeks = 53,
    this.cellSize = 12.0,
    this.cellSpacing = 3.0,
    this.cellRadius = 2.5,
    required this.emptyColor,
    this.hoveredDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = task.color;
    final isCounter = task.type == TrackingType.counter;
    final target = (task.dailyTarget != null && task.dailyTarget! > 0)
        ? task.dailyTarget!
        : 1;

    final cellPaint = Paint()..isAntiAlias = true;
    final borderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int col = 0; col < totalWeeks; col++) {
      for (int row = 0; row < 7; row++) {
        final daysOffset = (col * 7) + row;
        final cellDate = startDate.add(Duration(days: daysOffset));
        final dateKey = DateHelper.formatYmd(cellDate);

        // Don't paint dates in the future beyond today
        if (cellDate.isAfter(DateTime.now())) {
          continue;
        }

        final count = dailyCounts[dateKey] ?? 0;
        final isHovered = hoveredDate == dateKey;

        // Calculate fill color based on intensity
        Color fillColor;
        if (count <= 0) {
          fillColor = emptyColor;
        } else if (!isCounter) {
          // Binary task: Completed
          fillColor = baseColor;
        } else {
          // Counter task: 4 intensity tiers based on percentage of daily target
          final ratio = count / target;
          if (ratio < 0.34) {
            fillColor = baseColor.withValues(alpha: 0.35);
          } else if (ratio < 0.67) {
            fillColor = baseColor.withValues(alpha: 0.60);
          } else if (ratio < 1.0) {
            fillColor = baseColor.withValues(alpha: 0.85);
          } else {
            fillColor = baseColor;
          }
        }

        final x = col * (cellSize + cellSpacing);
        final y = row * (cellSize + cellSpacing);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          Radius.circular(cellRadius),
        );

        cellPaint.color = fillColor;
        canvas.drawRRect(rect, cellPaint);

        if (isHovered) {
          borderPaint.color = Colors.white.withValues(alpha: 0.9);
          canvas.drawRRect(rect, borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter oldDelegate) {
    return oldDelegate.dailyCounts != dailyCounts ||
        oldDelegate.task != task ||
        oldDelegate.hoveredDate != hoveredDate ||
        oldDelegate.emptyColor != emptyColor;
  }
}

