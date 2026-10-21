import '../../../core/utils/text_fold.dart';
import '../../products/domain/product.dart';

/// Câu trả lời của trợ lý C-12. Trợ lý chỉ tư vấn, không đặt hàng
/// (docs/REQUIREMENTS.md: khách mua trên sàn).
class ChatReply {
  const ChatReply({
    required this.text,
    this.products = const [],
    this.fallback = false,
  });

  final String text;

  /// Sản phẩm gợi ý (thẻ bấm được → C-11), tối đa [maxSuggestions].
  final List<Product> products;

  /// Câu trả lời dự phòng: trợ lý không trả lời được (nền warningTint).
  final bool fallback;
}

/// ⚠️ Backend chưa có API chatbot (`POST /api/storefront/chat`, docs/
/// API_CONTRACT.md) -> mock.
abstract interface class ChatbotRepository {
  Future<ChatReply> ask(int tenantId, String question);
}

const maxSuggestions = 3;

const _orderWords = ['đặt hàng', 'đặt mua', 'mua', 'thanh toán', 'chốt đơn'];

/// Khách muốn đặt / mua hàng ngay trong chat: trợ lý nhắc mua trên sàn.
///
/// Câu có dấu thì so theo từ có dấu ("mùa hè" không phải "mua"); câu gõ
/// không dấu thì so theo từ đã bỏ dấu.
bool isOrderIntent(String question) {
  final lower = question.toLowerCase();
  final folded = foldVietnamese(lower);
  final accented = folded != lower;
  final q =
      ' ${(accented ? lower : folded).replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')} ';
  return _orderWords.any(
    (w) => q.contains(' ${accented ? w : foldVietnamese(w)} '),
  );
}
