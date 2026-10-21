import '../../../core/utils/mock_delay.dart';
import '../../../core/utils/text_fold.dart';
import '../../products/domain/product.dart';
import '../../storefront/domain/storefront_repository.dart';
import '../domain/chatbot.dart';

/// Trợ lý mẫu: gợi ý sản phẩm của cửa hàng đang xem có tên chứa từ trong câu
/// hỏi; không khớp thì trả lời dự phòng.
class ChatbotMockRepository implements ChatbotRepository {
  ChatbotMockRepository(this._storefront);

  final StorefrontRepository _storefront;

  @override
  Future<ChatReply> ask(int tenantId, String question) async {
    await MockDelay.short();
    final products = await _storefront.listProducts(tenantId);
    final found = _match(products, question);
    if (isOrderIntent(question)) {
      return ChatReply(
        text:
            'Mình không đặt hàng được. Bạn chọn sản phẩm rồi mua trên Shopee '
            'hoặc TikTok Shop nhé.',
        products: found,
      );
    }
    if (found.isEmpty) {
      return const ChatReply(
        text:
            'Mình chưa trả lời được câu này. Bạn xem thêm ở trang Sản phẩm '
            'hoặc nhắn shop trên sàn nhé.',
        fallback: true,
      );
    }
    return ChatReply(
      text: 'Mình tìm được ${found.length} sản phẩm phù hợp:',
      products: found,
    );
  }

  /// Từ có từ 3 chữ cái trở lên trong câu hỏi xuất hiện trong tên sản phẩm.
  static List<Product> _match(List<Product> products, String question) {
    final words = foldVietnamese(
      question,
    ).split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 3).toSet();
    return [
      for (final p in products)
        if (foldVietnamese(
          p.name,
        ).split(RegExp(r'[^a-z0-9]+')).any(words.contains))
          p,
    ].take(maxSuggestions).toList();
  }
}
