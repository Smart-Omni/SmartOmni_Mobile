import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/formatters.dart';
import '../domain/support.dart';
import 'support_providers.dart';

/// T-50 Yêu cầu hỗ trợ (chỉ Tenant Admin, chặn ở `resolveRedirect`).
///
/// Segmented "Chưa xong / Đã giải quyết" có số đếm; hàng ticket là khối tĩnh
/// (chưa có màn chi tiết). Thanh dưới: Tạo yêu cầu (tiêu đề + mô tả); gửi xong
/// chuyển về tab "Chưa xong", ticket mới ở đầu.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _scroll = ScrollController();
  bool _showDone = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await showSoBottomSheet<SupportTicket>(
      context: context,
      builder: (_) => const _CreateTicketSheet(),
    );
    if (created == null || !mounted) return;
    setState(() => _showDone = false);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    showSoToast(context, 'Đã gửi yêu cầu ${created.code}');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supportTicketsProvider);
    final tickets = async.value;
    final (open, done) = splitTickets(tickets ?? const []);

    return SoScaffold(
      controller: _scroll,
      scrollable: tickets != null || async.hasError,
      appBar: const SoAppBar(title: 'Yêu cầu hỗ trợ'),
      bottomBar: SoActionBar(
        primary: SoButton(
          key: const Key('ticket_create'),
          label: 'Tạo yêu cầu',
          icon: LucideIcons.plus,
          onPressed: _create,
        ),
      ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverList.list(
            children: [
              const SoMockBanner(
                message: 'Yêu cầu là dữ liệu mẫu, chưa gửi tới đội hỗ trợ.',
              ),
              const SizedBox(height: SoSpace.s16),
              SoSegmented<bool>(
                key: const Key('ticket_tabs'),
                selected: _showDone,
                onChanged: (v) => setState(() => _showDone = v),
                segments: [
                  SoSegment(
                    value: false,
                    label: tickets == null
                        ? 'Chưa xong'
                        : 'Chưa xong · ${open.length}',
                  ),
                  SoSegment(
                    value: true,
                    label: tickets == null
                        ? 'Đã giải quyết'
                        : 'Đã giải quyết · ${done.length}',
                  ),
                ],
              ),
              const SizedBox(height: SoSpace.s16),
              if (tickets != null)
                _List(tickets: _showDone ? done : open, done: _showDone)
              else if (async.hasError && !async.isLoading)
                SoEmptyState.error(
                  key: const Key('ticket_error'),
                  title: 'Không tải được yêu cầu hỗ trợ',
                  message: 'Kiểm tra kết nối mạng rồi thử lại.',
                  onAction: () => ref.invalidate(supportTicketsProvider),
                )
              else
                const SoSkeletonList(count: 3),
            ],
          ),
        ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.tickets, required this.done});

  final List<SupportTicket> tickets;
  final bool done;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return SoEmptyState(
        key: const Key('ticket_empty'),
        icon: LucideIcons.lifeBuoy,
        title: done
            ? 'Chưa có yêu cầu nào được giải quyết'
            : 'Không có yêu cầu nào đang chờ',
        message: done ? null : 'Gặp vấn đề thì bấm Tạo yêu cầu.',
      );
    }
    return SoListGroup(
      children: [for (final t in tickets) _TicketRow(ticket: t)],
    );
  }
}

/// Khối tĩnh (không bấm được): mã + thời gian + nhãn, tiêu đề, trả lời cuối.
class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final c = context.soColors;
    final text = context.textTheme;
    final reply = t.lastReply;
    final status = switch (t.status) {
      TicketStatus.open => SoStatus.warning,
      TicketStatus.inProgress => SoStatus.info,
      TicketStatus.resolved => SoStatus.success,
    };
    return Container(
      key: Key('ticket_${t.id}'),
      color: c.surface,
      padding: SoSpace.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoCodeTag(t.code),
              const SizedBox(width: SoSpace.s8),
              Expanded(
                child: Text(
                  Formatters.dateTime(t.updatedAt),
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: SoSpace.s8),
              SoStatusTag(label: t.status.label, status: status),
            ],
          ),
          const SizedBox(height: SoSpace.s8),
          Text(
            t.title,
            style: text.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: SoSpace.s4),
          Text.rich(
            reply == null
                ? const TextSpan(text: 'Chưa có trả lời')
                : TextSpan(
                    children: [
                      TextSpan(
                        text: reply.author == ReplyAuthor.support
                            ? 'Hỗ trợ: '
                            : 'Bạn: ',
                        style: TextStyle(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: reply.text),
                    ],
                  ),
            key: Key('ticket_reply_${t.id}'),
            style: text.bodyMedium?.copyWith(color: c.ink2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Sheet "Tạo yêu cầu": tiêu đề (≤ 120) + mô tả (≤ 2.000).
class _CreateTicketSheet extends ConsumerStatefulWidget {
  const _CreateTicketSheet();

  @override
  ConsumerState<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends ConsumerState<_CreateTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _failed = false);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final ticket = await ref
          .read(supportRepositoryProvider)
          .create(
            title: _title.text.trim(),
            description: _description.text.trim(),
          );
      ref.invalidate(supportTicketsProvider);
      if (mounted) Navigator.pop(context, ticket);
    } catch (_) {
      // Giữ nguyên chữ đã nhập để gửi lại.
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SoBottomSheet(
        title: 'Tạo yêu cầu hỗ trợ',
        secondary: SoButton.secondary(
          key: const Key('ticket_cancel'),
          label: 'Hủy',
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        primary: SoButton(
          key: const Key('ticket_submit'),
          label: 'Gửi yêu cầu',
          loading: _busy,
          onPressed: _submit,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_failed) ...[
              const SoBanner(
                key: Key('ticket_submit_error'),
                tone: SoBannerTone.danger,
                title: 'Chưa gửi được yêu cầu',
                message: 'Kiểm tra kết nối mạng rồi thử lại.',
              ),
              const SizedBox(height: SoSpace.s16),
            ],
            SoTextField(
              key: const Key('ticket_title'),
              label: 'Tiêu đề',
              hint: 'Vd: Đơn TikTok Shop không về app',
              controller: _title,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                LengthLimitingTextInputFormatter(ticketTitleMax),
              ],
              validator: validateTicketTitle,
            ),
            const SizedBox(height: SoSpace.s16),
            SoTextField(
              key: const Key('ticket_description'),
              label: 'Mô tả',
              hint: 'Chuyện gì xảy ra, từ khi nào, mã đơn hoặc SKU liên quan',
              controller: _description,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              inputFormatters: [
                LengthLimitingTextInputFormatter(ticketDescriptionMax),
              ],
              validator: validateTicketDescription,
            ),
          ],
        ),
      ),
    );
  }
}
