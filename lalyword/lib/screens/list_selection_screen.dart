import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../config/app_theme.dart';
import 'flashcard_screen.dart';
import 'spell_screen.dart';
import 'settings_screen.dart';
import 'activity_screen.dart';
import 'video_transition_screen.dart';

enum PracticeMode { memo, spell }

// Helper function to get fun icon and gradient for each list
class ListIconHelper {
  static final List<Map<String, dynamic>> iconConfigs = [
    {'icon': Icons.star, 'gradient': AppTheme.orangeGradient},
    {'icon': Icons.rocket_launch, 'gradient': AppTheme.blueGradient},
    {'icon': Icons.palette, 'gradient': AppTheme.greenGradient},
    {'icon': Icons.celebration, 'gradient': AppTheme.orangeGradient},
    {'icon': Icons.music_note, 'gradient': AppTheme.blueGradient},
    {'icon': Icons.sports_esports, 'gradient': AppTheme.greenGradient},
    {'icon': Icons.auto_awesome, 'gradient': AppTheme.orangeGradient},
    {'icon': Icons.emoji_events, 'gradient': AppTheme.blueGradient},
    {'icon': Icons.local_fire_department, 'gradient': AppTheme.orangeGradient},
    {'icon': Icons.wb_sunny, 'gradient': AppTheme.greenGradient},
    {'icon': Icons.favorite, 'gradient': AppTheme.blueGradient},
    {'icon': Icons.psychology, 'gradient': AppTheme.orangeGradient},
    {'icon': Icons.lightbulb, 'gradient': AppTheme.greenGradient},
    {'icon': Icons.flight_takeoff, 'gradient': AppTheme.blueGradient},
    {'icon': Icons.beach_access, 'gradient': AppTheme.orangeGradient},
  ];

  static Map<String, dynamic> getIconForList(String listName, int index, bool isBuiltIn) {
    // For built-in lists, use library icon with orange gradient
    if (isBuiltIn) {
      return {
        'icon': Icons.local_library,
        'gradient': AppTheme.orangeGradient,
      };
    }
    
    // For Google Sheet lists, cycle through fun icons based on index
    final configIndex = index % iconConfigs.length;
    return iconConfigs[configIndex];
  }
}

class ListSelectionScreen extends ConsumerStatefulWidget {
  const ListSelectionScreen({super.key});

  @override
  ConsumerState<ListSelectionScreen> createState() => _ListSelectionScreenState();
}

class _ListSelectionScreenState extends ConsumerState<ListSelectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PracticeMode _selectedMode = PracticeMode.memo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedMode = _tabController.index == 0 ? PracticeMode.memo : PracticeMode.spell;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headersAsync = ref.watch(sheetHeadersProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: const Text('Select a List'),
        backgroundColor: AppTheme.pureWhite,
        foregroundColor: AppTheme.darkGrey,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.softGrey,
          tabs: const [
            Tab(text: 'Memo'),
            Tab(text: 'Spell'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.pureWhite,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.softGrey,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppTheme.orangeGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.build, color: AppTheme.pureWhite, size: 20),
                        ),
                        title: const Text('Setup'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final settings = ref.watch(settingsProvider);
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppTheme.blueGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                settings.showSyllables ? Icons.visibility : Icons.visibility_off,
                                color: AppTheme.pureWhite,
                                size: 20,
                              ),
                            ),
                            title: const Text('Show Syllables'),
                            trailing: Switch(
                              value: settings.showSyllables,
                              onChanged: (value) async {
                                await ref.read(settingsProvider.notifier).toggleSyllables(value);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(value ? 'Syllables Enabled' : 'Syllables Disabled'),
                                      backgroundColor: AppTheme.primaryGreen,
                                    ),
                                  );
                                }
                              },
                              activeColor: AppTheme.primaryGreen,
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppTheme.greenGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.analytics, color: AppTheme.pureWhite, size: 20),
                        ),
                        title: const Text('See Activity'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ActivityScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: headersAsync.when(
        data: (headers) {
          if (headers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.blueGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_off, color: AppTheme.pureWhite, size: 48),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No lists found.\nVerify your Sheet structure.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                ],
              ),
            );
          }
          
          final listNames = headers.keys.toList();
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listNames.length,
            itemBuilder: (context, index) {
              final name = listNames[index];
              final isBuiltIn = headers[name] == -1;
              final iconConfig = ListIconHelper.getIconForList(name, index, isBuiltIn);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.pureWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, 
                    vertical: 16,
                  ),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: iconConfig['gradient'] as LinearGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (iconConfig['gradient'] as LinearGradient).colors.first.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      iconConfig['icon'] as IconData,
                      color: AppTheme.pureWhite,
                      size: 28,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isBuiltIn ? 'Built-in List' : 'From Google Sheet',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.softGrey,
                      ),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGrey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.darkGrey,
                    ),
                  ),
                  onTap: () {
                    ref.read(selectedListProvider.notifier).state = name;
                    
                    final hasShownTransition = ref.read(transitionVideoShownProvider);
                    
                    if (!hasShownTransition) {
                      ref.read(transitionVideoShownProvider.notifier).state = true;
                      
                      final targetScreen = _selectedMode == PracticeMode.memo ? 'flashcard' : 'spell';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoTransitionScreen(targetScreen: targetScreen),
                        ),
                      );
                    } else {
                      if (_selectedMode == PracticeMode.memo) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FlashcardScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SpellScreen(),
                          ),
                        );
                      }
                    }
                  },
                ),
              );
            },
          );
        },
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.orangeGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, size: 48, color: AppTheme.pureWhite),
                ),
                const SizedBox(height: 24),
                Text(
                  'Error loading lists:\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.darkGrey),
                ),
                const SizedBox(height: 24),
                AppTheme.gradientButton(
                  text: 'Retry',
                  onPressed: () => ref.refresh(sheetHeadersProvider),
                  gradient: AppTheme.blueGradient,
                  icon: Icons.refresh,
                ),
              ],
            ),
          ),
        ),
        loading: () => Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }
}
