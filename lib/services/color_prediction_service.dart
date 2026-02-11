import 'mobile_api_service.dart';

class ColorPredictionResult {
  final String colorName;
  final String shadeLevel; // light | medium | dark
  final String tone; // warm | cool | neutral
  final String hexColor;
  final String rgb;
  final String confidence; // low | medium
  final String note;
  final String source; // 'local' | 'ai' | 'fallback'

  ColorPredictionResult({
    required this.colorName,
    required this.shadeLevel,
    required this.tone,
    required this.hexColor,
    required this.rgb,
    required this.confidence,
    this.note = 'Approximate result. Actual shade may vary.',
    this.source = 'local',
  });

  factory ColorPredictionResult.fromApiJson(Map<String, dynamic> json) {
    return ColorPredictionResult(
      colorName: json['colorName'] ?? 'Unknown',
      shadeLevel: json['shadeLevel'] ?? 'medium',
      tone: json['tone'] ?? 'neutral',
      hexColor: json['hexColor'] ?? '#808080',
      rgb: json['rgb'] ?? 'rgb(128, 128, 128)',
      confidence: json['confidence'] ?? 'low',
      note: json['note'] ?? 'Approximate result. Actual shade may vary.',
      source: json['source'] ?? 'ai',
    );
  }

  Map<String, dynamic> toJson() => {
    'colorName': colorName,
    'shadeLevel': shadeLevel,
    'tone': tone,
    'hexColor': hexColor,
    'rgb': rgb,
    'confidence': confidence,
    'note': note,
  };

  int get red => _parseRgb(0);
  int get green => _parseRgb(1);
  int get blue => _parseRgb(2);

  int _parseRgb(int index) {
    final parts = rgb.replaceAll('rgb(', '').replaceAll(')', '').split(',');
    return int.tryParse(parts[index].trim()) ?? 0;
  }
}

