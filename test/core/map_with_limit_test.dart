import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/utils/map_with_limit.dart';

void main() {
  test('không quá limit việc cùng lúc, giữ đúng thứ tự', () async {
    var running = 0;
    var peak = 0;
    final out = await mapWithLimit(List.generate(10, (i) => i), (i) async {
      running++;
      if (running > peak) peak = running;
      // Việc sau xong trước việc trước: thứ tự vẫn phải đúng.
      await Future<void>.delayed(Duration(milliseconds: 20 - i));
      running--;
      return i * 10;
    }, limit: 4);

    expect(out, [for (var i = 0; i < 10; i++) i * 10]);
    expect(peak, 4);
  });

  test('danh sách rỗng', () async {
    expect(await mapWithLimit(<int>[], (i) async => i), isEmpty);
  });

  test('một việc lỗi thì cả lời gọi lỗi', () async {
    await expectLater(
      mapWithLimit([1, 2, 3], (i) async {
        if (i == 2) throw StateError('hỏng');
        return i;
      }),
      throwsStateError,
    );
  });
}
