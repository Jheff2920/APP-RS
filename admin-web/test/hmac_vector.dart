import 'package:hello_world_app/services/redpos/redpos_code.dart';

void main(List<String> args) {
  const secret = 'unit-test-secret';
  if (args.isEmpty) {
    // ignore: avoid_print
    print(RedPosCode.generate(secret: secret));
    return;
  }
  // ignore: avoid_print
  print(RedPosCode.verify(args.first, secret: secret).ok);
}
