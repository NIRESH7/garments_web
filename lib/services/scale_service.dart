import 'dart:math';

class ScaleService {
  static Future<double> captureWeight() async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    // Return a random weight between 10.0 and 50.0
    return double.parse((Random().nextDouble() * 40 + 10).toStringAsFixed(2));
  }
}
