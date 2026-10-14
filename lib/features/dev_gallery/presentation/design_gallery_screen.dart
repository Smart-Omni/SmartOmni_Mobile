import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../l10n/l10n.dart';
import '../../loyalty/domain/loyalty_rules.dart';

/// Màn xem toàn bộ design system. Chỉ có ở bản dev (route `/dev/gallery`).
///
/// Dữ liệu trên màn này là ví dụ để xem giao diện, không phải dữ liệu thật.
class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  int _navIndex = 0;
  String _chip = 'all';
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SoAppBar(
        title: context.l10n.devGalleryTitle,
        subtitle: 'lib/core/design',
      ),
      bottomNavigationBar: SoBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: [
          SoNavItem(
            icon: LucideIcons.layoutDashboard,
            label: context.l10n.navDashboard,
          ),
          SoNavItem(
            icon: LucideIcons.receiptText,
            label: context.l10n.navOrders,
          ),
          SoNavItem(icon: LucideIcons.box, label: context.l10n.navProducts),
          SoNavItem(
            icon: LucideIcons.warehouse,
            label: context.l10n.navInventory,
          ),
          SoNavItem(icon: LucideIcons.ellipsis, label: context.l10n.navMore),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: SoSpace.s40),
        children: [
          const SoMockBanner(message: 'Mọi số liệu ở màn này là ví dụ.'),
          _Section(title: 'Logo', child: _logos()),
          _Section(title: 'Màu', child: _swatches(context)),
          _Section(title: 'Chữ', child: _typography(context)),
          _Section(title: 'Nút', child: _buttons()),
          _Section(title: 'Ô nhập', child: _fields()),
          _Section(title: 'Chip & segmented', child: _chips()),
          _Section(title: 'Nhãn', child: _tags()),
          _Section(title: 'Ô chỉ số', child: _stats()),
          _Section(title: 'Tồn kho', child: _stock()),
          _Section(title: 'Hàng đơn', padded: false, child: _orders()),
          _Section(title: 'Danh sách', child: _listRows()),
          _Section(title: 'Banner', child: _banners()),
          _Section(title: 'Toast & sheet', child: _overlays(context)),
          _Section(title: 'Rỗng & lỗi', padded: false, child: _empty()),
          const _Section(
            title: 'Skeleton',
            padded: false,
            child: SoSkeletonList(count: 2),
          ),
          _Section(title: 'Tiến trình', child: _timeline()),
        ],
      ),
    );
  }

  Widget _logos() => const Wrap(
    spacing: SoSpace.s24,
    runSpacing: SoSpace.s16,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [SoLogo(), SoLogo.mark(height: 40)],
  );

  Widget _swatches(BuildContext context) {
    final c = context.soColors;
    final swatches = <(String, Color)>[
      ('ground', c.ground),
      ('surface', c.surface),
      ('surfaceSunken', c.surfaceSunken),
      ('line', c.line),
      ('lineControl', c.lineControl),
      ('ink', c.ink),
      ('ink2', c.ink2),
      ('muted', c.muted),
      ('brand', c.brand),
      ('brandPress', c.brandPress),
      ('brandTint', c.brandTint),
      ('kraft', c.kraft),
      ('kraftTint', c.kraftTint),
      ('kraftInk', c.kraftInk),
      ('success', c.success),
      ('successTint', c.successTint),
      ('warning', c.warning),
      ('warningTint', c.warningTint),
      ('danger', c.danger),
      ('dangerTint', c.dangerTint),
      ('shopee', c.shopee),
      ('tiktok', c.tiktok),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = SoSpace.s8;
        final columns = constraints.maxWidth >= 400 ? 4 : 3;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: SoSpace.s12,
          children: [
            for (final (name, color) in swatches)
              SizedBox(
                width: width,
                child: _Swatch(name: name, color: color),
              ),
          ],
        );
      },
    );
  }

  Widget _typography(BuildContext context) {
    final t = context.textTheme;
    final so = context.soText;
    final rows = <(String, TextStyle?, String)>[
      ('display 32', t.headlineMedium, '3,87 tr'),
      ('title-lg 24', t.titleLarge, 'Việc hôm nay'),
      ('title-md 18', t.titleMedium, 'Chi tiết đơn'),
      ('body-lg 16', t.bodyLarge, 'Một tài khoản cho mọi vai trò.'),
      ('body 15', t.bodyMedium, 'Nhập số đếm được trong kho.'),
      ('body-strong 15', so.bodyStrong, 'Áo thun cổ tròn'),
      ('label 13', t.labelLarge, 'Mật khẩu'),
      ('caption 12', t.bodySmall, 'Cập nhật 09:41'),
      ('code 13', so.code, 'SKU-AT-001-M'),
      ('numeral 15', so.numeral, '318.000 ₫'),
      ('overline 11', so.overline, 'ĐƠN CẦN XỬ LÝ'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, style, sample) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: SoSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: so.overline),
                Text(sample, style: style),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buttons() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SoButton(label: 'Chuẩn bị hàng', onPressed: () {}, expand: true),
      const SizedBox(height: SoSpace.s12),
      Wrap(
        spacing: SoSpace.s8,
        runSpacing: SoSpace.s8,
        children: [
          SoButton.secondary(label: 'Hoàn/trả', onPressed: () {}),
          SoButton.ghost(label: 'Xem tất cả', onPressed: () {}),
          SoButton.danger(label: 'Đăng xuất', onPressed: () {}),
          const SoButton(label: 'Vô hiệu', onPressed: null),
          const SoButton(label: 'Đang lưu', onPressed: null, loading: true),
        ],
      ),
      const SizedBox(height: SoSpace.s12),
      Wrap(
        spacing: SoSpace.s8,
        runSpacing: SoSpace.s8,
        children: [
          SoButton(
            label: 'Nút nhỏ',
            size: SoButtonSize.small,
            icon: LucideIcons.plus,
            onPressed: () {},
          ),
          SoButton.secondary(
            label: 'Nút nhỏ',
            size: SoButtonSize.small,
            onPressed: () {},
          ),
        ],
      ),
    ],
  );

  Widget _fields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SoTextField(label: 'Email', hint: 'ten@cuahang.vn'),
      const SizedBox(height: SoSpace.s16),
      SoTextField(
        label: 'Mật khẩu',
        obscureText: true,
        errorText: 'Email hoặc mật khẩu không đúng.',
        suffix: IconButton(icon: const Icon(LucideIcons.eye), onPressed: () {}),
      ),
      const SizedBox(height: SoSpace.s16),
      const SoTextField(
        label: 'Mã đặt lại',
        mono: true,
        hint: '000000',
        helper: 'Mã gồm 6 chữ số trong email.',
      ),
      const SizedBox(height: SoSpace.s16),
      const SoTextField(label: 'Không sửa được', enabled: false),
    ],
  );

  Widget _chips() {
    final chips = [
      ('all', 'Tất cả', 24),
      ('pending', 'Chờ xử lý', 5),
      ('toShip', 'Chờ giao', 3),
      ('returned', 'Trả hàng', 1),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (id, label, count) in chips)
                Padding(
                  padding: const EdgeInsets.only(right: SoSpace.s8),
                  child: SoFilterChip(
                    label: label,
                    count: count,
                    selected: _chip == id,
                    onSelected: () => setState(() => _chip = id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: SoSpace.s16),
        SoSegmented<bool>(
          selected: _hidden,
          onChanged: (v) => setState(() => _hidden = v),
          segments: const [
            SoSegment(value: false, label: 'Đang bán · 12'),
            SoSegment(value: true, label: 'Đã ẩn · 2'),
          ],
        ),
      ],
    );
  }

  Widget _tags() => Wrap(
    spacing: SoSpace.s8,
    runSpacing: SoSpace.s8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const SoStatusTag(label: 'Chờ xử lý', status: SoStatus.warning),
      const SoStatusTag(label: 'Chờ giao', status: SoStatus.kraft),
      const SoStatusTag(label: 'Đang giao', status: SoStatus.info),
      const SoStatusTag(label: 'Hoàn tất', status: SoStatus.success),
      const SoStatusTag(label: 'Đã hủy', status: SoStatus.neutral),
      const SoStatusTag(label: 'Trả hàng', status: SoStatus.danger),
      for (final tier in LoyaltyTier.values) SoTierBadge(tier: tier),
      const SoTierBadge(tier: LoyaltyTier.diamond, large: true),
      const SoChannelTag(platform: Platform.shopee),
      const SoChannelTag(platform: Platform.tiktokShop),
      const SoCodeTag('250914ABCD12'),
      const SoAiLabel(),
    ],
  );

  Widget _stats() => const Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SoStatTile(label: 'Đơn hôm nay', value: '24'),
          ),
          SizedBox(width: SoSpace.cardGap),
          Expanded(
            child: SoStatTile(
              label: 'Chờ xử lý',
              value: '5',
              note: '2 đơn quá 4 giờ',
              attention: true,
            ),
          ),
        ],
      ),
      SizedBox(height: SoSpace.cardGap),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SoStatTile(
              label: 'Doanh thu hôm nay',
              value: '3,87 tr',
              note: 'Đơn hoàn tất',
            ),
          ),
          SizedBox(width: SoSpace.cardGap),
          Expanded(
            child: SoStatTile(label: 'SKU sắp hết', value: '3'),
          ),
        ],
      ),
    ],
  );

  Widget _stock() => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SoStockMeter(onHand: 120, reserved: 32),
      SizedBox(height: SoSpace.s16),
      SoStockMeter.mini(onHand: 8, reserved: 5),
    ],
  );

  Widget _orders() => Column(
    children: [
      SoOrderRow(
        platform: Platform.shopee,
        orderCode: '250914ABCD12',
        amount: 318000,
        productSummary: 'Áo thun cổ tròn cotton · Trắng / M và 1 sản phẩm khác',
        statusLabel: 'Chờ xử lý',
        status: SoStatus.warning,
        meta: 'Khách mẫu A · 09:41',
        onTap: () {},
      ),
      const Divider(),
      SoOrderRow(
        platform: Platform.tiktokShop,
        orderCode: '5781234567890',
        amount: 1250000,
        productSummary: 'Quần jean ống suông',
        statusLabel: 'Chờ giao',
        status: SoStatus.kraft,
        meta: 'Khách mẫu B · 08:15',
        onTap: () {},
      ),
    ],
  );

  Widget _listRows() => SoListGroup(
    children: [
      SoListRow(
        icon: LucideIcons.chartLine,
        title: 'AI dự báo & gợi ý',
        subtitle: 'Dự báo nhu cầu theo SKU',
        onTap: () {},
      ),
      const SoListRow(
        icon: LucideIcons.users,
        title: 'Quản lý nhân viên',
        comingSoon: true,
      ),
      SoListRow(
        icon: LucideIcons.logOut,
        title: 'Đăng xuất',
        destructive: true,
        trailing: const SizedBox.shrink(),
        onTap: () {},
      ),
    ],
  );

  Widget _banners() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SoBanner(
        tone: SoBannerTone.info,
        title: 'Kiểm tra hộp thư',
        message: 'Nếu email đã đăng ký, mã đặt lại sẽ được gửi tới đó.',
        actionLabel: 'Tôi đã có mã',
        onAction: () {},
      ),
      const SizedBox(height: SoSpace.s12),
      SoBanner(
        tone: SoBannerTone.warning,
        title: 'Tài khoản tạm khóa 15 phút',
        message: 'Bạn đã nhập sai mật khẩu nhiều lần.',
        actionLabel: 'Đặt lại mật khẩu',
        onAction: () {},
      ),
      const SizedBox(height: SoSpace.s12),
      const SoBanner(
        tone: SoBannerTone.danger,
        title: 'Cửa hàng đang bị khóa',
        message: 'Liên hệ quản trị SmartOmni để mở lại.',
      ),
    ],
  );

  Widget _overlays(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SoToast(
        message: 'Đã lưu số tồn',
        actionLabel: 'Hoàn tác',
        onAction: () {},
      ),
      const SizedBox(height: SoSpace.s12),
      Wrap(
        spacing: SoSpace.s8,
        runSpacing: SoSpace.s8,
        children: [
          SoButton.secondary(
            label: 'Hiện toast',
            onPressed: () => showSoToast(
              context,
              'Đã chuyển sang Chờ giao',
              actionLabel: 'Xem',
              onAction: () {},
            ),
          ),
          SoButton.secondary(
            key: const Key('gallery_open_sheet'),
            label: 'Mở bottom sheet',
            onPressed: () => _openSheet(context),
          ),
        ],
      ),
    ],
  );

  Future<void> _openSheet(BuildContext context) {
    return showSoBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SoBottomSheet(
        title: 'Đặt lại số tồn',
        secondary: SoButton.secondary(
          label: context.l10n.cancel,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
        primary: SoButton(
          label: 'Lưu số tồn',
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [SoCodeTag('SKU-AT-001-M')]),
            SizedBox(height: SoSpace.s16),
            SoStockMeter(onHand: 8, reserved: 5),
            SizedBox(height: SoSpace.s16),
            SoTextField(
              label: 'Số tồn đếm được',
              mono: true,
              hint: '0',
              helper: 'Nhập số đếm được trong kho, không phải số cộng thêm.',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SoEmptyState(
        title: 'Chưa có đơn nào',
        message: 'Đơn mới từ Shopee và TikTok Shop sẽ hiện ở đây.',
        actionLabel: 'Làm mới',
        onAction: () {},
      ),
      const Divider(),
      SoEmptyState.error(
        title: 'Không tải được đơn hàng',
        message: 'Kiểm tra kết nối mạng rồi thử lại.',
        onAction: () {},
      ),
    ],
  );

  Widget _timeline() => const SoTimeline(
    steps: [
      SoTimelineStep(
        title: 'Chờ xử lý',
        subtitle: '09:41',
        state: SoStepState.done,
      ),
      SoTimelineStep(
        title: 'Chờ giao',
        subtitle: 'Đang chuẩn bị hàng',
        state: SoStepState.current,
      ),
      SoTimelineStep(
        title: 'Đang giao',
        subtitle: 'Sàn tự cập nhật',
        state: SoStepState.upcoming,
      ),
      SoTimelineStep(
        title: 'Hoàn tất',
        subtitle: 'Sàn tự cập nhật',
        state: SoStepState.upcoming,
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.padded = true,
  });

  final String title;
  final Widget child;

  /// `false`: nội dung tràn hết bề ngang (danh sách).
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SoSpace.group),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SoSpace.screen),
            child: Text(title.toUpperCase(), style: context.soText.overline),
          ),
          const SizedBox(height: SoSpace.s8),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: padded ? SoSpace.screen : 0,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final hex = color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: SoRadius.xsAll,
            border: Border.all(color: c.line),
          ),
        ),
        const SizedBox(height: SoSpace.s4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall,
        ),
        Text('#$hex', style: context.textTheme.bodySmall),
      ],
    );
  }
}
