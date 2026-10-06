import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────
//  Public widget — API unchanged from original
// ─────────────────────────────────────────────
class BottomNav extends StatefulWidget {
  final int currentIndex;
  final bool showChat;
  final String role;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showChat = true,
    this.role = 'customer',
  });

  @override
  State<BottomNav> createState() => _BottomNavState();
}

// ─────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────
class _BottomNavState extends State<BottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _prevIndex = 0;

  // ── Tab definitions ─────────────────────────
  List<_NavTab> get _tabs {
    if (widget.role == 'staff') {
      return const [
        _NavTab(
          icon:   Icons.dashboard_outlined,
          active: Icons.dashboard_rounded,
          label:  'Dashboard',
        ),
        _NavTab(
          icon:   Icons.calendar_month_outlined,
          active: Icons.calendar_month_rounded,
          label:  'Rota',
        ),
        _NavTab(
          icon:   Icons.work_outline,
          active: Icons.work_rounded,
          label:  'My Jobs',
        ),
        _NavTab(
          icon:   Icons.chat_bubble_outline,
          active: Icons.chat_bubble_rounded,
          label:  'Messages',
        ),
        _NavTab(
          icon:   Icons.person_outline,
          active: Icons.person_rounded,
          label:  'Profile',
        ),
      ];
    }
    return [
      const _NavTab(
        icon:   Icons.home_outlined,
        active: Icons.home_rounded,
        label:  'Home',
      ),
      const _NavTab(
        icon:   Icons.medical_services_outlined,
        active: Icons.medical_services_rounded,
        label:  'Services',
      ),
      const _NavTab(
        icon:   Icons.calendar_today_outlined,
        active: Icons.calendar_today_rounded,
        label:  'Bookings',
      ),
      if (widget.showChat)
        const _NavTab(
          icon:   Icons.chat_bubble_outline,
          active: Icons.chat_bubble_rounded,
          label:  'Chat',
        ),
      const _NavTab(
        icon:   Icons.person_outline,
        active: Icons.person_rounded,
        label:  'Profile',
      ),
    ];
  }

  Color get _activeColor  =>
      widget.role == 'staff' ? AppTheme.goldDark : AppTheme.navy;
  Color get _bubbleColor  =>
      widget.role == 'staff' ? AppTheme.goldDark : AppTheme.navyDark;
  Color get _bubbleIcon   => Colors.white;

  // ── Lifecycle ────────────────────────────────
  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 380),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.value = 1.0; // start fully settled on initial tab
  }

  @override
  void didUpdateWidget(BottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _prevIndex = old.currentIndex;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tabs  = _tabs;
    final count = tabs.length;

    // Heights
    const double barHeight    = 64.0;  // visible bar area
    const double bubbleR      = 28.0;  // bubble radius
    const double bubbleOffset = 20.0;  // how far bubble rises above bar top
    const double totalHeight  = barHeight + bubbleOffset + bubbleR;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: totalHeight,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final prevFrac = _prevIndex / (count - 1);
            final currFrac = widget.currentIndex / (count - 1);
            final frac     = Tween<double>(begin: prevFrac, end: currFrac)
                .evaluate(_anim);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Bar (CustomPaint) ─────────────────────────
                Positioned(
                  left: 0, right: 0,
                  bottom: 0,
                  height: totalHeight,
                  child: CustomPaint(
                    painter: _LiquidPainter(
                      fraction:    frac,
                      barTop:      bubbleOffset + bubbleR,
                      bubbleR:     bubbleR,
                      color:       _bubbleColor,
                      tabCount:    count,
                    ),
                  ),
                ),

                // ── Tab labels + inactive icons ───────────────
                Positioned(
                  left: 0, right: 0,
                  bottom: 0,
                  height: barHeight,
                  child: Row(
                    children: List.generate(count, (i) {
                      final tab    = tabs[i];
                      final active = i == widget.currentIndex;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onTap(i),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Inactive icon (hidden when active)
                              AnimatedOpacity(
                                opacity:  active ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  tab.icon,
                                  size:  22,
                                  color: AppTheme.textMute,
                                ),
                              ),
                              const SizedBox(height: 3),
                              // Label
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: GoogleFonts.poppins(
                                  fontSize:   10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: active
                                      ? _activeColor
                                      : AppTheme.textMute,
                                ),
                                child: Text(tab.label),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // ── Floating active-tab bubble icon ───────────
                // Positioned absolutely so it matches the painter's cx exactly.
                // We know the Stack fills the full nav width.
                Builder(builder: (ctx) {
                  final screenW = MediaQuery.of(ctx).size.width;
                  final cx      = frac * screenW;
                  return Positioned(
                    left:   cx - bubbleR,
                    top:    bubbleOffset,
                    width:  bubbleR * 2,
                    height: bubbleR * 2,
                    child: GestureDetector(
                      onTap: () => widget.onTap(widget.currentIndex),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            tabs[widget.currentIndex].active,
                            key:   ValueKey(widget.currentIndex),
                            size:  26,
                            color: _bubbleIcon,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CustomPainter — bar with notch + bubble
// ─────────────────────────────────────────────
class _LiquidPainter extends CustomPainter {
  final double fraction;  // 0..1 horizontal position
  final double barTop;    // y where the bar starts
  final double bubbleR;   // bubble radius
  final Color  color;
  final int    tabCount;

  const _LiquidPainter({
    required this.fraction,
    required this.barTop,
    required this.bubbleR,
    required this.color,
    required this.tabCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = fraction * size.width;

    // ── Build bar path with smooth notch cutout ─
    const notchExtra = 10.0; // extra horizontal radius around the circle
    final nr = bubbleR + notchExtra;
    final nl = (cx - nr).clamp(0.0, size.width);
    final nrx = (cx + nr).clamp(0.0, size.width);

    // Bubble centre y sits half-way in the overlap zone
    final bcy = barTop - bubbleR * 0.4;

    final path = Path()
      ..moveTo(0, barTop)
      ..lineTo(nl, barTop)
      // Smooth cubic into the notch dip
      ..cubicTo(
        cx - nr * 0.55, barTop,
        cx - bubbleR * 0.85, bcy + bubbleR * 0.1,
        cx - bubbleR * 0.5,  bcy - bubbleR * 0.45,
      )
      // Arc under the bubble
      ..arcToPoint(
        Offset(cx + bubbleR * 0.5, bcy - bubbleR * 0.45),
        radius:    Radius.circular(bubbleR),
        clockwise: false,
      )
      // Smooth cubic back up to bar level
      ..cubicTo(
        cx + bubbleR * 0.85, bcy + bubbleR * 0.1,
        cx + nr * 0.55, barTop,
        nrx, barTop,
      )
      ..lineTo(size.width, barTop)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    // Shadow
    canvas.drawShadow(path, Colors.black54, 8, false);

    // Bar fill
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);

    // ── Bubble circle ───────────────────────────
    final bubblePath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, bcy), radius: bubbleR));

    canvas.drawShadow(bubblePath, Colors.black45, 12, false);
    canvas.drawCircle(
      Offset(cx, bcy),
      bubbleR,
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LiquidPainter old) =>
      old.fraction != fraction ||
      old.barTop   != barTop   ||
      old.color    != color    ||
      old.tabCount != tabCount;
}

// ─────────────────────────────────────────────
//  Data class
// ─────────────────────────────────────────────
class _NavTab {
  final IconData icon;
  final IconData active;
  final String   label;
  const _NavTab({
    required this.icon,
    required this.active,
    required this.label,
  });
}
