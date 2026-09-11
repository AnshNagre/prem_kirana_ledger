/// Utility to phonetically convert English customer names to Hindi (Devanagari).
/// If a name is already in Devanagari script or empty, it is returned intact.
class HindiTransliterator {
  static final RegExp _devanagariRegex = RegExp(r'[\u0900-\u097F]');

  /// Common Indian given names and surnames mapped for 100% accuracy.
  static final Map<String, String> _dictionary = {
    // Common first names
    'ansh': 'अंश',
    'anshu': 'अंशु',
    'priya': 'प्रिया',
    'ramesh': 'रमेश',
    'suresh': 'सुरेश',
    'mahesh': 'महेश',
    'dinesh': 'दिनेश',
    'rajesh': 'राजेश',
    'mukesh': 'मुकेश',
    'rakesh': 'राकेश',
    'naresh': 'नरेश',
    'umesh': 'उमेश',
    'kamlesh': 'कमलेश',
    'santosh': 'संतोष',
    'rahul': 'राहुल',
    'rohit': 'रोहित',
    'mohit': 'मोहित',
    'amit': 'अमित',
    'sumit': 'सुमित',
    'anil': 'अनिल',
    'sunil': 'सुनील',
    'deepak': 'दीपक',
    'vikas': 'विकास',
    'vishal': 'विशाल',
    'vijay': 'विजय',
    'ajay': 'अजय',
    'sanjay': 'संजय',
    'manoj': 'मनोज',
    'vinod': 'विनोद',
    'pramod': 'प्रमोद',
    'alok': 'आलोक',
    'ashok': 'अशोक',
    'sachin': 'सचिन',
    'nitin': 'नितिन',
    'sandeep': 'संदीप',
    'pradeep': 'प्रदीप',
    'kuldeep': 'कुलदीप',
    'kamal': 'कमल',
    'kiran': 'किरण',
    'mohan': 'मोहन',
    'sohan': 'सोहन',
    'rohan': 'रोहन',
    'karan': 'करण',
    'arjun': 'अर्जुन',
    'shyam': 'श्याम',
    'ram': 'राम',
    'prem': 'प्रेम',
    'gopal': 'गोपाल',
    'govind': 'गोविंद',
    'krishna': 'कृष्णा',
    'radha': 'राधा',
    'pooja': 'पूजा',
    'neha': 'नेहा',
    'sonam': 'सोनम',
    'geeta': 'गीता',
    'seema': 'सीमा',
    'reena': 'रीना',
    'meena': 'मीना',
    'mona': 'मोना',
    'sunita': 'सुनीता',
    'anita': 'अनीता',
    'rekha': 'रेखा',
    'kavita': 'कविता',
    'sarita': 'सरिता',
    'babita': 'बबीता',
    'laxmi': 'लक्ष्मी',
    'lakshmi': 'लक्ष्मी',
    'aarti': 'आरती',
    'arti': 'आरती',
    'swati': 'स्वाति',
    'jyoti': 'ज्योति',
    'shubham': 'शुभम',
    'shivam': 'शिवम',
    'pawan': 'पवन',
    'pankaj': 'पंकज',
    'bharat': 'भारत',
    'bhagwan': 'भगवान',
    'raj': 'राज',
    'raju': 'राजू',
    'sonu': 'सोनू',
    'monu': 'मोनू',
    'chintu': 'चिंटू',
    'pinki': 'पिंकी',
    'golu': 'गोलू',
    'babloo': 'बबलू',
    'bablu': 'बबलू',
    'pappu': 'पप्पू',
    'munna': 'मुन्ना',
    'hari': 'हरि',
    'harish': 'हरीश',
    'ravi': 'रवि',
    'shankar': 'शंकर',
    'shiv': 'शिव',
    'om': 'ओम',

    // Common Surnames / Titles
    'nagre': 'नागरे',
    'deshmukh': 'देशमुख',
    'sharma': 'शर्मा',
    'verma': 'वर्मा',
    'patel': 'पटेल',
    'gupta': 'गुप्ता',
    'singh': 'सिंह',
    'kumar': 'कुमार',
    'yadav': 'यादव',
    'mishra': 'मिश्रा',
    'tiwari': 'तिवारी',
    'pandey': 'पांडे',
    'shukla': 'शुक्ला',
    'dubey': 'दुबे',
    'chaubey': 'चौबे',
    'jha': 'झा',
    'thakur': 'ठाकुर',
    'chauhan': 'चौहान',
    'rajput': 'राजपूत',
    'jain': 'जैन',
    'agarwal': 'अग्रवाल',
    'agrawal': 'अग्रवाल',
    'bansal': 'बंसल',
    'mittal': 'मित्तल',
    'goyal': 'गोयल',
    'khandelwal': 'खंडेलवाल',
    'maheshwari': 'माहेश्वरी',
    'joshi': 'जोशी',
    'bhatt': 'भट्ट',
    'rawat': 'रावत',
    'negi': 'नेगी',
    'choudhary': 'चौधरी',
    'choudhury': 'चौधरी',
    'patil': 'पाटिल',
    'pawar': 'पवार',
    'kadam': 'कदम',
    'shinde': 'शिंदे',
    'gaikwad': 'गायकवाड़',
    'bhosale': 'भोसले',
    'jadhav': 'जाधव',
    'more': 'मोरे',
    'sawant': 'सावंत',
    'kale': 'काळे',
    'koli': 'कोली',
    'shah': 'शाह',
    'mehta': 'मेहता',
    'soni': 'सोनी',
    'sahu': 'साहू',
    'sen': 'सेन',
    'das': 'दास',
    'bose': 'बोस',
    'reddy': 'रेड्डी',
    'rao': 'राव',
    'nair': 'नायर',
    'pillai': 'पिल्लई',
    'menon': 'मेनन',
    'khan': 'खान',
    'ansari': 'अंसारी',
    'shaikh': 'शेख',
    'sheikh': 'शेख',
    'sayyad': 'सैयद',
    'ali': 'अली',
    'ahmed': 'अहमद',
    'malik': 'मलिक',
    'quraishi': 'कुरैशी',
    'qureshi': 'कुरैशी',
    'siddiqui': 'सिद्दीकी',
    'lal': 'लाल',
    'seth': 'सेठ',
    'devi': 'देवी',
    'bai': 'बाई',
    'bhai': 'भाई',
    'ben': 'बेन',
    'didi': 'दीदी',
    'chacha': 'चाचा',
    'kaka': 'काका',
    'mama': 'मामा',
  };

