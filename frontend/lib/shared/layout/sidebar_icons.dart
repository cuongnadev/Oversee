import 'package:flutter/material.dart';

/// Lucide-matched 24x24 stroked vector icons (stroke-width 1.6, round caps/joins)
/// matching `figma-source/src/components/Layout.tsx` and `app.css` `.nav-item > svg`.
enum FigmaIconType {
  layers3,
  layoutDashboard,
  inbox,
  listChecks,
  folderKanban,
  timer,
  flag,
  gitBranch,
  calendar,
  workflow,
  fileText,
  barChart,
  sparkles,
  users,
  bell,
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

      case FigmaIconType.listChecks:
        // Checkmark 1
        final c1 = Path()
          ..moveTo(3, 6.5)
          ..lineTo(4.8, 8.3)
          ..lineTo(8, 5);
        canvas.drawPath(c1, paint);
        canvas.drawLine(const Offset(11.5, 6.5), const Offset(21, 6.5), paint);
        // Checkmark 2
        final c2 = Path()
          ..moveTo(3, 12.5)
          ..lineTo(4.8, 14.3)
          ..lineTo(8, 11);
        canvas.drawPath(c2, paint);
        canvas.drawLine(const Offset(11.5, 12.5), const Offset(21, 12.5), paint);
        // Line 3
        canvas.drawLine(const Offset(3, 18.5), const Offset(7.5, 18.5), paint);
        canvas.drawLine(const Offset(11.5, 18.5), const Offset(21, 18.5), paint);
        break;

      case FigmaIconType.flag:
        canvas.drawLine(const Offset(4.5, 21), const Offset(4.5, 3.5), paint);
        final flagPath = Path()
          ..moveTo(4.5, 14.5)
          ..quadraticBezierTo(8.5, 13, 12, 14.5)
          ..quadraticBezierTo(15.5, 16, 19.5, 14.5)
          ..lineTo(19.5, 4.5)
          ..quadraticBezierTo(15.5, 6, 12, 4.5)
          ..quadraticBezierTo(8.5, 3, 4.5, 4.5);
        canvas.drawPath(flagPath, paint);
        break;

      case FigmaIconType.gitBranch:
        canvas.drawLine(const Offset(6.5, 3.5), const Offset(6.5, 15.5), paint);
        canvas.drawCircle(const Offset(17.5, 6.5), 2.8, paint);
        canvas.drawCircle(const Offset(6.5, 18.2), 2.8, paint);
        final branch = Path()
          ..moveTo(17.5, 9.3)
          ..quadraticBezierTo(17.5, 16.5, 9.3, 18.0);
        canvas.drawPath(branch, paint);
        break;

      case FigmaIconType.calendar:
        canvas.drawRRect(RRect.fromLTRBR(3, 5, 21, 21, const Radius.circular(2.5)), paint);
        canvas.drawLine(const Offset(8, 2.5), const Offset(8, 6.5), paint);
        canvas.drawLine(const Offset(16, 2.5), const Offset(16, 6.5), paint);
        canvas.drawLine(const Offset(3, 10), const Offset(21, 10), paint);
        canvas.drawCircle(const Offset(8, 14.5), 0.9, fillPaint);
        canvas.drawCircle(const Offset(12, 14.5), 0.9, fillPaint);
        canvas.drawCircle(const Offset(16, 14.5), 0.9, fillPaint);
        break;

      case FigmaIconType.fileText:
        final doc = Path()
          ..moveTo(14.5, 2.5)
          ..lineTo(6, 2.5)
          ..quadraticBezierTo(4.5, 2.5, 4.5, 4)
          ..lineTo(4.5, 20)
          ..quadraticBezierTo(4.5, 21.5, 6, 21.5)
          ..lineTo(18, 21.5)
          ..quadraticBezierTo(19.5, 21.5, 19.5, 20)
          ..lineTo(19.5, 7.5)
          ..close();
        canvas.drawPath(doc, paint);
        final fold = Path()
          ..moveTo(14.5, 2.5)
          ..lineTo(14.5, 7.5)
          ..lineTo(19.5, 7.5);
        canvas.drawPath(fold, paint);
        canvas.drawLine(const Offset(8.5, 12.5), const Offset(15.5, 12.5), paint);
        canvas.drawLine(const Offset(8.5, 16.5), const Offset(15.5, 16.5), paint);
        break;

      case FigmaIconType.barChart:
        canvas.drawLine(const Offset(4.5, 20), const Offset(4.5, 14), paint);
        canvas.drawLine(const Offset(9.5, 20), const Offset(9.5, 11), paint);
        canvas.drawLine(const Offset(14.5, 20), const Offset(14.5, 13), paint);
        canvas.drawLine(const Offset(19.5, 20), const Offset(19.5, 8.5), paint);
        final trend = Path()
          ..moveTo(4, 10.5)
          ..lineTo(9.5, 7)
          ..lineTo(14, 9.5)
          ..lineTo(19.5, 4.5);
        canvas.drawPath(trend, paint);
        break;

      case FigmaIconType.sparkles:
        final mainStar = Path()
          ..moveTo(11, 3)
          ..quadraticBezierTo(11, 10.5, 18.5, 11)
          ..quadraticBezierTo(11, 11.5, 11, 19)
          ..quadraticBezierTo(11, 11.5, 3.5, 11)
          ..quadraticBezierTo(11, 10.5, 11, 3)
          ..close();
        canvas.drawPath(mainStar, paint);
        canvas.drawLine(const Offset(19, 16), const Offset(19, 20), paint);
        canvas.drawLine(const Offset(17, 18), const Offset(21, 18), paint);
        canvas.drawLine(const Offset(18.5, 3.5), const Offset(18.5, 6.5), paint);
        canvas.drawLine(const Offset(17, 5), const Offset(20, 5), paint);
        break;

      case FigmaIconType.bell:
        final bellBody = Path()
          ..moveTo(6, 9.5)
          ..quadraticBezierTo(6, 4, 12, 4)
          ..quadraticBezierTo(18, 4, 18, 9.5)
          ..lineTo(18, 14.5)
          ..quadraticBezierTo(18, 16.5, 20, 17.5)
          ..lineTo(4, 17.5)
          ..quadraticBezierTo(6, 16.5, 6, 14.5)
          ..close();
        canvas.drawPath(bellBody, paint);
        final clapper = Path()
          ..moveTo(10, 20)
          ..quadraticBezierTo(12, 21.8, 14, 20);
        canvas.drawPath(clapper, paint);
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
