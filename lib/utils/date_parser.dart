class DateParser {
  /// Parses an ISO 8601 or standard datetime string without letting local timezone shifts modify the date/time.
  /// It strips any trailing timezone offsets (+xx:xx, -xx:xx, or Z) before parsing.
  static DateTime parseTimezoneIndependent(String dateTimeStr) {
    // Matches YYYY-MM-DD[T or space]HH:MM:SS with optional fraction of a second (.SSS)
    final regex = RegExp(r'^(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?)');
    final match = regex.firstMatch(dateTimeStr);
    if (match != null) {
      return DateTime.parse(match.group(1)!);
    }
    return DateTime.parse(dateTimeStr);
  }
}
