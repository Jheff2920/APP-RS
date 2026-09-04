class PrintMargins {
  const PrintMargins({
    this.leftMm = 0,
    this.rightMm = 0,
    /// Avance de papel al final (para poder cortar / despegar).
    this.bottomMm = 10,
  });

  final double leftMm;
  final double rightMm;
  final double bottomMm;

  PrintMargins copyWith({
    double? leftMm,
    double? rightMm,
    double? bottomMm,
  }) {
    return PrintMargins(
      leftMm: leftMm ?? this.leftMm,
      rightMm: rightMm ?? this.rightMm,
      bottomMm: bottomMm ?? this.bottomMm,
    );
  }

  Map<String, dynamic> toJson() => {
        'leftMm': leftMm,
        'rightMm': rightMm,
        'bottomMm': bottomMm,
      };

  factory PrintMargins.fromJson(Map<String, dynamic> json) {
    final bottom = (json['bottomMm'] as num?)?.toDouble();
    return PrintMargins(
      leftMm: (json['leftMm'] as num?)?.toDouble() ?? 0,
      rightMm: (json['rightMm'] as num?)?.toDouble() ?? 0,
      bottomMm: bottom ?? 10,
    );
  }
}
