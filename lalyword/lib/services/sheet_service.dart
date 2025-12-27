import 'package:gsheets/gsheets.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/word_item.dart';
import '../config/constants.dart';

class SheetService {
  GSheets? _gsheets;
  Spreadsheet? _spreadsheet;
  Worksheet? _worksheet;
  final http.Client _client = http.Client();
  
  // Simple public API mode (no service account)
  String? _publicSheetId;
  bool _usePublicApi = false;

  // Initialize with service account (existing method)
  Future<void> init(String credentialsJson, String spreadsheetId) async {
    _gsheets = GSheets(credentialsJson);
    _spreadsheet = await _gsheets!.spreadsheet(spreadsheetId);
    // Assuming the first sheet is the one we want
    _worksheet = _spreadsheet!.worksheetByIndex(0);
    _usePublicApi = false;
  }

  // Initialize with simple public API (new method)
  Future<void> initPublic(String spreadsheetId) async {
    _publicSheetId = spreadsheetId;
    _usePublicApi = true;
  }

  Future<Map<String, int>> getHeaders() async {
    print('=== getHeaders called, usePublicApi: $_usePublicApi ===');
    if (_usePublicApi) {
      return _getHeadersPublic();
    }
    
    if (_worksheet == null) return {};
    
    // Read the first row to get headers
    final headers = await _worksheet!.values.row(1);
    final map = <String, int>{};
    
    for (int i = 0; i < headers.length; i++) {
        // We only care about columns that might be English lists.
        // The user description: "To the left... is another column...".
        // This implies English columns are at index 1, 3, 5... (0-indexed) or similar.
        // We will return all headers and let the UI/Business logic decide or let user pick.
        if (headers[i].isNotEmpty) {
           map[headers[i]] = i + 1; // 1-based index for GSheets
        }
    }
    return map;
  }

  Future<Map<String, int>> _getHeadersPublic() async {
    if (_publicSheetId == null) {
      print('ERROR: _publicSheetId is null');
      return {};
    }
    
    try {
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_publicSheetId/values/A1:Z1?key=${AppConstants.googleSheetsApiKey}'
      );
      print('Fetching headers from: $url');
      final response = await _client.get(url);
      
      print('Headers API status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Headers API response: $data');
        final values = data['values'] as List<dynamic>?;
        
        if (values != null && values.isNotEmpty) {
          final headers = values[0] as List<dynamic>;
          final map = <String, int>{};
          
          for (int i = 0; i < headers.length; i++) {
            if (headers[i].toString().isNotEmpty) {
              map[headers[i].toString()] = i + 1; // 1-based index
              print('Found header: "${headers[i]}" at column ${i + 1}');
            }
          }
          print('Total headers found: ${map.length}');
          return map;
        }
      } else {
        print('Headers API error: ${response.body}');
      }
    } catch (e) {
      print('Error fetching headers from public API: $e');
    }
    
    return {};
  }

  Future<List<WordItem>> getWordsExample(int englishColIndex) async {
    print('=== getWordsExample called with englishColIndex: $englishColIndex, usePublicApi: $_usePublicApi ===');
    if (_usePublicApi) {
      return _getWordsPublic(englishColIndex);
    }
    
    if (_worksheet == null) return [];
    
    // Fetch the English column and the one to its right (Hebrew)
    // English Col Index is 1-based. Hebrew is englishColIndex + 1.
    
    final int hebrewColIndex = englishColIndex + 1;
    
    final englishValues = await _worksheet!.values.column(englishColIndex, fromRow: 2);
    final hebrewValues = await _worksheet!.values.column(hebrewColIndex, fromRow: 2);
    
    final List<WordItem> words = [];
    
    // Determine the max length to iterate
    int count = englishValues.length;
    
    for (int i = 0; i < count; i++) {
      String english = englishValues[i];
      if (english.trim().isEmpty) continue;
      
      String? hebrew;
      if (i < hebrewValues.length) {
          hebrew = hebrewValues[i].trim();
          if (hebrew.isEmpty) hebrew = null;
      }
      
      words.add(WordItem(
        englishWord: english,
        hebrewWord: hebrew,
      ));
    }
    
    return words;
  }

  Future<List<WordItem>> _getWordsPublic(int englishColIndex) async {
    if (_publicSheetId == null) return [];
    
    print('=== _getWordsPublic called with englishColIndex: $englishColIndex ===');
    
    try {
      // Convert column index to letter (A, B, C, etc.)
      String getColumnLetter(int index) {
        String letter = '';
        while (index > 0) {
          int remainder = (index - 1) % 26;
          letter = String.fromCharCode(65 + remainder) + letter;
          index = (index - 1) ~/ 26;
        }
        return letter;
      }
      
      final englishCol = getColumnLetter(englishColIndex);
      
      // Hebrew is to the right of English (e.g., if English is in C, Hebrew is in D)
      final int hebrewColIndex = englishColIndex + 1;
      final hebrewCol = getColumnLetter(hebrewColIndex);
      // Fetch both columns from row 2 onwards (e.g., C2:D100)
      final range = '$englishCol' '2:$hebrewCol' '100';
      
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_publicSheetId/values/$range?key=${AppConstants.googleSheetsApiKey}'
      );
      
      print('Fetching words from: $url');
      final response = await _client.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API Response: $data');
        final values = data['values'] as List<dynamic>?;
        
        if (values != null) {
          final List<WordItem> words = [];
          
          for (var row in values) {
            if (row is List && row.isNotEmpty) {
              // English is first column, Hebrew is second column (to the right)
              final english = row[0].toString().trim();
              
              if (english.isNotEmpty) {
                String? hebrew;
                if (row.length >= 2) {
                  hebrew = row[1].toString().trim();
                  if (hebrew.isEmpty) hebrew = null;
                }
                
                words.add(WordItem(
                  englishWord: english,
                  hebrewWord: hebrew,
                ));
              }
            }
          }
          
          print('Parsed ${words.length} words');
          return words;
        }
      } else {
        print('API returned status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching words from public API: $e');
    }
    
    return [];
  }
}
