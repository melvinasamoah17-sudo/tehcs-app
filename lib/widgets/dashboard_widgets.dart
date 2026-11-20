import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/dash_theme.dart';

// ══════════════════════════════════════════
// BASIC CARD
// ══════════════════════════════════════════
class DashCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const DashCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Dash.card,
          borderRadius: BorderRadius.circular(20),
          border:
              ThemeController.isDark ? Border.all(color: Dash.border) : null,
          boxShadow: [
            BoxShadow(
                color: Dash.shadow, blurRadius: 18, offset: const Offset(0, 6))
          ],
        ),
        child: child,
      );
}

/// Small caps label + big title, like "INTERACTIONS / Follower Stats".
class DashTitle extends StatelessWidget {
  final String kicker;
  final String title;
  final Widget? trailing;
  const DashTitle(
      {super.key, required this.kicker, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kicker.toUpperCase(),
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Dash.textMute)),
            const SizedBox(height: 2),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Dash.text)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]);
}

// ══════════════════════════════════════════
// GRADIENT STAT TILE  (Active Projects / Overdue / Pending / Meetings)
// ══════════════════════════════════════════
class GradientStatTile extends StatelessWidget {
  final String title;
  final int value;
  final int delta; // change vs previous period
  final String periodLabel; // e.g. "last 7 days"
  final List<Color> colors;
  final IconData icon;
  final VoidCallback? onTap;

  const GradientStatTile({
    super.key,
    required this.title,
    required this.value,
    required this.delta,
    required this.periodLabel,
    required this.colors,
    required this.icon,
    this.onTap,
  });

  static const green = [Color(0xFF8BD06A), Color(0xFF5DB043)];
  static const red = [Color(0xFFF26B78), Color(0xFFE2394A)];
  static const yellow = [Color(0xFFFFD66B), Color(0xFFF5B533)];
  static const blue = [Color(0xFF6AA8F7), Color(0xFF3D80E8)];
  static const purple = [Color(0xFFB38CF5), Color(0xFF8B5CF6)];

  @override
  Widget build(BuildContext context) {
    final deltaText = delta == 0
        ? 'No change vs $periodLabel'
        : '${delta.abs()} ${delta > 0 ? 'more' : 'less'} vs $periodLabel';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 128,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: colors.last.withValues(alpha: .35),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(children: [
          Positioned(
            right: -6,
            bottom: -10,
            child: Icon(icon,
                size: 64, color: Colors.white.withValues(alpha: .18)),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const Spacer(),
            Text('$value',
                style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Row(children: [
              if (delta != 0)
                Icon(
                    delta > 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 12,
                    color: Colors.white),
              if (delta != 0) const SizedBox(width: 2),
              Expanded(
                child: Text(deltaText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: .9))),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════
// SPARKLINE CARD  ($1.150 Weekly Income ...)
// ══════════════════════════════════════════
class SparkCard extends StatelessWidget {
  final String value;
  final String label;
  final List<double> points;
  final Color color;
  final int trend; // >0 up, <0 down, 0 flat

  const SparkCard({
    super.key,
    required this.value,
    required this.label,
    required this.points,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final trendIcon = trend > 0
        ? Icons.keyboard_arrow_up_rounded
        : trend < 0
            ? Icons.keyboard_arrow_down_rounded
            : Icons.remove_rounded;
    final trendColor = trend > 0
        ? const Color(0xFF5DB043)
        : trend < 0
            ? AppTheme.red
            : const Color(0xFF3D80E8);
    return Container(
      height: 168,
      decoration: BoxDecoration(
        color: Dash.card,
        borderRadius: BorderRadius.circular(20),
        border: ThemeController.isDark ? Border.all(color: Dash.border) : null,
        boxShadow: [
          BoxShadow(
              color: Dash.shadow, blurRadius: 18, offset: const Offset(0, 6))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          top: 64,
          child: CustomPaint(painter: _SparkPainter(points, color)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: GoogleFonts.poppins(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Dash.text)),
                    ),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Dash.textMid)),
                  ]),
            ),
            Icon(trendIcon, color: trendColor, size: 24),
          ]),
        ),
      ]),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> points;
  final Color color;
  _SparkPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final maxV = points.reduce(math.max);
    final minV = points.reduce(math.min);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    const padTop = 10.0, padBottom = 14.0;
    final h = size.height - padTop - padBottom;
    final dx = size.width / (points.length - 1);

    Offset pt(int i) => Offset(
        i * dx, padTop + h - ((points[i] - minV) / range) * h * .85 - h * .05);

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = pt(i - 1), p1 = pt(i);
      final mid = (p0.dx + p1.dx) / 2;
      line.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: .28),
              color.withValues(alpha: .04)
            ],
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.points != points || old.color != color;
}

