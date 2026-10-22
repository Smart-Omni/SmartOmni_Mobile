import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Đồng hồ dùng chung: dữ liệu mẫu và nhãn ngày ("Hôm nay", "Hôm qua") đọc
/// cùng một nguồn. Test ghi đè bằng thời điểm cố định để không phụ thuộc giờ
/// máy (vd. chạy lúc 0h thì đơn "1 giờ trước" thuộc hôm qua).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
