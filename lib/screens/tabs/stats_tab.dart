import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/library_provider.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    final totalSeries = lp.series.length;
    final totalChapters = lp.series.fold(0, (sum, s) => sum + s.chapters.length);
    
    // Calculate reading stats (simplified for now)
    final readProgressCount = lp.progressMap.length;
    final completedCount = lp.progressMap.values.where((p) => p.page >= p.totalPages - 1 && p.totalPages > 0).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Statistics', 
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatGrid(totalSeries, totalChapters, readProgressCount, completedCount),
            const SizedBox(height: 24),
            _buildFavoritesSection(context, lp),
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

  Widget _buildFavoritesSection(BuildContext context, LibraryProvider lp) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Favorite Series', 
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.05)),
          ),
          child: Center(
            child: Text('Coming Soon: Add to favorites!', 
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.3))),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: theme.primaryColor, size: 20),
          const Spacer(),
          Text(value, style: GoogleFonts.jetBrainsMono(
            color: theme.colorScheme.onSurface, 
            fontSize: 24, 
            fontWeight: FontWeight.bold
          )),
          Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.54), fontSize: 10)),
        ],
      ),
    );
  }
}
