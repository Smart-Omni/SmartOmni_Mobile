import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/routes.dart';
import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../customer_shop/domain/customer_shop.dart';
import '../../customer_shop/presentation/customer_shop_providers.dart';
import '../../customer_shop/presentation/no_shop_state.dart';
import '../../products/domain/product.dart';
import '../../storefront/presentation/storefront_screens.dart';
import '../data/chatbot_mock_repository.dart';
import '../domain/chatbot.dart';

/// Chỉ có Mock: backend chưa có API chatbot.
final chatbotRepositoryProvider = Provider<ChatbotRepository>(
  (ref) => ChatbotMockRepository(ref.watch(storefrontRepositoryProvider)),
);

/// Một dòng trong khung chat: câu hỏi của khách, hoặc câu trả lời của trợ lý
/// (`null` khi đang chờ).
typedef _Entry = ({String? question, ChatReply? reply});

/// C-12 Trợ lý cửa hàng (DESIGN.md mục 8b): tư vấn sản phẩm của cửa hàng
/// đang xem, không đặt hàng. Không có câu hỏi gợi ý. Lịch sử chỉ giữ trong
/// lúc mở màn.
class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final List<_Entry> _entries = [];

  bool get _waiting =>
      _entries.isNotEmpty &&
      _entries.last.question == null &&
      _entries.last.reply == null;

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _ask(CustomerShop shop) async {
    final text = _input.text.trim();
    if (text.isEmpty || _waiting) return;
    setState(() {
      _entries
        ..add((question: text, reply: null))
        ..add((question: null, reply: null));
      _input.clear();
    });
    _scrollToEnd();
    ChatReply reply;
    try {
      reply = await ref
          .read(chatbotRepositoryProvider)
          .ask(shop.tenantId, text);
    } catch (_) {
      reply = const ChatReply(
        text: 'Trợ lý đang bận, bạn thử lại sau nhé.',
        fallback: true,
      );
    }
    if (!mounted) return;
    setState(() => _entries.last = (question: null, reply: reply));
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(currentShopProvider);
    final shop = shopAsync.value;

    return SoScaffold(
      controller: _scroll,
      scrollable: shopAsync.hasValue || shopAsync.hasError,
      appBar: SoAppBar(
        title: shop == null ? 'Trợ lý' : 'Trợ lý ${shop.name}',
        subtitle: 'Tư vấn sản phẩm · không đặt hàng',
        subtitleIsCode: false,
        actions: const [
          Center(child: SoAiLabel()),
          SizedBox(width: SoSpace.screen),
        ],
      ),
      bottomBar: shop == null
          ? null
          : SoChatComposer(
              controller: _input,
              sending: _waiting,
              hint: 'Hỏi về sản phẩm',
              onSend: () => _ask(shop),
            ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: switch (shopAsync) {
            AsyncData(value: null) => const SliverToBoxAdapter(
              child: NoShopState(),
            ),
            AsyncData(value: final shop?) => SliverList.list(
              children: [
                const SoMockBanner(
                  message: 'Trợ lý trả lời bằng dữ liệu mẫu, chưa nối AI.',
                ),
                const SizedBox(height: SoSpace.s16),
                SoChatBubble(
                  key: const Key('chat_greeting'),
                  mine: false,
                  child: Text(
                    'Chào bạn, mình là trợ lý của ${shop.name}. Bạn cần tìm '
                    'sản phẩm gì?',
                  ),
                ),
                for (final (i, e) in _entries.indexed) ...[
                  const SizedBox(height: SoSpace.s12),
                  if (e.question case final q?)
                    SoChatBubble(
                      key: Key('chat_question_$i'),
                      mine: true,
                      child: Text(q),
                    )
                  else if (e.reply case final r?)
                    _ReplyBubble(key: Key('chat_reply_$i'), reply: r)
                  else
                    const _Typing(),
                ],
              ],
            ),
            AsyncError(:final error) => SliverToBoxAdapter(
              child: SoEmptyState.error(
                title: 'Không tải được cửa hàng',
                message: AsyncValueView.errorMessage(error),
                onAction: () => ref.invalidate(myShopsProvider),
              ),
            ),
            _ => const SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SoSkeleton(width: 240, height: 48, radius: SoRadius.lg),
              ),
            ),
          },
        ),
      ],
    );
  }
}

/// Câu trả lời của trợ lý + thẻ sản phẩm gợi ý. Dự phòng: nền warningTint.
class _ReplyBubble extends StatelessWidget {
  const _ReplyBubble({super.key, required this.reply});

  final ChatReply reply;

  @override
  Widget build(BuildContext context) {
    return SoChatBubble(
      mine: false,
      tone: reply.fallback ? SoChatTone.fallback : SoChatTone.normal,
      below: [
        for (final p in reply.products) ...[
          const SizedBox(height: SoSpace.s4),
          _ProductSuggestion(product: p),
        ],
      ],
      child: Text(reply.text),
    );
  }
}

/// Thẻ sản phẩm ngang trong chat: ô ảnh 56, tên, giá "Từ", kênh → C-11.
class _ProductSuggestion extends StatelessWidget {
  const _ProductSuggestion({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final p = product;
    final price = 'Từ ${Formatters.vnd(p.minPrice)}';
    final channels = [
      for (final platform in Platform.values)
        if (p.marketplaceUrls.containsKey(platform)) platform,
    ];
    return DecoratedBox(
      decoration: SoShape.card(c),
      child: Material(
        type: MaterialType.transparency,
        shape: SoShape.squircle(SoRadius.lgAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('chat_product_${p.id}'),
          onTap: () => context.push(Routes.customerProduct(p.id)),
          child: Semantics(
            button: true,
            label: '${p.name}, $price',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(SoSpace.s12),
              child: Row(
                children: [
                  // Chưa có ảnh sản phẩm thật: ô fill + icon (như C-10).
                  Container(
                    width: 56,
                    height: 56,
                    decoration: ShapeDecoration(
                      color: c.fill,
                      shape: SoShape.squircle(SoRadius.smAll),
                    ),
                    child: Icon(LucideIcons.image, color: c.muted),
                  ),
                  const SizedBox(width: SoSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleMedium,
                        ),
                        Text(price, style: context.soText.money),
                        if (channels.isNotEmpty) ...[
                          const SizedBox(height: SoSpace.s4),
                          Wrap(
                            spacing: SoSpace.s8,
                            runSpacing: SoSpace.s4,
                            children: [
                              for (final platform in channels)
                                SoChannelTag(platform: platform),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Trợ lý đang trả lời: 3 chấm tĩnh trong bong bóng trắng.
class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    return SoChatBubble(
      key: const Key('chat_typing'),
      mine: false,
      child: Semantics(
        label: 'Trợ lý đang trả lời',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: SoSpace.s4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.muted,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
