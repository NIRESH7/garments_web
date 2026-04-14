import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPrimary = ref.watch(themeProvider);

    final List<Map<String, dynamic>> presets = [
      {'name': 'Sky Blue', 'color': const Color(0xFF0EA5E9)},
      {'name': 'Indigo', 'color': const Color(0xFF6366F1)},
      {'name': 'Rose', 'color': const Color(0xFFE11D48)},
      {'name': 'Emerald', 'color': const Color(0xFF10B981)},
      {'name': 'Amber', 'color': const Color(0xFFF59E0B)},
      {'name': 'Crimson', 'color': const Color(0xFFDC2626)},
      {'name': 'Violet', 'color': const Color(0xFF8B5CF6)},
      {'name': 'Teal', 'color': const Color(0xFF0D9488)},
      {'name': 'Orange', 'color': const Color(0xFFEA580C)},
      {'name': 'Slate', 'color': const Color(0xFF475569)},
      {'name': 'Midnight', 'color': const Color(0xFF0F172A)},
      {'name': 'Earth', 'color': const Color(0xFF78350F)},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.arrowLeft, size: 20, color: Color(0xFF475569)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Text(
                  'THEME SETTINGS',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => ref.read(themeProvider.notifier).resetTheme(),
                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                  label: Text('RESET TO DEFAULT', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Container(
                width: double.infinity,
                alignment: Alignment.topCenter,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('PRIMARY ACCENT', 'Choose a color to personalize buttons, highlights, and active states.'),
                      const SizedBox(height: 24),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1,
                        ),
                        itemCount: presets.length,
                        itemBuilder: (context, index) {
                          final item = presets[index];
                          final color = item['color'] as Color;
                          final isSelected = currentPrimary.value == color.value;

                          return GestureDetector(
                            onTap: () => ref.read(themeProvider.notifier).setThemeColor(color),
                            child: Column(
                              children: [
                                Container(
                                  height: 60,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      if (isSelected)
                                        BoxShadow(
                                          color: color.withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? const Center(child: Icon(LucideIcons.check, color: Colors.white, size: 20))
                                      : null,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['name'],
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 48),
                      _sectionTitle('PREVIEW', 'Visualization of the selected accent color in common UI elements.'),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: currentPrimary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size(120, 40),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Button'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: currentPrimary,
                                    side: BorderSide(color: currentPrimary),
                                    minimumSize: const Size(120, 40),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Secondary'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Sample Title Text',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: currentPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This is how the accent color looks on standard components.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1.2,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
