import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A premium "Open Barrier" press-and-hold button
/// Drop-in replacement for FingerprintButton — same callbacks, same hold duration.
class OpenBarrierButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Duration holdDuration;
  final double size;

  const OpenBarrierButton({
    super.key,
    this.onPressed,
    this.holdDuration = const Duration(seconds: 2),
    this.size = 120,
  });

  @override
  State<OpenBarrierButton> createState() => _OpenBarrierButtonState();
}

class _OpenBarrierButtonState extends State<OpenBarrierButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _ringAnimation;
  bool _isPressed = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _ringAnimation = Tween<double>(
      begin: 1.0,
      end: 1.35,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isSuccess = true;
          _isPressed = false;
        });
        widget.onPressed?.call();
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() => _isSuccess = false);
            _controller.reset();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (_isSuccess) return;
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails _) => _cancel();
  void _handleTapCancel() => _cancel();

  void _cancel() {
    if (_controller.isAnimating) {
      _controller.reverse();
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final glowOpacity = _glowAnimation.value;

          // Color interpolation: idle blue → success green
          final Color coreColor = _isSuccess
              ? const Color(0xFF00E676)
              : Color.lerp(
                  const Color(0xFF1565C0),
                  const Color(0xFF42A5F5),
                  progress,
                )!;

          final Color glowColor = _isSuccess
              ? const Color(0xFF00E676)
              : const Color(0xFF64B5F6);

          return SizedBox(
            width: widget.size + 40,
            height: widget.size + 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Outermost ambient glow ──────────────────────────────
                if (_isPressed || _isSuccess)
                  Transform.scale(
                    scale: _ringAnimation.value,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withOpacity(0.25 * glowOpacity),
                            blurRadius: 32,
                            spreadRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Segmented arc progress ring ─────────────────────────
                if (_isPressed || _isSuccess)
                  SizedBox(
                    width: widget.size + 10,
                    height: widget.size + 10,
                    child: CustomPaint(
                      painter: _SegmentedArcPainter(
                        progress: _isSuccess ? 1.0 : progress,
                        color: glowColor,
                        segments: 12,
                      ),
                    ),
                  ),

                // ── Thin outer ring (idle state) ────────────────────────
                if (!_isPressed && !_isSuccess)
                  Container(
                    width: widget.size + 10,
                    height: widget.size + 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),

                // ── Main button body ────────────────────────────────────
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        radius: 1.1,
                        colors: _isSuccess
                            ? [const Color(0xFF00E676), const Color(0xFF00897B)]
                            : [
                                Color.lerp(
                                  const Color(0xFF1565C0),
                                  const Color(0xFF1E88E5),
                                  progress,
                                )!,
                                Color.lerp(
                                  const Color(0xFF0D2B6B),
                                  const Color(0xFF1565C0),
                                  progress,
                                )!,
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: coreColor.withOpacity(0.5 + 0.3 * glowOpacity),
                          blurRadius: 16 + 16 * glowOpacity,
                          spreadRadius: 2 + 4 * glowOpacity,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Inner rim highlight
                        Container(
                          width: widget.size - 8,
                          height: widget.size - 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.12),
                                Colors.transparent,
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                          ),
                        ),

                        // Icon + label
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _isSuccess
                                  ? const Icon(
                                      Icons.check_rounded,
                                      key: ValueKey('check'),
                                      color: Colors.white,
                                      size: 36,
                                    )
                                  : _BarrierIcon(
                                      key: const ValueKey('barrier'),
                                      progress: progress,
                                      size: 36,
                                    ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                color: Colors.white.withOpacity(
                                  _isSuccess ? 1.0 : (0.7 + 0.3 * progress),
                                ),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                                fontFamily: 'monospace',
                              ),
                              child: Text(
                                _isSuccess
                                    ? 'OPENED'
                                    : (_isPressed ? 'OPENING…' : 'HOLD'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Barrier lift icon (animated arm) ──────────────────────────────────────

class _BarrierIcon extends StatelessWidget {
  final double progress;
  final double size;

  const _BarrierIcon({super.key, required this.progress, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BarrierIconPainter(progress: progress)),
    );
  }
}

class _BarrierIconPainter extends CustomPainter {
  final double progress;
  _BarrierIconPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final armPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final postPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Base post (left vertical)
    canvas.drawLine(
      Offset(w * 0.22, h * 0.85),
      Offset(w * 0.22, h * 0.40),
      postPaint,
    );

    // Hinge dot
    canvas.drawCircle(
      Offset(w * 0.22, h * 0.40),
      2.5,
      Paint()..color = Colors.white,
    );

    // Barrier arm: rotates from horizontal (0°) to ~75° up as progress → 1
    final angle = -progress * (math.pi * 0.72); // 0 → -130°
    final armLength = w * 0.64;
    final pivot = Offset(w * 0.22, h * 0.40);
    final armEnd = Offset(
      pivot.dx + armLength * math.cos(angle),
      pivot.dy + armLength * math.sin(angle),
    );

    // Striped arm (alternating segments)
    final segments = 5;
    for (int i = 0; i < segments; i++) {
      final t0 = i / segments;
      final t1 = (i + 0.7) / segments;
      final p0 = Offset(
        pivot.dx + armLength * t0 * math.cos(angle),
        pivot.dy + armLength * t0 * math.sin(angle),
      );
      final p1 = Offset(
        pivot.dx + armLength * t1 * math.cos(angle),
        pivot.dy + armLength * t1 * math.sin(angle),
      );
      final segPaint = Paint()
        ..color = (i.isEven ? Colors.white : Colors.white.withOpacity(0.45))
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p0, p1, segPaint);
    }

    // Tip dot
    canvas.drawCircle(armEnd, 2.0, Paint()..color = Colors.white);

    // Ground line (road)
    canvas.drawLine(
      Offset(w * 0.05, h * 0.85),
      Offset(w * 0.95, h * 0.85),
      basePaint..color = Colors.white.withOpacity(0.35),
    );
  }

  @override
  bool shouldRepaint(_BarrierIconPainter old) => old.progress != progress;
}

// ─── Segmented arc progress painter ────────────────────────────────────────

class _SegmentedArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int segments;

  _SegmentedArcPainter({
    required this.progress,
    required this.color,
    required this.segments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    const gapDeg = 6.0;
    final segDeg = (360.0 - segments * gapDeg) / segments;
    const startOffset = -90.0;

    for (int i = 0; i < segments; i++) {
      final segStart = startOffset + i * (segDeg + gapDeg);
      final segFillRatio = ((progress * segments) - i).clamp(0.0, 1.0);
      if (segFillRatio <= 0) continue;

      final paint = Paint()
        ..color = color.withOpacity(0.3 + 0.7 * segFillRatio)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawArc(
        rect,
        _deg2rad(segStart),
        _deg2rad(segDeg * segFillRatio),
        false,
        paint,
      );
    }
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  @override
  bool shouldRepaint(_SegmentedArcPainter old) =>
      old.progress != progress || old.color != color;
}
