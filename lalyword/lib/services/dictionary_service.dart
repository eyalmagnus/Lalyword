import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/word_item.dart';

class DictionaryService {
  final http.Client _client = http.Client();

  Future<WordItem> enrichWord(WordItem item) async {
    String originalWord = item.englishWord;
    String currentWord = originalWord;
    String? audioUrl;
    String? phonetic;
    String? syllables;

    // Handle "to " prefix for verbs (e.g., "to set" -> "set" for dictionary lookup)
    // Strip "to " for dictionary APIs but keep original word for translation
    String? toPrefix;
    String lookupWord = currentWord;
    if (currentWord.toLowerCase().startsWith('to ') && currentWord.length > 3) {
      toPrefix = 'to ';
      lookupWord = currentWord.substring(3).trim(); // Remove "to " prefix
      print('Detected "to " prefix, using "$lookupWord" for dictionary lookup (keeping "$currentWord" for translation)');
    }

    // Handle "able to" suffix (e.g., "able to" -> "able" for dictionary lookup)
    // Strip " to" for dictionary APIs but keep original word for translation
    String? toSuffix;
    if (lookupWord.toLowerCase().endsWith(' to') && lookupWord.length > 4) {
      toSuffix = ' to';
      lookupWord = lookupWord.substring(0, lookupWord.length - 3).trim(); // Remove " to" suffix
      print('Detected " to" suffix, using "$lookupWord" for dictionary lookup (keeping "$currentWord" for translation)');
    }

    // Try with lookup word (stripped of "to " if present)
    final result = await _fetchDictionaryData(lookupWord);
    audioUrl = result['audioUrl'];
    phonetic = result['phonetic'];
    syllables = result['syllables'];
    final actualWordId = result['actualWordId'];

    // Check if Merriam-Webster returned a different word (base form for inflected forms)
    // e.g., searched "behaviors" but got "behavior" in meta.id
    // e.g., searched "Babysitting" but got "babysit" in meta.id
    // Compare with lookupWord (not currentWord) since we may have stripped "to "
    final isMultiWordPhrase = lookupWord.contains(' ');
    
    // For multi-word phrases: if MW returns a base word, fetch audio/syllables from base word
    // but keep the original phrase for display
    if (isMultiWordPhrase && actualWordId != null && actualWordId.toLowerCase() != lookupWord.toLowerCase()) {
      print('Multi-word phrase "$lookupWord" found, base word is "$actualWordId"');
      // Fetch audio and syllables from the base word
      final baseWordResult = await _fetchDictionaryData(actualWordId);
      // Use base word's audio if we don't have it, or if it's better
      if ((audioUrl == null || audioUrl.isEmpty) && baseWordResult['audioUrl'] != null && baseWordResult['audioUrl']!.isNotEmpty) {
        audioUrl = baseWordResult['audioUrl'];
        print('Using audio from base word "$actualWordId" for phrase "$lookupWord": $audioUrl');
      }
      // Use base word's syllables if we don't have them, or if they're better
      if ((syllables == null || syllables.isEmpty) && baseWordResult['syllables'] != null && baseWordResult['syllables']!.isNotEmpty) {
        syllables = baseWordResult['syllables'];
        print('Using syllables from base word "$actualWordId" for phrase "$lookupWord": $syllables');
      }
      // Use base word's phonetic if available
      if (baseWordResult['phonetic'] != null && baseWordResult['phonetic']!.isNotEmpty) {
        phonetic = baseWordResult['phonetic'];
      }
      // Keep the original phrase for display (don't replace lookupWord)
      print('Keeping multi-word phrase "$lookupWord" as-is, using audio/syllables from base word "$actualWordId"');
    } else if (actualWordId != null && actualWordId.toLowerCase() != lookupWord.toLowerCase() && !isMultiWordPhrase) {
      // Single word replacement logic (existing behavior)
      // Only update word if audio is from Merriam-Webster (not FreeDictionaryAPI)
      // This ensures the word matches what the audio is actually for
      final hasMerriamAudio = audioUrl != null && audioUrl.isNotEmpty && 
                              audioUrl.contains('merriam-webster.com');
      final hasFreeDictAudio = audioUrl != null && audioUrl.isNotEmpty && 
                               !audioUrl.contains('merriam-webster.com');
      
      // Update word if:
      // 1. We have Merriam-Webster audio (both audio and syllables match the base form), OR
      // 2. We don't have FreeDictionaryAPI audio (so we should match the syllables from MW)
      if (hasMerriamAudio || !hasFreeDictAudio) {
        print('Merriam-Webster returned base form "$actualWordId" for "$lookupWord", updating lookup word');
        lookupWord = actualWordId;
        // If we had a "to " prefix, restore it to the currentWord for display
        if (toPrefix != null) {
          currentWord = '$toPrefix$actualWordId';
        } else if (toSuffix != null) {
          // If we had a " to" suffix, restore it to the currentWord for display
          currentWord = '$actualWordId$toSuffix';
        } else {
          currentWord = actualWordId;
        }
      } else {
        print('Keeping "$lookupWord" because audio is from FreeDictionaryAPI for this word, even though syllables are for "$actualWordId"');
      }
    }

    // Check if we're missing audio or syllables and lookup word ends with 's'
    final missingAudio = audioUrl == null || audioUrl.isEmpty;
    final missingSyllables = syllables == null || syllables.isEmpty;
    final needsFallback = (missingAudio || missingSyllables) && 
                          lookupWord.length > 1 && 
                          lookupWord.toLowerCase().endsWith('s');

    if (needsFallback) {
      // Try with singular form (drop the 's')
      final singularWord = lookupWord.substring(0, lookupWord.length - 1);
      print('Trying singular form for "$lookupWord": "$singularWord"');
      
      final singularResult = await _fetchDictionaryData(singularWord);
      final singularAudioUrl = singularResult['audioUrl'];
      final singularPhonetic = singularResult['phonetic'];
      final singularSyllables = singularResult['syllables'];

      // Use singular data if we found what was missing
      final foundAudio = (missingAudio && singularAudioUrl != null && singularAudioUrl.isNotEmpty);
      final foundSyllables = (missingSyllables && singularSyllables != null && singularSyllables.isNotEmpty);

      print('Fallback results for "$lookupWord" -> "$singularWord":');
      print('  - missingAudio: $missingAudio, foundAudio: $foundAudio, singularAudioUrl: "$singularAudioUrl"');
      print('  - missingSyllables: $missingSyllables, foundSyllables: $foundSyllables, singularSyllables: "$singularSyllables"');

      if (foundAudio || foundSyllables) {
        print('Found data with singular form, updating lookup word from "$lookupWord" to "$singularWord"');
        // Update lookup word to singular form if we found missing data
        lookupWord = singularWord;
        // If we had a "to " prefix, restore it to the currentWord for display
        if (toPrefix != null) {
          currentWord = '$toPrefix$singularWord';
        } else if (toSuffix != null) {
          // If we had a " to" suffix, restore it to the currentWord for display
          currentWord = '$singularWord$toSuffix';
        } else {
          currentWord = singularWord;
        }
        // Use singular data (prefer singular if both exist, otherwise use what we have)
        if (foundAudio) {
          audioUrl = singularAudioUrl;
          print('Updated audioUrl to: "$audioUrl"');
        } else {
          print('Audio not found in singular form for "$singularWord"');
        }
        if (foundSyllables) {
          syllables = singularSyllables;
          print('Updated syllables to: "$syllables"');
        }
        // Update phonetic if we got it from singular
        if (singularPhonetic != null && singularPhonetic.isNotEmpty) phonetic = singularPhonetic;
      } else {
        print('No additional data found with singular form for "$singularWord"');
      }
    }

    // Keep original word if it had "to " prefix or " to" suffix (for translation)
    // For multi-word phrases, always keep the original phrase
    final finalWord = (toPrefix != null || toSuffix != null || isMultiWordPhrase) ? originalWord : currentWord;
    
    // Track if word was modified (different from original input)
    // For words with "to " prefix: compare lookupWord with the stripped original
    // For words with " to" suffix: compare lookupWord with the stripped original
    // For other words: compare currentWord with originalWord
    String? storedOriginalWord;
    bool wordWasModified = false;
    
    if (toPrefix != null) {
      // For "to " prefix words, compare the lookup word with what it should be
      final originalStripped = originalWord.substring(3).trim();
      wordWasModified = lookupWord.toLowerCase() != originalStripped.toLowerCase();
      if (wordWasModified) {
        print('Word with "to " prefix modified: lookup changed from "$originalStripped" to "$lookupWord"');
      }
    } else if (toSuffix != null) {
      // For " to" suffix words, compare the lookup word with what it should be
      final originalStripped = originalWord.substring(0, originalWord.length - 3).trim();
      wordWasModified = lookupWord.toLowerCase() != originalStripped.toLowerCase();
      if (wordWasModified) {
        print('Word with " to" suffix modified: lookup changed from "$originalStripped" to "$lookupWord"');
      }
    } else {
      // For regular words, compare currentWord with originalWord
      wordWasModified = currentWord.toLowerCase() != originalWord.toLowerCase();
      if (wordWasModified) {
        print('Word modified from "$originalWord" to "$currentWord"');
      }
    }
    
    if (wordWasModified) {
      storedOriginalWord = originalWord;
      print('Storing original word: "$originalWord" (final word: "$finalWord")');
    }
    
    return item.copyWith(
      englishWord: finalWord, // Keep original "to set" for translation, or updated word otherwise
      audioUrl: audioUrl,
      phonetic: phonetic,
      syllables: syllables,
      originalWord: storedOriginalWord, // Store original if word was modified
    );
  }

