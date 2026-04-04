import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb;
  
  static bool isDesktopWeb(double width) {
    return isWeb && width >= 900;
  }
  
  static bool isTabletWeb(double width) {
    return isWeb && width >= 600 && width < 900;
  }
  
  static bool isMobileWeb(double width) {
    return isWeb && width < 600;
  }
}