class ColorPredictionService {
  // ─── Comprehensive dye color database ───
  static final Map<String, _DyeColor> _dyeDatabase = {
    // === REACTIVE DYES (Cotton) ===
    // Reds
    'reactive red': _DyeColor(200, 30, 30, 'Red', 'warm'),
    'reactive red me4bl': _DyeColor(180, 20, 40, 'Crimson Red', 'warm'),
    'reactive red 195': _DyeColor(210, 35, 35, 'Scarlet Red', 'warm'),
    'reactive red m8b': _DyeColor(190, 25, 50, 'Ruby Red', 'warm'),
    'reactive red m5b': _DyeColor(195, 40, 45, 'Cherry Red', 'warm'),
    'reactive red 3bs': _DyeColor(205, 45, 35, 'Bright Red', 'warm'),
    'red me4bl': _DyeColor(180, 20, 40, 'Crimson Red', 'warm'),
    'red 195': _DyeColor(210, 35, 35, 'Scarlet Red', 'warm'),
    'red m8b': _DyeColor(190, 25, 50, 'Ruby Red', 'warm'),
    'red': _DyeColor(200, 30, 30, 'Red', 'warm'),

    // Blues
    'reactive blue': _DyeColor(20, 50, 180, 'Royal Blue', 'cool'),
    'reactive blue megn': _DyeColor(25, 80, 190, 'Ocean Blue', 'cool'),
    'reactive blue 19': _DyeColor(15, 40, 170, 'Navy Blue', 'cool'),
    'reactive blue 21': _DyeColor(30, 60, 200, 'Cobalt Blue', 'cool'),
    'reactive blue 49': _DyeColor(35, 90, 195, 'Sapphire Blue', 'cool'),
    'reactive blue rr': _DyeColor(20, 55, 185, 'Bright Blue', 'cool'),
    'blue megn': _DyeColor(25, 80, 190, 'Ocean Blue', 'cool'),
    'blue 19': _DyeColor(15, 40, 170, 'Navy Blue', 'cool'),
    'blue': _DyeColor(20, 50, 180, 'Royal Blue', 'cool'),
    'navy blue': _DyeColor(10, 20, 80, 'Navy Blue', 'cool'),
    'turquoise blue': _DyeColor(0, 160, 190, 'Turquoise Blue', 'cool'),
    'reactive turquoise': _DyeColor(0, 150, 180, 'Turquoise', 'cool'),

    // Yellows
    'reactive yellow': _DyeColor(240, 200, 20, 'Golden Yellow', 'warm'),
    'reactive yellow merl': _DyeColor(245, 210, 15, 'Lemon Yellow', 'warm'),
    'reactive yellow 145': _DyeColor(230, 190, 30, 'Amber Yellow', 'warm'),
    'reactive yellow m4g': _DyeColor(250, 215, 25, 'Bright Yellow', 'warm'),
    'reactive yellow fg': _DyeColor(235, 195, 35, 'Sunshine Yellow', 'warm'),
    'reactive yellow 3rs': _DyeColor(255, 220, 0, 'Canary Yellow', 'warm'),
    'yellow merl': _DyeColor(245, 210, 15, 'Lemon Yellow', 'warm'),
    'yellow 145': _DyeColor(230, 190, 30, 'Amber Yellow', 'warm'),
    'yellow': _DyeColor(240, 200, 20, 'Golden Yellow', 'warm'),

    // Oranges
    'reactive orange': _DyeColor(240, 120, 20, 'Orange', 'warm'),
    'reactive orange me2rl': _DyeColor(235, 100, 15, 'Tangerine', 'warm'),
    'reactive orange 13': _DyeColor(245, 130, 25, 'Bright Orange', 'warm'),
    'reactive orange 84': _DyeColor(230, 110, 20, 'Deep Orange', 'warm'),
    'orange': _DyeColor(240, 120, 20, 'Orange', 'warm'),

    // Greens
    'reactive green': _DyeColor(30, 140, 50, 'Forest Green', 'cool'),
    'reactive green 19': _DyeColor(25, 130, 45, 'Emerald Green', 'cool'),
    'green': _DyeColor(30, 140, 50, 'Forest Green', 'cool'),
    'olive green': _DyeColor(110, 120, 40, 'Olive Green', 'warm'),
    'bottle green': _DyeColor(10, 80, 30, 'Bottle Green', 'cool'),

    // Blacks
    'reactive black': _DyeColor(25, 25, 25, 'Jet Black', 'neutral'),
    'reactive black b': _DyeColor(20, 20, 20, 'Deep Black', 'neutral'),
    'reactive black wnn': _DyeColor(30, 28, 25, 'Carbon Black', 'neutral'),
    'reactive black 5': _DyeColor(15, 15, 15, 'Intense Black', 'neutral'),
    'reactive black 8': _DyeColor(35, 30, 30, 'Charcoal Black', 'neutral'),
    'black b': _DyeColor(20, 20, 20, 'Deep Black', 'neutral'),
    'black wnn': _DyeColor(30, 28, 25, 'Carbon Black', 'neutral'),
    'black': _DyeColor(25, 25, 25, 'Jet Black', 'neutral'),

    // Browns
    'reactive brown': _DyeColor(140, 80, 30, 'Chocolate Brown', 'warm'),
    'reactive brown gn': _DyeColor(130, 70, 25, 'Coffee Brown', 'warm'),
    'brown': _DyeColor(140, 80, 30, 'Chocolate Brown', 'warm'),
    'dark brown': _DyeColor(80, 40, 15, 'Dark Brown', 'warm'),
    'camel brown': _DyeColor(175, 130, 70, 'Camel Brown', 'warm'),

    // Violets / Purples
    'reactive violet': _DyeColor(120, 30, 140, 'Violet', 'cool'),
    'reactive violet 5r': _DyeColor(130, 25, 150, 'Purple', 'cool'),
    'violet': _DyeColor(120, 30, 140, 'Violet', 'cool'),
    'purple': _DyeColor(100, 20, 130, 'Purple', 'cool'),
    'grape': _DyeColor(90, 25, 100, 'Grape', 'cool'),

    // Pinks
    'reactive pink': _DyeColor(230, 80, 130, 'Hot Pink', 'warm'),
    'pink': _DyeColor(230, 80, 130, 'Hot Pink', 'warm'),
    'baby pink': _DyeColor(245, 180, 200, 'Baby Pink', 'warm'),

    // Maroon
    'reactive maroon': _DyeColor(100, 15, 25, 'Maroon', 'warm'),
    'maroon': _DyeColor(100, 15, 25, 'Maroon', 'warm'),

    // Greys
    'reactive grey': _DyeColor(120, 120, 120, 'Grey', 'neutral'),
    'grey': _DyeColor(120, 120, 120, 'Grey', 'neutral'),
    'ash grey': _DyeColor(140, 145, 145, 'Ash Grey', 'cool'),
    'steel grey': _DyeColor(100, 105, 110, 'Steel Grey', 'cool'),

    // Whites / Beige
    'white': _DyeColor(250, 250, 250, 'White', 'neutral'),
    'off white': _DyeColor(245, 240, 230, 'Off White', 'warm'),
    'beige': _DyeColor(225, 210, 180, 'Beige', 'warm'),
    'cream': _DyeColor(255, 250, 220, 'Cream', 'warm'),
    'ivory': _DyeColor(255, 255, 230, 'Ivory', 'warm'),

    // Khaki
    'khaki': _DyeColor(190, 175, 130, 'Khaki', 'warm'),
    'olive': _DyeColor(128, 128, 0, 'Olive', 'warm'),

    // Coral / Peach
    'coral': _DyeColor(240, 100, 80, 'Coral', 'warm'),
    'peach': _DyeColor(255, 200, 170, 'Peach', 'warm'),

    // === DISPERSE DYES (Polyester) ===
    'disperse red': _DyeColor(210, 40, 40, 'Polyester Red', 'warm'),
    'disperse blue': _DyeColor(25, 55, 185, 'Polyester Blue', 'cool'),
    'disperse yellow': _DyeColor(235, 205, 25, 'Polyester Yellow', 'warm'),
    'disperse orange': _DyeColor(240, 115, 25, 'Polyester Orange', 'warm'),
    'disperse black': _DyeColor(30, 30, 30, 'Polyester Black', 'neutral'),
    'disperse brown': _DyeColor(135, 75, 30, 'Polyester Brown', 'warm'),
    'disperse violet': _DyeColor(115, 35, 145, 'Polyester Violet', 'cool'),
    'disperse navy': _DyeColor(12, 25, 85, 'Polyester Navy', 'cool'),
    'disperse green': _DyeColor(35, 135, 55, 'Polyester Green', 'cool'),
    'disperse pink': _DyeColor(225, 85, 135, 'Polyester Pink', 'warm'),
    'disperse grey': _DyeColor(115, 115, 115, 'Polyester Grey', 'neutral'),
    'disperse maroon': _DyeColor(95, 18, 28, 'Polyester Maroon', 'warm'),

    // === VAT DYES ===
    'vat blue': _DyeColor(15, 45, 160, 'Indigo Blue', 'cool'),
    'vat indigo': _DyeColor(20, 20, 110, 'Indigo', 'cool'),
    'vat black': _DyeColor(20, 20, 20, 'Vat Black', 'neutral'),
    'vat green': _DyeColor(20, 100, 40, 'Vat Green', 'cool'),
    'vat brown': _DyeColor(120, 60, 20, 'Vat Brown', 'warm'),
    'vat orange': _DyeColor(230, 100, 15, 'Vat Orange', 'warm'),
    'vat red': _DyeColor(185, 25, 30, 'Vat Red', 'warm'),
    'vat yellow': _DyeColor(220, 185, 15, 'Vat Yellow', 'warm'),
    'vat violet': _DyeColor(100, 25, 120, 'Vat Violet', 'cool'),
  };