  Future<Map<String, String?>> _fetchDictionaryData(String word) async {
    String? audioUrl;
    String? phonetic;
    String? syllables;
    String? actualWordId; // The actual word ID returned by Merriam-Webster

    // 1. Fetch from FreeDictionaryAPI (Audio + Phonetic)
    try {
      final url = Uri.parse('${AppConstants.freeDictionaryApiUrl}/$word');
      print('Fetching audio from FreeDictionaryAPI for: $word');
      final response = await _client.get(url);
      
      print('FreeDictionaryAPI response status for "$word": ${response.statusCode}');
      
      if (response.statusCode == 404) {
        print('FreeDictionaryAPI: Word "$word" not found (404)');
      } else if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('FreeDictionaryAPI response data length for "$word": ${data.length}');
        
        if (data.isNotEmpty) {
          final entry = data[0];
          phonetic = entry['phonetic'];
          print('FreeDictionaryAPI phonetic for "$word": $phonetic');
          
          // Find first audio
          final phonetics = entry['phonetics'] as List<dynamic>?;
          print('FreeDictionaryAPI phonetics array for "$word": ${phonetics?.length ?? 0} entries');
          
          if (phonetics != null) {
            for (var i = 0; i < phonetics.length; i++) {
              final p = phonetics[i];
              final audio = p['audio'];
              print('FreeDictionaryAPI phonetics[$i] audio for "$word": "$audio"');
              
              if (audio != null) {
                var audioPath = audio.toString().trim();
                // Skip empty strings, single slashes, or obviously invalid paths
                if (audioPath.isEmpty || audioPath == '/' || audioPath == '//') {
                  print('FreeDictionaryAPI phonetics[$i] audio for "$word" is invalid (empty or slash only): "$audioPath"');
                  continue;
                }
                
                // Check if it's a valid URL (starts with http) or needs to be constructed
                // FreeDictionaryAPI sometimes returns relative paths like "/media/pronunciations/en/word-us.mp3"
                if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
                  audioUrl = audioPath;
                } else if (audioPath.startsWith('/')) {
                  // Construct full URL from relative path (must have actual content after /)
                  if (audioPath.length > 1) {
                    audioUrl = 'https://api.dictionaryapi.dev$audioPath';
                  }
                } else if (audioPath.isNotEmpty) {
                  // If it's just a filename or path, try to construct it
                  audioUrl = 'https://api.dictionaryapi.dev/media/pronunciations/en/$audioPath';
                }
                
                print('FreeDictionaryAPI final audioUrl for "$word": "$audioUrl"');
                if (audioUrl != null && audioUrl.isNotEmpty && audioUrl.length > 10) {
                  break; // Only break if we have a reasonable URL
                } else {
                  // Reset if URL is too short to be valid
                  audioUrl = null;
                }
              }
            }
          }
          
          if (audioUrl == null || audioUrl.isEmpty) {
            print('No valid audio URL found in FreeDictionaryAPI response for "$word"');
          }
        } else {
          print('FreeDictionaryAPI response is empty for "$word"');
        }
      } else {
        print('FreeDictionaryAPI returned status ${response.statusCode} for "$word", body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      }
    } catch (e) {
      print('Error fetching FreeDictionaryAPI for "$word": $e');
    }

    // 2. Fetch Syllables from Merriam-Webster Learner's Dictionary
    // Also try to get audio if FreeDictionaryAPI didn't provide it
    try {
      final url = Uri.parse('${AppConstants.merriamWebsterApiUrl}/$word?key=${AppConstants.merriamWebsterApiKey}');
      print('Fetching syllables from Merriam-Webster for: $word');
      final response = await _client.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Merriam-Webster response for "$word": $data');
        // Response format: array of entries with hwi.hw containing syllables with * delimiter
        if (data.isNotEmpty) {
          // Get first entry for audio extraction and ID
          final firstEntry = data[0] is Map ? data[0] as Map<String, dynamic> : null;
          
          // Check the actual word ID returned by Merriam-Webster (use first entry for ID)
          if (firstEntry != null) {
            final meta = firstEntry['meta'] as Map<String, dynamic>?;
            if (meta != null && meta['id'] != null) {
              var rawId = meta['id'].toString();
              // Strip homograph indicators like ":1", ":2", etc. from the ID
              // These are just indicators to distinguish multiple entries, not part of the word
              final colonIndex = rawId.indexOf(':');
              actualWordId = colonIndex > 0 ? rawId.substring(0, colonIndex) : rawId;
              print('Merriam-Webster meta.id for searched "$word": "$rawId" (cleaned to "$actualWordId")');
            }
          }
          
          // Try each entry until we find valid syllables
          bool foundValidSyllables = false;
          for (var entryData in data) {
            if (entryData is! Map) continue;
            final entry = entryData as Map<String, dynamic>;
            
            // Try to extract syllables from this entry
            final hwi = entry['hwi'] as Map<String, dynamic>?;
            if (hwi != null && hwi['hw'] != null && !foundValidSyllables) {
              // hw contains syllables separated by *, e.g., "beau*ti*ful"
              final hw = hwi['hw'].toString();
              final extractedSyllables = hw.replaceAll('*', '.');
              
              // Validate syllables: remove dots and compare with original word (case-insensitive)
              // This ensures we don't use malformed syllables like "genegal" for "general"
              final syllablesWithoutDots = extractedSyllables.replaceAll('.', '').toLowerCase();
              final wordLower = word.toLowerCase();
              
              if (syllablesWithoutDots == wordLower) {
                syllables = extractedSyllables;
                foundValidSyllables = true;
                print('Parsed syllables for "$word": $syllables');
                break; // Found valid syllables, stop searching
              } else {
                print('Skipping invalid syllables "$extractedSyllables" for "$word" (syllables without dots: "$syllablesWithoutDots" != "$wordLower")');
              }
            }
          }
          
          if (!foundValidSyllables) {
            print('No valid hwi.hw found in any entry for "$word"');
          }
          
          // Try to extract audio from Merriam-Webster if we don't have it from FreeDictionaryAPI
          if ((audioUrl == null || audioUrl.isEmpty) && firstEntry != null) {
            print('Attempting to extract audio from Merriam-Webster for "$word"');
            
            // Look for audio in vrs (variants) array
            final vrs = firstEntry['vrs'] as List<dynamic>?;
            if (vrs != null) {
              for (var variant in vrs) {
                if (variant is Map<String, dynamic>) {
                  final prs = variant['prs'] as List<dynamic>?;
                  if (prs != null) {
                    for (var pr in prs) {
                      if (pr is Map<String, dynamic>) {
                        final sound = pr['sound'] as Map<String, dynamic>?;
                        if (sound != null) {
                          final audioId = sound['audio'];
                          if (audioId != null && audioId.toString().isNotEmpty) {
                            // Construct Merriam-Webster audio URL
                            // Format: https://media.merriam-webster.com/audio/prons/en/us/mp3/[first_letter]/[audio_id].mp3
                            final audioIdStr = audioId.toString();
                            if (audioIdStr.isNotEmpty) {
                              final firstLetter = audioIdStr[0].toLowerCase();
                              audioUrl = 'https://media.merriam-webster.com/audio/prons/en/us/mp3/$firstLetter/$audioIdStr.mp3';
                              print('Constructed Merriam-Webster audio URL for "$word": "$audioUrl"');
                              break; // Use first audio found
                            }
                          }
                        }
                      }
                    }
                    if (audioUrl != null && audioUrl.isNotEmpty) break;
                  }
                }
              }
            }
            
            // If still no audio, try hwi.prs (headword pronunciations) from first entry
            if (audioUrl == null || audioUrl.isEmpty) {
              final firstHwi = firstEntry['hwi'] as Map<String, dynamic>?;
              if (firstHwi != null) {
                final hwiPrs = firstHwi['prs'] as List<dynamic>?;
                if (hwiPrs != null) {
                  for (var pr in hwiPrs) {
                    if (pr is Map<String, dynamic>) {
                      final sound = pr['sound'] as Map<String, dynamic>?;
                      if (sound != null) {
                        final audioId = sound['audio'];
                        if (audioId != null && audioId.toString().isNotEmpty) {
                          final audioIdStr = audioId.toString();
                          if (audioIdStr.isNotEmpty) {
                            final firstLetter = audioIdStr[0].toLowerCase();
                            audioUrl = 'https://media.merriam-webster.com/audio/prons/en/us/mp3/$firstLetter/$audioIdStr.mp3';
                            print('Constructed Merriam-Webster audio URL from hwi.prs for "$word": "$audioUrl"');
                            break;
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        } else {
          print('Response is empty or not a Map for "$word"');
        }
      } else {
        print('Merriam-Webster API returned status: ${response.statusCode} for "$word"');
      }
    } catch (e) {
      print('Error fetching Merriam-Webster for "$word": $e');
    }

    return {
      'audioUrl': audioUrl,
      'phonetic': phonetic,
      'syllables': syllables,
      'actualWordId': actualWordId, // Return the actual word ID if different
    };
  }
}
