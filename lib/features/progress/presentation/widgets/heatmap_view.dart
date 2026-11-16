import 'package:flutter/material.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../tasks/domain/models/task_entity.dart';
import 'heatmap_painter.dart';

class HeatmapView extends StatefulWidget {
  final TaskEntity task;
  final Map<String, int> dailyCounts;
  final Function(String date)? onCellTapped;

  const HeatmapView({
    super.key,
    required this.task,
    required this.dailyCounts,
    this.onCellTapped,
  });

  @override
  State<HeatmapView> createState() => _HeatmapViewState();
}

class _HeatmapViewState extends State<HeatmapView> {
  String? _hoveredDate;
  Offset? _hoverPosition;

  static const double _cellSize = 12.0;
  static const double _cellSpacing = 3.5;
  static const int _totalWeeks = 53;

  late final DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Align to start from the Monday ~52 weeks ago
    final todayWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    final currentWeekMonday = now.subtract(Duration(days: todayWeekday - 1));
    _startDate = currentWeekMonday.subtract(const Duration(days: 7 * (_totalWeeks - 1)));
  }

  void _onHover(PointerEvent event) {
    final localX = event.localPosition.dx;
    final localY = event.localPosition.dy;

    final col = (localX / (_cellSize + _cellSpacing)).floor();
    final row = (localY / (_cellSize + _cellSpacing)).floor();

    if (col >= 0 && col < _totalWeeks && row >= 0 && row < 7) {
      final daysOffset = (col * 7) + row;
      final date = _startDate.add(Duration(days: daysOffset));

      if (!date.isAfter(DateTime.now())) {
        final dateKey = DateHelper.formatYmd(date);
        setState(() {
          _hoveredDate = dateKey;
          _hoverPosition = event.localPosition;
        });
        return;
      }
    }

    if (_hoveredDate != null) {
      setState(() {
        _hoveredDate = null;
        _hoverPosition = null;
      });
    }
  }

  void _onExit(PointerEvent event) {
    setState(() {
      _hoveredDate = null;
      _hoverPosition = null;
    });
  }

  void _onTap() {
    if (_hoveredDate != null && widget.onCellTapped != null) {
      widget.onCellTapped!(_hoveredDate!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyColor = isDark
        ? const Color(0xFF1E293B) // Dark slate
        : const Color(0xFFE2E8F0); // Light gray slate

    final totalWidth = _totalWeeks * (_cellSize + _cellSpacing);
    final totalHeight = 7 * (_cellSize + _cellSpacing);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day labels + Grid Canvas
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekday labels (Mon, Wed, Fri)
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: SizedBox(
                height: totalHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _weekdayLabel('Sen'),
                    _weekdayLabel('Rab'),
                    _weekdayLabel('Jum'),
                    _weekdayLabel('Min'),
                  ],
                ),
              ),
            ),

            // Scrollable canvas on desktop / mobile
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true, // Auto scroll to the most recent date on the right!
                child: MouseRegion(
                  onHover: _onHover,
                  onExit: _onExit,
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _onTap,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          size: Size(totalWidth, totalHeight),
                          painter: HeatmapPainter(
                            dailyCounts: widget.dailyCounts,
                            task: widget.task,
                            startDate: _startDate,
                            totalWeeks: _totalWeeks,
                            cellSize: _cellSize,
                            cellSpacing: _cellSpacing,
                            emptyColor: emptyColor,
                            hoveredDate: _hoveredDate,
                          ),
                        ),
                        // Tooltip when hovered
                        if (_hoveredDate != null && _hoverPosition != null)
                          _buildHoverTooltip(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Legend row (Less -> More)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Kurang',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 4),
            _legendBox(emptyColor),
            const SizedBox(width: 2),
            _legendBox(widget.task.color.withValues(alpha: 0.35)),
            const SizedBox(width: 2),
            _legendBox(widget.task.color.withValues(alpha: 0.60)),
            const SizedBox(width: 2),
            _legendBox(widget.task.color.withValues(alpha: 0.85)),
            const SizedBox(width: 2),
            _legendBox(widget.task.color),
            const SizedBox(width: 4),
            Text(
              'Lebih',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _weekdayLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildHoverTooltip(BuildContext context) {
    final count = widget.dailyCounts[_hoveredDate!] ?? 0;
    final date = DateHelper.parseYmd(_hoveredDate!);
    final dateDisplay = DateHelper.formatDisplay(date);

    String detail;
    if (widget.task.type == TrackingType.binary) {
      detail = count > 0 ? '✓ Selesai' : 'Belum selesai';
    } else {
      final target = widget.task.dailyTarget ?? 0;
      final unit = widget.task.unit ?? '';
      final percent = target > 0 ? ((count / target) * 100).toInt() : 0;
      detail = '$count / $target $unit ($percent%)';
    }

    final posX = (_hoverPosition!.dx - 60).clamp(0.0, 700.0);
    final posY = _hoverPosition!.dy < 40 ? _hoverPosition!.dy + 20 : _hoverPosition!.dy - 48;

    return Positioned(
      left: posX,
      top: posY,
      child: IgnorePointer(
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF020617), // Deep dark tooltip
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateDisplay,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 10,
                    color: count > 0 ? widget.task.color : Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

