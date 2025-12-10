import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/word_item.dart';

class DictionaryService {
  final http.Client _client = http.Client();

  Future<WordItem> enrichWord(WordItem item) async {
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

    // 2. Fetch Syllables from Merriam-Webster Learner's Dictionary
    String? syllables;
    
    try {
      final url = Uri.parse('${AppConstants.merriamWebsterApiUrl}/${item.englishWord}?key=${AppConstants.merriamWebsterApiKey}');
      print('Fetching syllables from Merriam-Webster for: ${item.englishWord}');
      final response = await _client.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Merriam-Webster response: $data');
        // Response format: array of entries with hwi.hw containing syllables with * delimiter
        if (data.isNotEmpty && data[0] is Map) {
          final entry = data[0] as Map<String, dynamic>;
          final hwi = entry['hwi'] as Map<String, dynamic>?;
          if (hwi != null && hwi['hw'] != null) {
            // hw contains syllables separated by *, e.g., "beau*ti*ful"
            final hw = hwi['hw'].toString();
            syllables = hw.replaceAll('*', '.');
            print('Parsed syllables: $syllables');
          } else {
            print('No hwi.hw found in response');
          }
        } else {
          print('Response is empty or not a Map');
        }
      } else {
        print('Merriam-Webster API returned status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Merriam-Webster: $e');
    }

    return item.copyWith(
      audioUrl: audioUrl,
      phonetic: phonetic,
      syllables: syllables,
    );
  }
}
