import 'package:flutter/material.dart';

/// Lucide-matched 24x24 stroked vector icons (stroke-width 1.6, round caps/joins)
/// matching `figma-source/src/components/Layout.tsx` and `app.css` `.nav-item > svg`.
enum FigmaIconType {
  layers3,
  layoutDashboard,
  inbox,
  folderKanban,
  timer,
  workflow,
  users,
  settings2,
  search,
  chevronsUpDown,
  chevronDown,
  bookOpen,
  terminal,
  panelLeftClose,
  panelLeftOpen,
  moreHorizontal,
  plus,
}

class FigmaSidebarIcon extends StatelessWidget {
  final FigmaIconType type;
  final double size;
  final Color color;
  final double strokeWidth;

  const FigmaSidebarIcon(
    this.type, {
    super.key,
    this.size = 16.0,
    required this.color,
    this.strokeWidth = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FigmaSidebarIconPainter(
          type: type,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _FigmaSidebarIconPainter extends CustomPainter {
  final FigmaIconType type;
  final Color color;
  final double strokeWidth;

  const _FigmaSidebarIconPainter({
    required this.type,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, size.height / 24.0);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * (24.0 / size.width).clamp(1.0, 1.8) * 0.88
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case FigmaIconType.layers3:
        // Top diamond
        final top = Path()
          ..moveTo(12, 2.5)
          ..lineTo(2.5, 7.5)
          ..lineTo(12, 12.5)
          ..lineTo(21.5, 7.5)
          ..close();
        canvas.drawPath(top, paint);
        // Middle chevron
        final mid = Path()
          ..moveTo(2.5, 12.5)
          ..lineTo(12, 17.5)
          ..lineTo(21.5, 12.5);
        canvas.drawPath(mid, paint);
        // Bottom chevron
        final bot = Path()
          ..moveTo(2.5, 17.2)
          ..lineTo(12, 22.0)
          ..lineTo(21.5, 17.2);
        canvas.drawPath(bot, paint);
        break;

      case FigmaIconType.layoutDashboard:
        canvas.drawRRect(RRect.fromLTRBR(3, 3, 10, 12, const Radius.circular(1.5)), paint);
        canvas.drawRRect(RRect.fromLTRBR(14, 3, 21, 8, const Radius.circular(1.5)), paint);
        canvas.drawRRect(RRect.fromLTRBR(14, 12, 21, 21, const Radius.circular(1.5)), paint);
        canvas.drawRRect(RRect.fromLTRBR(3, 16, 10, 21, const Radius.circular(1.5)), paint);
        break;

      case FigmaIconType.inbox:
        final box = Path()
          ..moveTo(22, 12)
          ..lineTo(18.5, 5.2)
          ..quadraticBezierTo(18.0, 4.0, 16.7, 4.0)
          ..lineTo(7.3, 4.0)
          ..quadraticBezierTo(6.0, 4.0, 5.5, 5.2)
          ..lineTo(2, 12)
          ..lineTo(2, 18)
          ..quadraticBezierTo(2, 20, 4, 20)
          ..lineTo(20, 20)
          ..quadraticBezierTo(22, 20, 22, 18)
          ..close();
        canvas.drawPath(box, paint);
        final tray = Path()
          ..moveTo(2, 12)
          ..lineTo(8, 12)
          ..lineTo(9.8, 15)
          ..lineTo(14.2, 15)
          ..lineTo(16, 12)
          ..lineTo(22, 12);
        canvas.drawPath(tray, paint);
        break;

      case FigmaIconType.folderKanban:
        final folder = Path()
          ..moveTo(4, 20)
          ..lineTo(20, 20)
          ..quadraticBezierTo(22, 20, 22, 18)
          ..lineTo(22, 8)
          ..quadraticBezierTo(22, 6, 20, 6)
          ..lineTo(12.1, 6)
          ..lineTo(10.0, 4)
          ..lineTo(4, 4)
          ..quadraticBezierTo(2, 4, 2, 6)
          ..lineTo(2, 18)
          ..quadraticBezierTo(2, 20, 4, 20)
          ..close();
        canvas.drawPath(folder, paint);
        canvas.drawLine(const Offset(8, 10), const Offset(8, 16), paint);
        canvas.drawLine(const Offset(12, 10), const Offset(12, 13.5), paint);
        canvas.drawLine(const Offset(16, 10), const Offset(16, 15.5), paint);
        break;

      case FigmaIconType.timer:
        canvas.drawLine(const Offset(10, 2), const Offset(14, 2), paint);
        canvas.drawLine(const Offset(12, 14), const Offset(15, 11), paint);
        canvas.drawCircle(const Offset(12, 14), 8, paint);
        break;

      case FigmaIconType.workflow:
        canvas.drawRRect(RRect.fromLTRBR(3, 3, 11, 11, const Radius.circular(2)), paint);
        final connector = Path()
          ..moveTo(7, 11)
          ..lineTo(7, 15)
          ..quadraticBezierTo(7, 17, 9, 17)
          ..lineTo(13, 17);
        canvas.drawPath(connector, paint);
        canvas.drawRRect(RRect.fromLTRBR(13, 13, 21, 21, const Radius.circular(2)), paint);
        break;

      case FigmaIconType.users:
        canvas.drawCircle(const Offset(9, 7), 3.6, paint);
        final u1 = Path()
          ..moveTo(2.5, 20.5)
          ..quadraticBezierTo(2.5, 15, 9, 15)
          ..quadraticBezierTo(15.5, 15, 15.5, 20.5);
        canvas.drawPath(u1, paint);
        final u2Head = Path()
          ..moveTo(15.8, 3.6)
          ..quadraticBezierTo(19, 4.4, 19, 7.2)
          ..quadraticBezierTo(19, 9.8, 16, 10.6);
        canvas.drawPath(u2Head, paint);
        final u2Body = Path()
          ..moveTo(18.5, 15.4)
          ..quadraticBezierTo(21.5, 16.4, 21.5, 20.5);
        canvas.drawPath(u2Body, paint);
        break;

      case FigmaIconType.settings2:
        canvas.drawLine(const Offset(20, 7), const Offset(14, 7), paint);
        canvas.drawLine(const Offset(4, 7), const Offset(8, 7), paint);
        canvas.drawCircle(const Offset(11, 7), 3, paint);
        canvas.drawLine(const Offset(4, 17), const Offset(10, 17), paint);
        canvas.drawLine(const Offset(16, 17), const Offset(20, 17), paint);
        canvas.drawCircle(const Offset(13, 17), 3, paint);
        break;

      case FigmaIconType.search:
        canvas.drawCircle(const Offset(11, 11), 7.5, paint);
        canvas.drawLine(const Offset(16.6, 16.6), const Offset(21, 21), paint);
        break;

      case FigmaIconType.chevronsUpDown:
        final up = Path()
          ..moveTo(7, 9)
          ..lineTo(12, 4)
          ..lineTo(17, 9);
        final down = Path()
          ..moveTo(7, 15)
          ..lineTo(12, 20)
          ..lineTo(17, 15);
        canvas.drawPath(up, paint);
        canvas.drawPath(down, paint);
        break;

      case FigmaIconType.chevronDown:
        final ch = Path()
          ..moveTo(6, 9)
          ..lineTo(12, 15)
          ..lineTo(18, 9);
        canvas.drawPath(ch, paint);
        break;

      case FigmaIconType.bookOpen:
        final leftPage = Path()
          ..moveTo(12, 7)
          ..quadraticBezierTo(10, 4.5, 5, 4.5)
          ..lineTo(2.5, 4.5)
          ..lineTo(2.5, 18)
          ..lineTo(6.5, 18)
          ..quadraticBezierTo(10.5, 18, 12, 20.5);
        final rightPage = Path()
          ..moveTo(12, 7)
          ..quadraticBezierTo(14, 4.5, 19, 4.5)
          ..lineTo(21.5, 4.5)
          ..lineTo(21.5, 18)
          ..lineTo(17.5, 18)
          ..quadraticBezierTo(13.5, 18, 12, 20.5)
          ..lineTo(12, 7);
        canvas.drawPath(leftPage, paint);
        canvas.drawPath(rightPage, paint);
        break;

      case FigmaIconType.terminal:
        final prompt = Path()
          ..moveTo(4, 17)
          ..lineTo(10, 11)
          ..lineTo(4, 5);
        canvas.drawPath(prompt, paint);
        canvas.drawLine(const Offset(12, 19), const Offset(20, 19), paint);
        break;

      case FigmaIconType.panelLeftClose:
        canvas.drawRRect(RRect.fromLTRBR(3, 3, 21, 21, const Radius.circular(2.5)), paint);
        canvas.drawLine(const Offset(9, 3), const Offset(9, 21), paint);
        final arrow = Path()
          ..moveTo(16, 15)
          ..lineTo(13, 12)
          ..lineTo(16, 9);
        canvas.drawPath(arrow, paint);
        break;

      case FigmaIconType.panelLeftOpen:
        canvas.drawRRect(RRect.fromLTRBR(3, 3, 21, 21, const Radius.circular(2.5)), paint);
        canvas.drawLine(const Offset(9, 3), const Offset(9, 21), paint);
        final arrow = Path()
          ..moveTo(14, 9)
          ..lineTo(17, 12)
          ..lineTo(14, 15);
        canvas.drawPath(arrow, paint);
        break;

      case FigmaIconType.moreHorizontal:
        canvas.drawCircle(const Offset(5.5, 12), 1.4, fillPaint);
        canvas.drawCircle(const Offset(12, 12), 1.4, fillPaint);
        canvas.drawCircle(const Offset(18.5, 12), 1.4, fillPaint);
        break;

      case FigmaIconType.plus:
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), paint);
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), paint);
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FigmaSidebarIconPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