  /// Main prediction method
  static ColorPredictionResult predict({
    required String fabricType,
    required double fabricGSM,
    required String dyeType,
    required double dyePercentage,
    required List<String> dyeNames,
    required double saltPercentage,
    required double sodaAshPercentage,
    required double aceticAcidPercentage,
    List<String> otherChemicals = const [],
  }) {
    if (dyeNames.isEmpty) {
      return ColorPredictionResult(
        colorName: 'Undyed / Raw',
        shadeLevel: 'light',
        tone: 'neutral',
        hexColor: '#F5F5DC',
        rgb: 'rgb(245, 245, 220)',
        confidence: 'low',
        note: 'No dye names provided. Showing raw fabric color.',
      );
    }

    // Step 1: Resolve each dye name to base RGB
    List<_DyeColor> resolvedDyes = [];
    for (var name in dyeNames) {
      final dye = _findDye(name.trim());
      if (dye != null) {
        resolvedDyes.add(dye);
      }
    }

    if (resolvedDyes.isEmpty) {
      return ColorPredictionResult(
        colorName: 'Unknown Dye Combination',
        shadeLevel: 'medium',
        tone: 'neutral',
        hexColor: '#808080',
        rgb: 'rgb(128, 128, 128)',
        confidence: 'low',
        note:
            'Could not identify dye names. Try standard names like "Reactive Red", "Blue 19", etc.',
      );
    }

    // Step 2: Blend dye colors (average for multiple dyes)
    double r = 0, g = 0, b = 0;
    for (var dye in resolvedDyes) {
      r += dye.r;
      g += dye.g;
      b += dye.b;
    }
    r /= resolvedDyes.length;
    g /= resolvedDyes.length;
    b /= resolvedDyes.length;

    // Step 3: Apply dye percentage effect (deeper shade with higher %)
    double depthFactor = _calculateDepthFactor(dyePercentage);
    r = _adjustForDepth(r, depthFactor);
    g = _adjustForDepth(g, depthFactor);
    b = _adjustForDepth(b, depthFactor);

    // Step 4: Apply fabric type adjustments
    _FabricAdjustment fabricAdj = _getFabricAdjustment(fabricType, fabricGSM);
    r = (r * fabricAdj.brightnessFactor).clamp(0, 255);
    g = (g * fabricAdj.brightnessFactor).clamp(0, 255);
    b = (b * fabricAdj.brightnessFactor).clamp(0, 255);

    // Step 5: Chemical effects
    // High salt → deeper shade
    if (saltPercentage > 50) {
      double saltEffect = 1.0 - ((saltPercentage - 50) / 100 * 0.1);
      r *= saltEffect;
      g *= saltEffect;
      b *= saltEffect;
    }

    // High soda ash → slightly shifts tone
    if (sodaAshPercentage > 15) {
      r = (r * 0.98).clamp(0, 255);
      g = (g * 1.01).clamp(0, 255);
      b = (b * 1.01).clamp(0, 255);
    }

    // Acetic acid (neutralization) → slightly brighter/washed
    if (aceticAcidPercentage > 1) {
      double acidEffect = 1.0 + (aceticAcidPercentage / 100 * 0.05);
      r = (r * acidEffect).clamp(0, 255);
      g = (g * acidEffect).clamp(0, 255);
      b = (b * acidEffect).clamp(0, 255);
    }

    int finalR = r.round().clamp(0, 255);
    int finalG = g.round().clamp(0, 255);
    int finalB = b.round().clamp(0, 255);

    // Step 6: Determine shade level
    String shadeLevel = _getShadeLevel(finalR, finalG, finalB, dyePercentage);

    // Step 7: Determine tone
    String tone = _determineTone(resolvedDyes);

    // Step 8: Generate color name
    String colorName = _generateColorName(resolvedDyes, shadeLevel, dyeNames);

    // Step 9: Confidence
    String confidence = resolvedDyes.length == dyeNames.length
        ? 'medium'
        : 'low';

    String hex =
        '#${finalR.toRadixString(16).padLeft(2, '0')}${finalG.toRadixString(16).padLeft(2, '0')}${finalB.toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();

    return ColorPredictionResult(
      colorName: colorName,
      shadeLevel: shadeLevel,
      tone: tone,
      hexColor: hex,
      rgb: 'rgb($finalR, $finalG, $finalB)',
      confidence: confidence,
    );
  }

