final class RadioBeaconImportIssue {
  const RadioBeaconImportIssue({
    required this.code,
    required this.message,
    this.line,
    this.field,
  });

  final String code;
  final String message;
  final int? line;
  final String? field;

  @override
  String toString() {
    final location = [
      if (line != null) 'line $line',
      if (field != null) 'field $field',
    ].join(', ');
    return location.isEmpty
        ? '[$code] $message'
        : '[$code] $location: $message';
  }
}

final class RadioBeaconImportException implements Exception {
  RadioBeaconImportException(List<RadioBeaconImportIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<RadioBeaconImportIssue> issues;

  @override
  String toString() => 'RadioBeaconImportException:\n${issues.join('\n')}';
}
