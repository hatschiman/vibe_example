enum TranscriptionStatus { pending, transcribing, done, failed }

class Memo {
  const Memo({
    required this.id,
    required this.createdAt,
    required this.duration,
    required this.fileName,
    this.transcript,
    this.status = TranscriptionStatus.pending,
  });

  final String id;
  final DateTime createdAt;
  final Duration duration;

  /// File name inside the app's memo directory. Only the name is stored
  /// because the documents directory can move between app installs on iOS.
  final String fileName;
  final String? transcript;
  final TranscriptionStatus status;

  bool get hasTranscript => transcript != null && transcript!.trim().isNotEmpty;

  Memo copyWith({
    String? transcript,
    TranscriptionStatus? status,
  }) {
    return Memo(
      id: id,
      createdAt: createdAt,
      duration: duration,
      fileName: fileName,
      transcript: transcript ?? this.transcript,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt.millisecondsSinceEpoch,
        'duration_ms': duration.inMilliseconds,
        'file_name': fileName,
        'transcript': transcript,
        'status': status.name,
      };

  factory Memo.fromMap(Map<String, Object?> map) => Memo(
        id: map['id'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        duration: Duration(milliseconds: map['duration_ms'] as int),
        fileName: map['file_name'] as String,
        transcript: map['transcript'] as String?,
        status: TranscriptionStatus.values.byName(map['status'] as String),
      );
}
