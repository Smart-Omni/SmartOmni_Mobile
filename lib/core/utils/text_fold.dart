const _accents = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

/// Chữ thường, bỏ dấu tiếng Việt: "Tạm KHÓA" -> "tam khoa".
/// Dùng để so khớp thông điệp backend (có thể có dấu hoặc không).
String foldVietnamese(String input) {
  final buffer = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    var out = ch;
    for (final entry in _accents.entries) {
      if (entry.value.contains(ch)) {
        out = entry.key;
        break;
      }
    }
    buffer.write(out);
  }
  return buffer.toString();
}