// ══════════════════════════════════════════
// BAR CHART  (Consumption by day)
// ══════════════════════════════════════════
class BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;

  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = const Color(0xFF2FB67A),
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter:
              _BarPainter(values, labels, color, Dash.textMute, Dash.border),
        ),
      );
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color, labelColor, gridColor;
  _BarPainter(
      this.values, this.labels, this.color, this.labelColor, this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelH = 22.0, topPad = 18.0;
    final chartH = size.height - labelH - topPad;
    final maxV = math.max(1.0, values.reduce(math.max));
    final slot = size.width / values.length;
    final barW = math.min(26.0, slot * .55);

    // Grid lines
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = topPad + chartH * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final bh = v <= 0 ? 3.0 : math.max(6.0, chartH * v / maxV);
      final x = slot * i + (slot - barW) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, topPad + chartH - bh, barW, bh),
        topLeft: const Radius.circular(7),
        topRight: const Radius.circular(7),
      );
      canvas.drawRRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: .45)],
            ).createShader(rect.outerRect));

      // Value above the bar
      if (v > 0) {
        _text(canvas, v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1),
            Offset(x + barW / 2, topPad + chartH - bh - 14), 10, labelColor,
            bold: true);
      }
      // Label under the bar
      if (i < labels.length) {
        _text(canvas, labels[i], Offset(x + barW / 2, size.height - labelH + 6),
            10, labelColor);
      }
    }
  }

  void _text(Canvas c, String s, Offset center, double fs, Color col,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: fs,
              color: col,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.values != values ||
      old.color != color ||
      old.labelColor != labelColor;
}

// ══════════════════════════════════════════
// PROGRESS ROW  (Website Launch — Developing 2/6)
// ══════════════════════════════════════════
class ProgressRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String trailing;
  final double progress; // 0..1

  const ProgressRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: .75), color]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: .35),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Dash.text)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 4,
                  color: color,
                  backgroundColor: Dash.field,
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: Dash.textMute)),
                ),
                Text(trailing,
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: Dash.textMute)),
              ]),
            ]),
          ),
        ]),
      );
}

// ══════════════════════════════════════════
// DAY / NIGHT TOGGLE  (glowing moon / sun)
// ══════════════════════════════════════════
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = ThemeController.isDark;
    return Tooltip(
      message: dark ? 'Switch to day mode' : 'Switch to night mode',
      child: GestureDetector(
        onTap: ThemeController.toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? const Color(0xFF0E7490) : const Color(0xFFFFF4DB),
            border: Border.all(
                color: dark ? const Color(0xFF22D3EE) : AppTheme.gold,
                width: 2),
            boxShadow: [
              BoxShadow(
                  color: (dark ? const Color(0xFF22D3EE) : AppTheme.gold)
                      .withValues(alpha: .45),
                  blurRadius: 14),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (c, a) => RotationTransition(
                turns: Tween(begin: .5, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: c)),
            child: Icon(
              dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              key: ValueKey(dark),
              color: dark ? Colors.white : AppTheme.goldDark,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
// BOTTOM NAV  (Home · Features · Pages · Search · Settings)
// ══════════════════════════════════════════
class DashNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const DashNavItem(this.icon, this.activeIcon, this.label);
}

class DashBottomNav extends StatelessWidget {
  final List<DashNavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final int? badgeIndex;
  final int badgeCount;

  const DashBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
    this.badgeIndex,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final active = ThemeController.isDark ? AppTheme.gold : AppTheme.red;
    return Container(
      decoration: BoxDecoration(
        color: Dash.bar,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Dash.shadow, blurRadius: 20, offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onTap(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Badge(
                          isLabelVisible: badgeIndex == i && badgeCount > 0,
                          label: Text('$badgeCount'),
                          backgroundColor: AppTheme.red,
                          child: Icon(
                            i == index ? items[i].activeIcon : items[i].icon,
                            size: 24,
                            color: i == index ? active : Dash.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(items[i].label,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: i == index
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == index ? active : Dash.textMid)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Last 7 days ▾" selector.
class PeriodSelector extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;
  const PeriodSelector(
      {super.key, required this.days, required this.onChanged});

  static const options = {
    7: 'Last 7 days',
    30: 'Last 30 days',
    90: 'Last 90 days'
  };

  @override
  Widget build(BuildContext context) => DashCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: days,
            isExpanded: true,
            dropdownColor: Dash.card,
            borderRadius: BorderRadius.circular(14),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: Dash.textMute),
            style: GoogleFonts.inter(fontSize: 14, color: Dash.textMid),
            items: [
              for (final e in options.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ),
      );
}
