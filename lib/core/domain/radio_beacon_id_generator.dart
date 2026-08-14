final class RadioBeaconIdGenerator {
  const RadioBeaconIdGenerator._();

  static String generate({
    required String name,
    required Iterable<String> existingIds,
  }) {
    final occupied = existingIds.map((id) => id.toLowerCase()).toSet();
    final transliterated = _transliterate(name.trim()).toUpperCase();
    final words = RegExp(
      r'[A-Z0-9]+',
    ).allMatches(transliterated).map((match) => match.group(0)!);
    var base = words.join('-');
    if (base.isEmpty) base = 'RADIOFARO';
    if (base.length > 64) base = base.substring(0, 64);
    if (!occupied.contains(base.toLowerCase())) return base;

    for (var suffix = 2; ; suffix++) {
      final tail = '-$suffix';
      final maximumBaseLength = 64 - tail.length;
      final shortened = base.length > maximumBaseLength
          ? base.substring(0, maximumBaseLength)
          : base;
      final candidate = '$shortened$tail';
      if (!occupied.contains(candidate.toLowerCase())) return candidate;
    }
  }

  static String _transliterate(String value) {
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(replacements[character.toLowerCase()] ?? character);
    }
    return buffer.toString();
  }
}
