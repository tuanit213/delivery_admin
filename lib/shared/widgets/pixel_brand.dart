import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PixelWordmark extends StatelessWidget {
  const PixelWordmark({
    super.key,
    this.pixelSize = 4,
    this.color = AppColors.text,
  });
  final double pixelSize;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'LogiRoute',
    header: true,
    child: ExcludeSemantics(
      child: SizedBox(
        width: 53 * pixelSize,
        height: 7 * pixelSize,
        child: CustomPaint(painter: _WordmarkPainter(pixelSize, color)),
      ),
    ),
  );
}

class _WordmarkPainter extends CustomPainter {
  const _WordmarkPainter(this.unit, this.color);
  final double unit;
  final Color color;
  static const glyphs = <String, List<String>>{
    'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
    'O': ['01110', '11011', '10001', '10001', '10001', '11011', '01110'],
    'G': ['01111', '11000', '10000', '10111', '10001', '11001', '01111'],
    'I': ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
    'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
    'U': ['10001', '10001', '10001', '10001', '10001', '11011', '01110'],
    'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
    'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  };
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var i = 0; i < 9; i++) {
      final letter = glyphs['LOGIROUTE'[i]]!;
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 5; x++) {
          if (letter[y][x] == '1') {
            canvas.drawRect(
              Rect.fromLTWH((i * 6 + x) * unit, y * unit, unit, unit),
              paint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WordmarkPainter old) =>
      old.unit != unit || old.color != color;
}

class PixelParcel extends StatelessWidget {
  const PixelParcel({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _ParcelPainter()),
    ),
  );
}

class _ParcelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()..isAntiAlias = false;
    void block(double x, double y, double w, double h, Color c) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), p..color = c);
    }

    block(2, 4, 20, 18, AppColors.text);
    block(4, 6, 16, 14, AppColors.amber);
    block(10, 6, 4, 14, const Color(0xFFFFD991));
    block(2, 2, 8, 2, AppColors.text);
    block(14, 2, 8, 2, AppColors.text);
    block(5, 16, 4, 2, AppColors.text);
  }

  @override
  bool shouldRepaint(covariant _ParcelPainter old) => false;
}

class PixelBrand extends StatelessWidget {
  const PixelBrand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!compact) ...[const PixelParcel(), const SizedBox(width: 12)],
      PixelWordmark(pixelSize: compact ? 3 : 4),
    ],
  );
}

BoxDecoration pixelPanel({Color color = AppColors.panel, double shadow = 5}) =>
    BoxDecoration(
      color: color,
      border: Border.all(color: AppColors.text, width: 2),
      boxShadow: [
        BoxShadow(
          color: AppColors.text.withValues(alpha: .15),
          offset: Offset(shadow, shadow),
        ),
      ],
    );
