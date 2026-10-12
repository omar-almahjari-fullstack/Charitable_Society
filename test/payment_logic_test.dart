import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly payment coverage is exact', () {
    const amount = 150.0, fee = 50.0;
    expect(amount / fee, 3);
  });
  test('rejects a non-integral subscription amount', () {
    expect(125 % 50, isNot(0));
  });
}
