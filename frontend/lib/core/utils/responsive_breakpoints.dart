import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_constants.dart';

/// Responsive device category.
enum DeviceScreenType { mobile, tablet, desktop }

/// Helper utility for detecting screen types and breakpoints.
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  static DeviceScreenType getDeviceType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppConstants.mobileBreakpoint) {
      return DeviceScreenType.mobile;
    } else if (width < AppConstants.tabletBreakpoint) {
      return DeviceScreenType.tablet;
    } else {
      return DeviceScreenType.desktop;
    }
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppConstants.mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppConstants.mobileBreakpoint && width < AppConstants.tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;
}
