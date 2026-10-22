import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/design/design.dart';
import '../../../core/utils/validators.dart';
import '../../account/presentation/account_widgets.dart';
import '../domain/staff.dart';
import 'staff_providers.dart';

/// T-20 Quản lý nhân viên (chỉ Tenant Admin, chặn ở `resolveRedirect`).
///
/// Chủ cửa hàng ("Bạn") đứng đầu, không bấm được. Chạm một nhân viên để khóa
/// / mở khóa qua sheet xác nhận. Thanh dưới: Thêm nhân viên (email + mật
/// khẩu tạm). Chưa có phân quyền con (USER_FLOWS F-T3).
class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  /// Đang gửi khóa / mở khóa: chặn chạm thêm cho tới khi xong.
  bool _busy = false;

  Future<void> _toggle(StaffMember m) async {
    if (_busy) return;
    final lock = m.active;
    final ok = await showSoBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SoBottomSheet(
        title: lock
            ? 'Khóa tài khoản ${m.displayName}?'
            : 'Mở khóa ${m.displayName}?',
        secondary: SoButton.secondary(
          key: const Key('staff_toggle_cancel'),
          label: 'Hủy',
          onPressed: () => Navigator.pop(sheetContext, false),
        ),
        primary: lock
            ? SoButton.danger(
                key: const Key('staff_toggle_confirm'),
                label: 'Khóa tài khoản',
                onPressed: () => Navigator.pop(sheetContext, true),
              )
            : SoButton(
                key: const Key('staff_toggle_confirm'),
                label: 'Mở khóa',
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
        child: Text(
          lock
              ? '${m.email} sẽ không đăng nhập được vào SmartOmni. Đơn và '
                    'tin nhắn đã xử lý vẫn giữ nguyên.'
              : '${m.email} đăng nhập lại được bằng mật khẩu cũ.',
          style: sheetContext.textTheme.bodyMedium,
        ),
      ),
    );
    if (!(ok ?? false) || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(staffRepositoryProvider).setActive(m.id, active: !lock);
      ref.invalidate(staffListProvider);
      if (mounted) {
        showSoToast(
          context,
          lock ? 'Đã khóa ${m.displayName}' : 'Đã mở khóa ${m.displayName}',
        );
      }
    } catch (_) {
      if (mounted) {
        showSoToast(
          context,
          lock
              ? 'Chưa khóa được. Kiểm tra kết nối mạng rồi thử lại.'
              : 'Chưa mở khóa được. Kiểm tra kết nối mạng rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final added = await showSoBottomSheet<StaffMember>(
      context: context,
      builder: (_) => const _AddStaffSheet(),
    );
    if (added != null && mounted) {
      showSoToast(context, 'Đã thêm ${added.email}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(staffListProvider);
    final staff = async.value;

    return SoScaffold(
      scrollable: staff != null || async.hasError,
      appBar: const SoAppBar(title: 'Nhân viên'),
      bottomBar: SoActionBar(
        primary: SoButton(
          key: const Key('staff_add'),
          label: 'Thêm nhân viên',
          icon: LucideIcons.userPlus,
          onPressed: staff == null ? null : _add,
        ),
      ),
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: SliverList.list(
            children: [
              const SoMockBanner(
                message: 'Danh sách mẫu, backend chưa có API nhân viên.',
              ),
              const SizedBox(height: SoSpace.s16),
              if (staff != null)
                _Body(members: staff, onTap: _busy ? null : _toggle)
              else if (async.hasError && !async.isLoading)
                SoEmptyState.error(
                  key: const Key('staff_error'),
                  title: 'Không tải được danh sách nhân viên',
                  message: 'Kiểm tra kết nối mạng rồi thử lại.',
                  onAction: () => ref.invalidate(staffListProvider),
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

class _Body extends StatelessWidget {
  const _Body({required this.members, required this.onTap});

  final List<StaffMember> members;
  final ValueChanged<StaffMember>? onTap;

  @override
  Widget build(BuildContext context) {
    final owners = members.where((m) => m.isOwner);
    final staff = members.where(canToggleStaff).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoListGroup(children: [for (final m in owners) _StaffRow(member: m)]),
        GroupTitle('Nhân viên · ${staff.length}'),
        if (staff.isEmpty)
          Text(
            key: const Key('staff_empty'),
            'Chưa có nhân viên. Bấm Thêm nhân viên để mời người cùng xử lý '
            'đơn.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.soColors.ink2,
            ),
          )
        else
          SoListGroup(
            children: [
              for (final m in staff)
                _StaffRow(
                  member: m,
                  onTap: onTap == null ? null : () => onTap!(m),
                ),
            ],
          ),
      ],
    );
  }
}

/// Tên (hoặc email nếu chưa có tên) + email + nhãn trạng thái. Hàng chủ cửa
/// hàng: nhãn "Bạn", không mũi tên, không bấm được.
class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.member, this.onTap});

  final StaffMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = member;
    final c = context.soColors;
    final tag = m.isOwner
        ? const SoStatusTag(label: 'Bạn', status: SoStatus.brand)
        : m.active
        ? const SoStatusTag(label: 'Đang hoạt động', status: SoStatus.success)
        : const SoStatusTag(label: 'Đã khóa', status: SoStatus.neutral);
    return SoListRow(
      key: Key('staff_${m.id}'),
      title: m.displayName,
      subtitle: m.name == null ? null : m.email,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tag,
          if (canToggleStaff(m)) ...[
            const SizedBox(width: SoSpace.s8),
            Icon(
              LucideIcons.chevronRight,
              size: SoSize.iconSmall,
              color: c.muted,
            ),
          ],
        ],
      ),
    );
  }
}

/// Sheet "Thêm nhân viên": email + mật khẩu tạm (≥ 8 ký tự).
class _AddStaffSheet extends ConsumerStatefulWidget {
  const _AddStaffSheet();

  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _emailError;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _emailError = null;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final added = await ref
          .read(staffRepositoryProvider)
          .add(email: _email.text.trim(), password: _password.text);
      ref.invalidate(staffListProvider);
      if (mounted) Navigator.pop(context, added);
    } on DuplicateStaffEmailException {
      if (mounted) {
        setState(() => _emailError = 'Email này đã có trong cửa hàng');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Kiểm tra kết nối mạng rồi thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SoBottomSheet(
        title: 'Thêm nhân viên',
        secondary: SoButton.secondary(
          key: const Key('staff_add_cancel'),
          label: 'Hủy',
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        primary: SoButton(
          key: const Key('staff_add_submit'),
          label: 'Thêm nhân viên',
          loading: _busy,
          onPressed: _submit,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              SoBanner(
                key: const Key('staff_add_error'),
                tone: SoBannerTone.danger,
                title: 'Chưa thêm được nhân viên',
                message: _error,
              ),
              const SizedBox(height: SoSpace.s16),
            ],
            SoTextField(
              key: const Key('staff_email'),
              label: 'Email',
              controller: _email,
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
            ),
            const SizedBox(height: SoSpace.s16),
            SoTextField(
              key: const Key('staff_password'),
              label: 'Mật khẩu tạm',
              helper: 'Ít nhất 8 ký tự',
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: Validators.newPassword,
              suffix: IconButton(
                key: const Key('staff_password_toggle'),
                tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                icon: Icon(
                  _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                  color: context.soColors.ink2,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: SoSpace.s16),
            const SoBanner(
              tone: SoBannerTone.info,
              title: 'Gửi thông tin đăng nhập',
              message:
                  'Gửi email và mật khẩu tạm cho nhân viên để họ đăng nhập.',
            ),
          ],
        ),
      ),
    );
  }
}
