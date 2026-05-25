class PianoNote {
  final String name; // ex: "C4", "D#4"
  final double frequency; // Hz
  final int durationMs; // durée en millisecondes

  const PianoNote({
    required this.name,
    required this.frequency,
    required this.durationMs,
  });

  PianoNote copyWith({String? name, double? frequency, int? durationMs}) {
    return PianoNote(
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'frequency': frequency,
    'durationMs': durationMs,
  };

  factory PianoNote.fromJson(Map<String, dynamic> json) => PianoNote(
    name: json['name'] as String,
    frequency: (json['frequency'] as num).toDouble(),
    durationMs: json['durationMs'] as int,
  );
}
