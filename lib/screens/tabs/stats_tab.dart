import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/library_provider.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LibraryProvider>();
    final totalSeries = lp.series.length;
    final totalChapters = lp.series.fold(0, (sum, s) => sum + s.chapters.length);
    
    // Calculate reading stats (simplified for now)
    final readProgressCount = lp.progressMap.length;
    final completedCount = lp.progressMap.values.where((p) => p.page >= p.totalPages - 1 && p.totalPages > 0).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Statistics', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatGrid(totalSeries, totalChapters, readProgressCount, completedCount),
            const SizedBox(height: 24),
            _buildFavoritesSection(lp),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid(int series, int chapters, int reading, int completed) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _StatCard(label: 'Total Series', value: series.toString(), icon: Icons.library_books_rounded),
        _StatCard(label: 'Total Files', value: chapters.toString(), icon: Icons.folder_zip_rounded),
        _StatCard(label: 'Currently Reading', value: reading.toString(), icon: Icons.menu_book_rounded),
        _StatCard(label: 'Completed', value: completed.toString(), icon: Icons.check_circle_rounded),
      ],
    );
  }

  Widget _buildFavoritesSection(LibraryProvider lp) {
    // For now, just show a placeholder or recently read
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Favorite Series', 
          style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text('Coming Soon: Add to favorites!', style: TextStyle(color: Colors.white30)),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF6C3CE0), size: 20),
          const Spacer(),
          Text(value, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}
