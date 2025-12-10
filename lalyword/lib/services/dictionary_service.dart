import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/word_item.dart';

class DictionaryService {
  final http.Client _client = http.Client();

  Future<WordItem> enrichWord(WordItem item, {String? wordnikApiKey}) async {
    // 1. Fetch from FreeDictionaryAPI (Audio + Phonetic)
    String? audioUrl;
    String? phonetic;
    
    try {
      final url = Uri.parse('${AppConstants.freeDictionaryApiUrl}/${item.englishWord}');
      final response = await _client.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final entry = data[0];
          phonetic = entry['phonetic'];
          
          // Find first audio
          final phonetics = entry['phonetics'] as List<dynamic>?;
          if (phonetics != null) {
            for (var p in phonetics) {
              final audio = p['audio'];
              if (audio != null && audio.toString().isNotEmpty) {
                audioUrl = audio;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching FreeDictionaryAPI: $e');
    }

    // 2. Fetch Syllables from Wordnik (if key provided)
    String? syllables;
    final String apiKey = wordnikApiKey ?? AppConstants.wordnikApiKey;
    
    if (apiKey.isNotEmpty) {
       try {
         final url = Uri.parse('https://api.wordnik.com/v4/word.json/${item.englishWord}/hyphenation?useCanonical=false&limit=50&api_key=$apiKey');
         final response = await _client.get(url);
         
         if (response.statusCode == 200) {
           final List<dynamic> data = json.decode(response.body);
           // Response format: [{text: "syll", seq: 0}, {text: "a", seq: 1}, {text: "ble", seq: 2}]
           final syllableParts = data.map((e) => e['text'].toString()).toList();
           syllables = syllableParts.join('.');
         }
       } catch (e) {
         print('Error fetching Wordnik: $e');
       }
    }

    return item.copyWith(
      audioUrl: audioUrl,
      phonetic: phonetic,
      syllables: syllables,
    );
  }
}
