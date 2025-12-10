import 'package:gsheets/gsheets.dart';
import '../models/word_item.dart';

class SheetService {
  GSheets? _gsheets;
  Spreadsheet? _spreadsheet;
  Worksheet? _worksheet;

  Future<void> init(String credentialsJson, String spreadsheetId) async {
    _gsheets = GSheets(credentialsJson);
    _spreadsheet = await _gsheets!.spreadsheet(spreadsheetId);
    // Assuming the first sheet is the one we want
    _worksheet = _spreadsheet!.worksheetByIndex(0);
  }

  Future<Map<String, int>> getHeaders() async {
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

  Future<List<WordItem>> getWordsExample(int englishColIndex) async {
    if (_worksheet == null) return [];
    
    // Fetch the English column and the one to its left (Hebrew)
    // English Col Index is 1-based. Hebrew is englishColIndex - 1.
    
    if (englishColIndex <= 1) {
        // Can't have a column to the left of the first one
        return []; 
    }

    final int hebrewColIndex = englishColIndex - 1;
    
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
}
