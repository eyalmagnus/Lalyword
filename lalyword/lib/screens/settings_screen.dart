import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _jsonController;
  late TextEditingController _sheetIdController;
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _jsonController = TextEditingController(text: settings.credentialsJson);
    _sheetIdController = TextEditingController(text: settings.sheetId);
    _apiKeyController = TextEditingController(text: settings.wordnikApiKey);
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _sheetIdController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(settingsProvider.notifier).saveSettings(
        credentialsJson: _jsonController.text.trim(),
        sheetId: _sheetIdController.text.trim(),
        wordnikApiKey: _apiKeyController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings Saved')),
        );
        // Force re-init check
        ref.refresh(sheetInitProvider);
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
                'Google Service Account JSON',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _jsonController,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{ "type": "service_account", ... }',
                  helperText: 'Paste the content of your .json key file',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter JSON credentials';
                  }
                  if (!value.contains('"private_key"')) {
                    return 'Invalid JSON format (missing private_key)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              const Text(
                'Spreadsheet ID',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _sheetIdController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
                  helperText: 'Found in the URL of your Google Sheet',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Spreadsheet ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              const Text(
                'Wordnik API Key (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'your-api-key',
                  helperText: 'Required for syllable dots (e.g. beau.ti.ful)',
                ),
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
            ],
          ),
        ),
      ),
    );
  }
}
