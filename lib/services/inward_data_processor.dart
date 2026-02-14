class InwardDataProcessor {
  static Map<String, dynamic> process(Map<String, dynamic> inward) {
    final Set<String> diaSet = {};
    final Map<String, Map<String, dynamic>> colourMap = {};
    final Map<String, Map<String, double>> diaTotals = {};

    // Helper to add data
    void addData(String colour, String dia, int rolls, double weight) {
      if (dia.trim().isEmpty) return;
      diaSet.add(dia);
      
      if (!colourMap.containsKey(colour)) {
        colourMap[colour] = {
          'colour': colour,
          'data': <String, Map<String, dynamic>>{}, // dia -> {rolls, weight}
          'totalRolls': 0,
          'totalWeight': 0.0,
        };
      }
      
      final cData = colourMap[colour]!;
      if (!cData['data'].containsKey(dia)) {
        cData['data'][dia] = {'rolls': 0, 'weight': 0.0};
      }
      
      cData['data'][dia]['rolls'] += rolls;
      cData['data'][dia]['weight'] += weight;
      cData['totalRolls'] += rolls;
      cData['totalWeight'] += weight;

      if (!diaTotals.containsKey(dia)) {
        diaTotals[dia] = {'rolls': 0.0, 'weight': 0.0};
      }
      diaTotals[dia]!['rolls'] = (diaTotals[dia]!['rolls'] ?? 0) + rolls;
      diaTotals[dia]!['weight'] = (diaTotals[dia]!['weight'] ?? 0) + weight;
    }

    // Process storageDetails if available (preferred for colour breakdown)
    if (inward['storageDetails'] != null && (inward['storageDetails'] as List).isNotEmpty) {
      for (var sd in inward['storageDetails']) {
        final dia = sd['dia']?.toString() ?? 'N/A';
        final rows = sd['rows'] as List? ?? [];
        for (var row in rows) {
            final colour = row['colour']?.toString() ?? 'N/A';
            // Count sets/rolls and weight
            final setWeights = row['setWeights'] as List? ?? [];
            int rolls = setWeights.length; 
            double weight = setWeights.fold(0.0, (sum, w) => sum + (double.tryParse(w.toString()) ?? 0));
            
            addData(colour, dia, rolls, weight);
        }
      }
    } else {
      // Fallback to diaEntries (No Colour info usually, so use "N/A" or "Mixed")
      // User requested colour-wise, so this is just a fail-safe.
       for (var entry in inward['diaEntries'] ?? []) {
          final dia = entry['dia']?.toString() ?? 'N/A';
          final rolls = (entry['recRoll'] as num?)?.toInt() ?? 0;
          final weight = (entry['recWt'] as num?)?.toDouble() ?? 0.0;
          addData('N/A', dia, rolls, weight);
       }
    }

    final sortedDias = diaSet.toList()..sort();

    // Calculate Grand Totals
    int grandTotalRolls = 0;
    double grandTotalWeight = 0.0;
    
    diaTotals.forEach((key, value) {
        grandTotalRolls += (value['rolls'] ?? 0).toInt();
        grandTotalWeight += (value['weight'] ?? 0);
    });

    return {
      'dias': sortedDias,
      'rows': colourMap.values.toList(),
      'totals': {
        ...diaTotals,
        'grandTotalRolls': grandTotalRolls,
        'grandTotalWeight': grandTotalWeight,
      }
    };
  }
}
