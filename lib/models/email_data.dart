class EmailData {
  final String id;
  final String? from;
  final String? subject;
  final String? body;
  final DateTime? date;
  final String? snippet;

  const EmailData({
    required this.id,
    this.from,
    this.subject,
    this.body,
    this.date,
    this.snippet,
  });

  @override
  String toString() {
    return 'EmailData(id: $id, from: $from, subject: $subject, date: $date)';
  }
}