  /// Main entry point: converts [input] English name to Hindi Devanagari.
  static String toHindi(String input) {
    if (input.trim().isEmpty) return input;
    // If it already contains Hindi characters, preserve it
    if (_devanagariRegex.hasMatch(input)) return input;

    final words = input.split(RegExp(r'\s+'));
    final convertedWords = words.map(_convertSingleWord).toList();
    return convertedWords.join(' ');
  }

  static String _convertSingleWord(String word) {
    if (word.trim().isEmpty) return word;
    final lower = word.toLowerCase().trim();

    // 1. Direct dictionary match
    if (_dictionary.containsKey(lower)) {
      return _dictionary[lower]!;
    }

    // 2. Phonetic transliteration engine
    return _phoneticTransliterate(lower);
  }

  static String _phoneticTransliterate(String text) {
    final buffer = StringBuffer();
    int i = 0;
    final len = text.length;

    // Special initial vowel map
    const initialVowels = {
      'aa': 'आ',
      'a': 'अ',
      'ee': 'ई',
      'i': 'इ',
      'oo': 'ऊ',
      'u': 'उ',
      'e': 'ए',
      'ai': 'ऐ',
      'o': 'ओ',
      'au': 'औ',
      'ri': 'ऋ',
    };

    // Dependent vowel (matra) map
    const matras = {
      'aa': 'ा',
      'a': '',
      'ee': 'ी',
      'i': 'ि',
      'oo': 'ू',
      'u': 'ु',
      'e': 'े',
      'ai': 'ै',
      'o': 'ो',
      'au': 'ौ',
    };

    // Consonant map
    const consonants = {
      'chh': 'छ',
      'kh': 'ख',
      'gh': 'घ',
      'ch': 'च',
      'jh': 'झ',
      'th': 'थ',
      'dh': 'ध',
      'ph': 'फ',
      'bh': 'भ',
      'sh': 'श',
      'shh': 'ष',
      'wh': 'व',
      'k': 'क',
      'g': 'ग',
      'c': 'क',
      'j': 'ज',
      't': 'त',
      'd': 'द',
      'n': 'न',
      'p': 'प',
      'f': 'फ',
      'b': 'ब',
      'm': 'म',
      'y': 'य',
      'r': 'र',
      'l': 'ल',
      'v': 'व',
      'w': 'व',
      's': 'स',
      'h': 'ह',
      'z': 'ज़',
      'q': 'क',
      'x': 'क्स',
    };

    bool isInitial = true;

    while (i < len) {
      // Check if character is not a letter
      final char = text[i];
      if (!RegExp(r'[a-z]').hasMatch(char)) {
        buffer.write(char);
        i++;
        isInitial = true;
        continue;
      }

      // Check initial vowels
      if (isInitial) {
        bool matchedVowel = false;
        for (final vLen in [2, 1]) {
          if (i + vLen <= len) {
            final sub = text.substring(i, i + vLen);
            if (initialVowels.containsKey(sub)) {
              buffer.write(initialVowels[sub]);
              i += vLen;
              isInitial = false;
              matchedVowel = true;
              break;
            }
          }
        }
        if (matchedVowel) continue;
      }

      // Check consonants (up to 3 chars: chh, then 2: kh/gh/sh, then 1)
      String? matchedConsonant;
      int cLen = 0;
      for (final testLen in [3, 2, 1]) {
        if (i + testLen <= len) {
          final sub = text.substring(i, i + testLen);
          if (consonants.containsKey(sub)) {
            matchedConsonant = consonants[sub];
            cLen = testLen;
            break;
          }
        }
      }

      if (matchedConsonant != null) {
        buffer.write(matchedConsonant);
        i += cLen;
        isInitial = false;

        // Now check following vowel/matra
        String? matchedMatra;
        int mLen = 0;
        for (final testLen in [2, 1]) {
          if (i + testLen <= len) {
            final sub = text.substring(i, i + testLen);
            if (matras.containsKey(sub)) {
              matchedMatra = matras[sub];
              mLen = testLen;
              break;
            }
          }
        }

        if (matchedMatra != null) {
          buffer.write(matchedMatra);
          i += mLen;
        } else {
          // If followed by another consonant and not at end of word, add halant
          if (i < len && RegExp(r'[a-z]').hasMatch(text[i])) {
            // Check if next is a consonant
            bool nextIsConsonant = false;
            for (final testLen in [3, 2, 1]) {
              if (i + testLen <= len && consonants.containsKey(text.substring(i, i + testLen))) {
                nextIsConsonant = true;
                break;
              }
            }
            if (nextIsConsonant) {
              buffer.write('्'); // Halant for conjunct
            }
          }
        }
      } else {
        // Fallback for unmatched character
        buffer.write(text[i]);
        i++;
      }
    }

    return buffer.toString();
  }
}
