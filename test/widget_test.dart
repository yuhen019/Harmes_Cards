// 占位 widget 测试：模板自带的计数器测试已不适用。
// 功能测试见 test/guardrails_test.dart（护栏）与 tool/test_suite.dart（算法/存储/同步）。
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('占位：功能测试由 guardrails_test / test_suite 承担', () {
    expect(1 + 1, 2);
  });
}
