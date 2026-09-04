enum PrintJobStatus {
  queued,
  success,
  failed;

  String get label {
    switch (this) {
      case PrintJobStatus.queued:
        return 'En cola';
      case PrintJobStatus.success:
        return 'Impreso';
      case PrintJobStatus.failed:
        return 'Fallido';
    }
  }

  static PrintJobStatus fromName(String name) {
    return PrintJobStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PrintJobStatus.failed,
    );
  }
}

class PrintJobRecord {
  PrintJobRecord({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.printerId,
    required this.printerName,
    required this.status,
    this.error,
    this.source = 'app',
  });

  final String id;
  final DateTime createdAt;
  final String title;
  final String printerId;
  final String printerName;
  final PrintJobStatus status;
  final String? error;
  final String source; // app | share | test

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'printerId': printerId,
        'printerName': printerName,
        'status': status.name,
        'error': error,
        'source': source,
      };

  factory PrintJobRecord.fromJson(Map<String, dynamic> json) {
    return PrintJobRecord(
      id: json['id'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: json['title'] as String? ?? 'Trabajo',
      printerId: json['printerId'] as String? ?? '',
      printerName: json['printerName'] as String? ?? '',
      status: PrintJobStatus.fromName(json['status'] as String? ?? 'failed'),
      error: json['error'] as String?,
      source: json['source'] as String? ?? 'app',
    );
  }
}
