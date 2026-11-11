/// Chạy [task] cho từng phần tử, tối đa [limit] việc cùng lúc. Kết quả giữ
/// đúng thứ tự [items]. Một việc lỗi thì Future trả về lỗi đó.
Future<List<R>> mapWithLimit<T, R>(
  List<T> items,
  Future<R> Function(T item) task, {
  int limit = 4,
}) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (next < items.length) {
      final i = next++;
      results[i] = await task(items[i]);
    }
  }

  await Future.wait([
    for (var w = 0; w < limit && w < items.length; w++) worker(),
  ]);
  return results.cast<R>();
}
