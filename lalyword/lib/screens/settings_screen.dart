import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
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
          const SnackBar(content: Text('Settings Saved')),
        );
        // Force re-init check
        ref.invalidate(sheetInitProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup LalyWord')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Google Sheet ID',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _sheetIdController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save & Connect'),
                ),
              ),
              
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ActivityScreen()),
                    );
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('See Activity'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
