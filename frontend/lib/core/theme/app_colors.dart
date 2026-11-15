import 'package:flutter/material.dart';

/// Oversee Design System Color Palette.
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFF6366F1); // Indigo 500
  static const Color primaryDark = Color(0xFF3730A3); // Indigo 800

  // Secondary Accent Colors
  static const Color secondary = Color(0xFF0EA5E9); // Sky 500
  static const Color secondaryLight = Color(0xFF38BDF8); // Sky 400
  static const Color secondaryDark = Color(0xFF0369A1); // Sky 700

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6); // Blue 500
  static const Color infoLight = Color(0xFFDBEAFE);

  // Issue Status Colors (mapped to backend IssueStatus)
  static const Color statusBacklog = Color(0xFF64748B); // Slate 500
  static const Color statusTodo = Color(0xFF3B82F6); // Blue 500
  static const Color statusInProgress = Color(0xFFF59E0B); // Amber 500
  static const Color statusInReview = Color(0xFF8B5CF6); // Purple 500
  static const Color statusDone = Color(0xFF10B981); // Emerald 500
  static const Color statusCanceled = Color(0xFF94A3B8); // Slate 400

  // Issue Priority Colors (mapped to backend IssuePriority)
  static const Color priorityLowest = Color(0xFF94A3B8); // Slate 400
  static const Color priorityLow = Color(0xFF3B82F6); // Blue 500
  static const Color priorityMedium = Color(0xFFF59E0B); // Amber 500
  static const Color priorityHigh = Color(0xFFEA580C); // Orange 600
  static const Color priorityUrgent = Color(0xFFDC2626); // Red 600

  // Neutral Colors - Light Mode
  static const Color bgLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color textMutedLight = Color(0xFF94A3B8); // Slate 400

  // Neutral Colors - Dark Mode
  static const Color bgDark = Color(0xFF0B0F19); // Deep Slate
  static const Color surfaceDark = Color(0xFF111827); // Gray 900
  static const Color cardDark = Color(0xFF1F2937); // Gray 800
  static const Color borderDark = Color(0xFF374151); // Gray 700
  static const Color textPrimaryDark = Color(0xFFF9FAFB); // Gray 50
  static const Color textSecondaryDark = Color(0xFF9CA3AF); // Gray 400
  static const Color textMutedDark = Color(0xFF6B7280); // Gray 500
}
