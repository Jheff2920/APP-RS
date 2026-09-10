import 'package:flutter_test/flutter_test.dart';
import 'package:hello_world_app/models/print_margins.dart';

void main() {
  test('default bottom margin is 15 mm', () {
    expect(const PrintMargins().bottomMm, 15);
    expect(PrintMargins.fromJson({}).bottomMm, 15);
  });

  test('saved bottom margin is kept', () {
    expect(PrintMargins.fromJson({'bottomMm': 10}).bottomMm, 10);
  });

  test('equal margins compare equal', () {
    expect(const PrintMargins(bottomMm: 15), const PrintMargins());
  });
}