  static _DyeColor? _findDye(String name) {
    final normalized = name.toLowerCase().trim();

    // Exact match
    if (_dyeDatabase.containsKey(normalized)) {
      return _dyeDatabase[normalized];
    }

    // Partial match - find best match
    String? bestMatch;
    int bestScore = 0;

    for (var key in _dyeDatabase.keys) {
      // Check if dye name contains the search term or vice versa
      if (key.contains(normalized) || normalized.contains(key)) {
        int score = _matchScore(normalized, key);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = key;
        }
      }
    }

    // Try individual words
    if (bestMatch == null) {
      final words = normalized.split(RegExp(r'[\s,]+'));
      for (var word in words) {
        if (word.length < 3) continue;
        for (var key in _dyeDatabase.keys) {
          if (key.contains(word)) {
            int score = _matchScore(word, key);
            if (score > bestScore) {
              bestScore = score;
              bestMatch = key;
            }
          }
        }
      }
    }

    return bestMatch != null ? _dyeDatabase[bestMatch] : null;
  }

  static int _matchScore(String search, String key) {
    if (search == key) return 100;
    if (key.startsWith(search)) return 80;
    if (key.contains(search)) return 60;
    return 30;
  }

  static double _calculateDepthFactor(double dyePercentage) {
    // 0-0.5% → very light, 0.5-1.5% → light, 1.5-3% → medium, 3%+ → dark
    if (dyePercentage <= 0.5) return 0.3;
    if (dyePercentage <= 1.0) return 0.5;
    if (dyePercentage <= 1.5) return 0.65;
    if (dyePercentage <= 2.0) return 0.75;
    if (dyePercentage <= 3.0) return 0.85;
    if (dyePercentage <= 5.0) return 0.95;
    return 1.0;
  }

  static double _adjustForDepth(double colorValue, double depthFactor) {
    // Push towards white (255) for lighter shades, keep original for deeper
    return colorValue + (255 - colorValue) * (1 - depthFactor);
  }

  static _FabricAdjustment _getFabricAdjustment(String fabricType, double gsm) {
    final type = fabricType.toLowerCase();
    double brightness = 1.0;

    if (type.contains('polyester')) {
      brightness = 1.05; // Polyester tends to be slightly brighter
    } else if (type.contains('blend')) {
      brightness = 1.02;
    } else {
      // Cotton - absorbs more, slightly muted
      brightness = 0.98;
    }

    // Higher GSM = slightly deeper color absorption
    if (gsm > 200) {
      brightness *= 0.97;
    } else if (gsm < 120) {
      brightness *= 1.03;
    }

    return _FabricAdjustment(brightness);
  }

  static String _getShadeLevel(int r, int g, int b, double dyePercentage) {
    double luminance = (0.299 * r + 0.587 * g + 0.114 * b);

    if (dyePercentage <= 0.5 || luminance > 200) return 'light';
    if (dyePercentage <= 2.0 || luminance > 100) return 'medium';
    return 'dark';
  }

  static String _determineTone(List<_DyeColor> dyes) {
    int warm = 0, cool = 0, neutral = 0;
    for (var dye in dyes) {
      if (dye.tone == 'warm')
        warm++;
      else if (dye.tone == 'cool')
        cool++;
      else
        neutral++;
    }
    if (warm > cool && warm > neutral) return 'warm';
    if (cool > warm && cool > neutral) return 'cool';
    return 'neutral';
  }

  static String _generateColorName(
    List<_DyeColor> dyes,
    String shade,
    List<String> originalNames,
  ) {
    if (dyes.length == 1) {
      String prefix = '';
      if (shade == 'light') prefix = 'Light ';
      if (shade == 'dark') prefix = 'Dark ';
      return '$prefix${dyes[0].name}';
    }

    // For multiple dyes, create a compound name
    if (dyes.length == 2) {
      return '${dyes[0].name} + ${dyes[1].name} Blend';
    }

    // 3+ dyes
    return '${dyes[0].name} Multi-Dye Blend';
  }

  /// AI-powered prediction using OpenAI via backend API.
  /// Falls back to local prediction if API is unavailable.
  static Future<ColorPredictionResult> predictWithAI({
    required String fabricType,
    required double fabricGSM,
    required String dyeType,
    required double dyePercentage,
    required List<String> dyeNames,
    required double saltPercentage,
    required double sodaAshPercentage,
    required double aceticAcidPercentage,
    List<String> otherChemicals = const [],
  }) async {
    try {
      final api = MobileApiService();
      final result = await api.predictColor(
        fabricType: fabricType,
        fabricGSM: fabricGSM,
        dyeType: dyeType,
        dyePercentage: dyePercentage,
        dyeNames: dyeNames,
        saltPercentage: saltPercentage,
        sodaAshPercentage: sodaAshPercentage,
        aceticAcidPercentage: aceticAcidPercentage,
        otherChemicals: otherChemicals,
      );

      if (result != null) {
        return ColorPredictionResult.fromApiJson(result);
      }
    } catch (_) {
      // Fall through to local prediction
    }

    // Fallback to local prediction
    return predict(
      fabricType: fabricType,
      fabricGSM: fabricGSM,
      dyeType: dyeType,
      dyePercentage: dyePercentage,
      dyeNames: dyeNames,
      saltPercentage: saltPercentage,
      sodaAshPercentage: sodaAshPercentage,
      aceticAcidPercentage: aceticAcidPercentage,
      otherChemicals: otherChemicals,
    );
  }
}

class _DyeColor {
  final double r, g, b;
  final String name;
  final String tone;

  _DyeColor(this.r, this.g, this.b, this.name, this.tone);
}

class _FabricAdjustment {
  final double brightnessFactor;
  _FabricAdjustment(this.brightnessFactor);
}
