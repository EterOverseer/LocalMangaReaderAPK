import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_screen.dart';
import 'tabs/tag_mgr_tab.dart';
import 'tabs/dir_mgr_tab.dart';
import 'tabs/stats_tab.dart';
import 'library_screen.dart';
import '../providers/library_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 2; // Default to Home (Tab 3)

  final List<Widget> _tabs = [
    const SettingsScreen(),
    const TagMgrTab(),
    const LibraryScreen(), // Home
    const DirMgrTab(),
    const StatsTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure library is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryProvider>().initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-refresh when returning to the app
      context.read<LibraryProvider>().initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(.1),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: GNav(
              rippleColor: colorScheme.onSurface.withOpacity(0.1),
              hoverColor: colorScheme.onSurface.withOpacity(0.05),
              gap: 8,
              activeColor: theme.primaryColor,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: theme.primaryColor.withOpacity(0.1),
              color: colorScheme.onSurface.withOpacity(0.54),
              tabs: const [
                GButton(icon: Icons.settings_outlined, text: 'Settings'),
                GButton(icon: Icons.label_outline_rounded, text: 'Tags'),
                GButton(icon: Icons.home_rounded, text: 'Home'),
                GButton(icon: Icons.folder_special_outlined, text: 'Sources'),
                GButton(icon: Icons.auto_graph_rounded, text: 'Stats'),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}


