import 'package:flutter_test/flutter_test.dart';
import 'package:hello_world_app/services/redpos/redpos_code.dart';

void main() {
  test('generated codes verify with the same secret', () {
    final code = RedPosCode.generate(secret: 'unit-test-secret');
    expect(code.startsWith('RP-'), isTrue);
    final result = RedPosCode.verify(code, secret: 'unit-test-secret');
    expect(result.ok, isTrue);
    expect(result.nonce, hasLength(8));
  });

  test('wrong secret is rejected', () {
    final code = RedPosCode.generate(secret: 'a');
    expect(RedPosCode.verify(code, secret: 'b').ok, isFalse);
  });

  test('spaces and lowercase still verify', () {
    final code = RedPosCode.generate(secret: 's');
    final spaced = code.toLowerCase().replaceAll('-', ' - ');
    expect(RedPosCode.verify(spaced, secret: 's').ok, isTrue);
  });

  test('master code R100301S is rejected', () {
    expect(RedPosCode.verify('R100301S').ok, isFalse);
  });

  test('old demo alias is no longer accepted', () {
    expect(RedPosCode.verify('REDPOS-PRUEBA-1').ok, isFalse);
  });
}
