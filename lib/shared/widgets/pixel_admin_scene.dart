import 'dart:math' as math;

import 'package:flutter/material.dart';

class PixelAdminScene extends StatefulWidget {
  const PixelAdminScene({super.key});

  @override
  State<PixelAdminScene> createState() => _PixelAdminSceneState();
}

class _PixelAdminSceneState extends State<PixelAdminScene>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Semantics(
      image: true,
      label:
          'Minh họa pixel quản trị viên gõ phím, chớp mắt và theo dõi biểu đồ chuyển động',
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: 1536,
            height: 1024,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/admin-office-wide-base.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  excludeFromSemantics: true,
                ),
                AnimatedBuilder(
                  animation: _motion,
                  child: Image.asset(
                    'assets/images/admin-office-wide-typing.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                    excludeFromSemantics: true,
                  ),
                  builder: (context, child) {
                    final t = _motion.value;
                    return ClipPath(
                      clipper: _PoseClipper(
                        typing: (t * 48).floor().isOdd && t % .5 < .34,
                        blink: t > .43 && t < .45 || t > .87 && t < .89,
                      ),
                      child: child,
                    );
                  },
                ),
                CustomPaint(
                  painter: _DashboardPainter(_motion),
                  isComplex: true,
                  willChange: !MediaQuery.disableAnimationsOf(context),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PoseClipper extends CustomClipper<Path> {
  const _PoseClipper({required this.typing, required this.blink});
  final bool typing, blink;

  @override
  Path getClip(Size size) => Path()
    ..addRect(typing ? const Rect.fromLTWH(675, 615, 298, 116) : Rect.zero)
    ..addRect(blink ? const Rect.fromLTWH(543, 250, 30, 34) : Rect.zero);

  @override
  bool shouldReclip(covariant _PoseClipper oldClipper) =>
      oldClipper.typing != typing || oldClipper.blink != blink;
}

class _DashboardPainter extends CustomPainter {
  _DashboardPainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;
  final _brush = Paint()..isAntiAlias = false;

  Offset plot(double u, double v) {
    final top = Offset.lerp(
      const Offset(899, 329),
      const Offset(1087, 329),
      u,
    )!;
    final bottom = Offset.lerp(
      const Offset(899, 407),
      const Offset(1087, 411),
      u,
    )!;
    return Offset.lerp(top, bottom, v)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final t = motion.value;
    final panel = Path()
      ..addPolygon([plot(0, 0), plot(1, 0), plot(1, 1), plot(0, 1)], true);
    canvas.drawPath(panel, _brush..color = const Color(0xFFE9EDF4));
    for (var row = 1; row < 5; row++) {
      canvas.drawLine(
        plot(0, row / 5),
        plot(1, row / 5),
        Paint()
          ..color = const Color(0xFFD1DFEC)
          ..strokeWidth = 1
          ..isAntiAlias = false,
      );
    }
    const heights = [.25, .43, .61, .75, .87, .96];
    for (var index = 0; index < heights.length; index++) {
      final height =
          heights[index] * (.86 + .12 * math.sin(t * math.pi * 4 + index));
      final left = .03 + index * .16;
      final right = left + .104;
      final bar = Path()
        ..addPolygon([
          plot(left, 1 - height),
          plot(right, 1 - height),
          plot(right, .96),
          plot(left, .96),
        ], true);
      canvas.drawPath(
        bar,
        _brush
          ..color = index == (t * heights.length).floor()
              ? const Color(0xFF58B8FF)
              : const Color(0xFF5486DC),
      );
    }

    final donutGlint = Paint()
      ..color = const Color(0xFFB2F1FF).withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..isAntiAlias = false;
    canvas.drawArc(
      const Rect.fromLTWH(1134, 327, 87, 98),
      t * math.pi * 2,
      math.pi / 3,
      false,
      donutGlint,
    );

    final row = (t * 4).floor();
    canvas.drawRect(
      Rect.fromLTWH(1259, 508 + row * 24, 8, 6),
      _brush
        ..color = const Color(
          0xFF39C882,
        ).withValues(alpha: .5 + .4 * math.sin(t * math.pi * 8).abs()),
    );

    if ((t * 48).floor().isOdd && t % .5 < .34) {
      canvas.drawRect(
        const Rect.fromLTWH(915, 714, 14, 3),
        _brush..color = const Color(0xFF73CBF5),
      );
      canvas.drawRect(
        const Rect.fromLTWH(978, 700, 12, 3),
        _brush..color = const Color(0xFF73CBF5),
      );
    }

    final cursorX = 1068 + math.sin(t * math.pi * 2) * 30;
    final cursorY = 452 + math.sin(t * math.pi * 4) * 12;
    final cursor = Path()
      ..addPolygon([
        Offset(cursorX, cursorY),
        Offset(cursorX + 4, cursorY + 24),
        Offset(cursorX + 11, cursorY + 17),
        Offset(cursorX + 20, cursorY + 17),
      ], true);
    canvas.drawPath(cursor, _brush..color = Colors.white);
    canvas.drawPath(
      cursor,
      Paint()
        ..color = const Color(0xFF344F70)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..isAntiAlias = false,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DashboardPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
