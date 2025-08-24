import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double mobileBreakpoint = 400.0;
  static const double tabletBreakpoint = 600.0;
  static const double desktopBreakpoint = 1200.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isSmallMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 350.0;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static bool isRegularDesktop(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Detect larger desktop screens like MacBook Pro, iMac, etc.
    return size.width >= 1500.0 || size.height >= 900.0;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.height < 700.0;
  }

  static bool isSmallDesktop(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Detect small desktop/laptop screens like MacBook Air (1366x768, 1440x900)
    return size.width >= tabletBreakpoint && 
           size.width < 1500.0 && 
           size.height < 900.0;
  }

  static bool isLimitedHeight(BuildContext context) {
    // Screens with limited vertical space that need compact layouts
    return MediaQuery.of(context).size.height < 800.0;
  }

  // Responsive padding
  static double getHorizontalPadding(BuildContext context) {
    if (isSmallMobile(context)) return 12.0;
    if (isMobile(context)) return 16.0;
    if (isTablet(context)) return 24.0;
    return 32.0;
  }

  static double getVerticalPadding(BuildContext context) {
    if (isSmallScreen(context)) return 12.0;
    if (isMobile(context)) return 16.0;
    return 24.0;
  }

  // Responsive grid
  static int getSeedPhraseGridColumns(BuildContext context) {
    if (isSmallMobile(context)) return 2;
    if (isMobile(context) || isTablet(context)) return 3;
    return 4;
  }

  static double getSeedPhraseAspectRatio(BuildContext context) {
    if (isSmallMobile(context)) return 3.2;
    if (isMobile(context)) return 3.5;
    if (isTablet(context)) return 3.8;
    return 4.0;
  }

  static double getSeedPhraseSpacing(BuildContext context) {
    if (isSmallMobile(context)) return 6.0;
    if (isMobile(context)) return 8.0;
    return 10.0;
  }

  // Responsive text sizes
  static double getBodyTextSize(BuildContext context) {
    if (isSmallMobile(context)) return 13.0;
    if (isMobile(context)) return 14.0;
    return 16.0;
  }

  static double getSeedWordTextSize(BuildContext context) {
    if (isSmallMobile(context)) return 11.0;
    if (isMobile(context)) return 12.0;
    return 14.0;
  }

  static double getSeedNumberTextSize(BuildContext context) {
    if (isSmallMobile(context)) return 10.0;
    if (isMobile(context)) return 11.0;
    return 12.0;
  }

  static double getTitleTextSize(BuildContext context) {
    if (isSmallMobile(context)) return 20.0;
    if (isMobile(context)) return 22.0;
    return 24.0;
  }

  // Responsive button sizes
  static double getButtonHeight(BuildContext context) {
    if (isSmallMobile(context)) return 48.0;
    if (isMobile(context)) return 52.0;
    return 56.0;
  }

  static double getButtonBorderRadius(BuildContext context) {
    if (isSmallMobile(context)) return 12.0;
    if (isMobile(context)) return 14.0;
    return 16.0;
  }

  // Safe area helpers
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }

  static EdgeInsets getScreenPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: getHorizontalPadding(context),
      vertical: getVerticalPadding(context),
    );
  }

  // Layout helpers
  static double getCardBorderRadius(BuildContext context) {
    if (isSmallMobile(context)) return 12.0;
    if (isMobile(context)) return 16.0;
    return 20.0;
  }

  static double getIconSize(BuildContext context, {double base = 24.0}) {
    if (isSmallMobile(context)) return base * 0.9;
    if (isMobile(context)) return base;
    return base * 1.1;
  }

  // Input field helpers
  static double getInputFieldHeight(BuildContext context) {
    if (isSmallMobile(context)) return 44.0;
    if (isMobile(context)) return 48.0;
    return 52.0;
  }

  static EdgeInsets getInputFieldPadding(BuildContext context) {
    if (isSmallMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal:14, vertical: 10);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }

  // PIN-specific responsive sizing
  static double getPinButtonPadding(BuildContext context) {
    // Tighter padding for all platforms for smaller overall button size
    return 3.0;
  }

  static double getPinKeypadWidth(BuildContext context) {
    if (isRegularDesktop(context)) return 240.0;
    if (isSmallDesktop(context)) return 220.0;
    if (isDesktop(context)) return 250.0;
    return 240.0;
  }

  static double getPinButtonMinSize(BuildContext context) {
    // Much smaller buttons for desktop, appropriate sizes for mobile
    if (isRegularDesktop(context)) return 28.0;  // Large desktops (MacBook Pro, iMac)
    if (isSmallDesktop(context)) return 30.0;    // Small desktops (MacBook Air)
    if (isMobile(context)) return 36.0;          // Mobile devices need larger touch targets
    return 32.0;  // Tablet fallback
  }

  static double getPinButtonFontSize(BuildContext context) {
    // Proportional font sizing for smaller buttons
    if (isRegularDesktop(context)) return 13.0;  // Large desktops
    if (isSmallDesktop(context)) return 14.0;    // Small desktops  
    if (isMobile(context)) return 16.0;          // Mobile
    return 15.0;  // Tablet fallback
  }

  static double getPinVerticalSpacing(BuildContext context) {
    if (isLimitedHeight(context)) return 16.0;
    if (isSmallDesktop(context)) return 20.0;
    if (isDesktop(context)) return 24.0;
    return 32.0;
  }

  static double getSecurityWarningPadding(BuildContext context) {
    if (isSmallDesktop(context) || isLimitedHeight(context)) return 12.0;
    return getHorizontalPadding(context);
  }

  // Balance-specific responsive sizing
  static double getBalanceTextSize(BuildContext context) {
    if (isSmallMobile(context)) return 34.0;  // Increased for better mobile readability
    if (isMobile(context)) return 38.0;       // Increased for better mobile readability
    return 36.0;                              // Match send page spendable balance size
  }

  static double getBalanceTextHeight(BuildContext context) {
    if (isMobile(context)) return 1.2;        // Tighter line height for mobile
    return 1.4;                               // Desktop line height
  }

  static double getBalanceContainerHeight(BuildContext context) {
    if (isSmallMobile(context)) return 35.0;  // More compact for small screens
    if (isMobile(context)) return 40.0;       // Reduced mobile height
    return 50.0;                              // Reduced desktop height
  }

  static double getBalanceTopPadding(BuildContext context) {
    if (isMobile(context)) return 40.0;       // Reduced mobile padding for compactness
    return 36.0;                              // Reduced desktop padding
  }
}