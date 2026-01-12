import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../config/app_theme.dart';
import 'activity_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _sheetIdController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _sheetIdController = TextEditingController(text: settings.sheetId);
  }

  @override
  void dispose() {
    _sheetIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(settingsProvider.notifier).saveSettings(
        sheetId: _sheetIdController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings Saved'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        ref.invalidate(sheetInitProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: const Text('Setup LalyWord'),
        backgroundColor: AppTheme.pureWhite,
        foregroundColor: AppTheme.darkGrey,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: AppTheme.orangeGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.cloud, color: AppTheme.pureWhite),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Google Sheet ID',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sheetIdController,
                        decoration: const InputDecoration(
                          hintText: '1ih-k_KL33t7AU_h6BChr9XChjqoGiT9SVfuL04nS1JA',
                          helperText: 'Found in the URL of your public Google Sheet.\nMake sure the sheet is shared as "Anyone with the link can view".',
                          helperMaxLines: 2,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter Spreadsheet ID';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: AppTheme.gradientButton(
                  text: 'Save & Connect',
                  onPressed: _save,
                  gradient: AppTheme.blueGradient,
                  icon: Icons.save,
                ),
              ),
              
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ActivityScreen()),
                    );
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('See Activity'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    foregroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
