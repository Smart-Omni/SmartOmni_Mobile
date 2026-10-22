import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/utils/mock_delay.dart';
import 'package:smartomni_mobile/features/staff/data/staff_mock_repository.dart';
import 'package:smartomni_mobile/features/staff/domain/staff.dart';
import 'package:smartomni_mobile/features/staff/presentation/staff_providers.dart';
import 'package:smartomni_mobile/features/staff/presentation/staff_screen.dart';

import '../helpers/test_app.dart';

/// Lần gọi `list()` đầu lỗi, lần sau trả [members].
class _FlakyStaff implements StaffRepository {
  _FlakyStaff(this.members);

  final List<StaffMember> members;
  var calls = 0;

  @override
  Future<List<StaffMember>> list() async {
    calls++;
    if (calls == 1) throw Exception('mất mạng');
    return members;
  }

  @override
  Future<StaffMember> add({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<StaffMember> setActive(int id, {required bool active}) =>
      throw Exception('mất mạng');
}

const _owner = StaffMember(
  id: 1,
  email: 'admin@demo.vn',
  name: 'Chủ',
  isOwner: true,
);

Future<void> _openStaff(WidgetTester tester, {StaffRepository? repo}) async {
  await loginAs(
    tester,
    'admin@demo.vn',
    tallView: true,
    overrides: [
      staffRepositoryProvider.overrideWithValue(repo ?? StaffMockRepository()),
    ],
  );
  await tester.tap(find.byKey(const Key('nav_more')));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const Key('menu_staff')));
}

String _tag(WidgetTester tester, int id) => tester
    .widget<SoStatusTag>(
      find.descendant(
        of: find.byKey(Key('staff_$id')),
        matching: find.byType(SoStatusTag),
      ),
    )
    .label;

Future<void> _addStaff(
  WidgetTester tester,
  String email,
  String password,
) async {
  await tester.enterText(find.byKey(const Key('staff_email')), email);
  await tester.enterText(find.byKey(const Key('staff_password')), password);
  await tester.tap(find.byKey(const Key('staff_add_submit')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => MockDelay.enabled = false);

  test('canToggleStaff: chủ cửa hàng không tự khóa được', () {
    expect(canToggleStaff(_owner), isFalse);
    expect(canToggleStaff(const StaffMember(id: 2, email: 'a@b.vn')), isTrue);
  });

  test('sortStaff: chủ → đang hoạt động → đã khóa, theo tên bỏ dấu', () {
    final sorted = sortStaff(const [
      StaffMember(id: 3, email: 'z@b.vn', name: 'Ân', active: false),
      StaffMember(id: 4, email: 'binh@b.vn'),
      StaffMember(id: 5, email: 'x@b.vn', name: 'Ánh'),
      _owner,
    ]);
    expect([for (final m in sorted) m.id], [1, 5, 4, 3]);
  });

  test('mock: email trùng (không phân biệt hoa thường) bị từ chối', () async {
    final repo = StaffMockRepository();
    await expectLater(
      repo.add(email: ' STAFF@demo.vn ', password: '12345678'),
      throwsA(isA<DuplicateStaffEmailException>()),
    );
    final added = await repo.add(email: 'Moi@Demo.vn', password: '12345678');
    expect(added.email, 'moi@demo.vn');
    expect(added.name, isNull);
    expect(added.active, isTrue);
  });

  test('mock: không khóa được chủ cửa hàng', () async {
    final repo = StaffMockRepository();
    await expectLater(repo.setActive(1, active: false), throwsStateError);
  });

  testWidgets('M-50 Staff: không có mục Quản lý nhân viên', (tester) async {
    await loginAs(tester, 'staff@demo.vn', tallView: true);
    await tester.tap(find.byKey(const Key('nav_more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu_staff')), findsNothing);
  });

  testWidgets('T-20: chủ cửa hàng đầu danh sách, nhãn Bạn, không bấm được', (
    tester,
  ) async {
    await _openStaff(tester);

    expect(find.byType(StaffScreen), findsOneWidget);
    expect(find.byType(SoMockBanner), findsOneWidget);
    expect(find.text('Nhân viên · 3'), findsOneWidget);
    expect(_tag(tester, 1), 'Bạn');
    expect(_tag(tester, 2), 'Đang hoạt động');
    expect(_tag(tester, 4), 'Đã khóa');
    // Đã khóa xếp cuối.
    expect(
      tester.getTopLeft(find.byKey(const Key('staff_4'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const Key('staff_6'))).dy),
    );

    await tester.tap(find.byKey(const Key('staff_1')));
    await tester.pumpAndSettle();
    expect(find.byType(SoBottomSheet), findsNothing);
  });

  testWidgets('T-20: khóa rồi mở khóa qua sheet xác nhận', (tester) async {
    await _openStaff(tester);

    await tapVisible(tester, find.byKey(const Key('staff_2')));
    expect(find.text('Khóa tài khoản Lê Văn Bình?'), findsOneWidget);
    expect(
      find.textContaining('staff@demo.vn sẽ không đăng nhập'),
      findsOneWidget,
    );
    // Hủy: không đổi gì.
    await tester.tap(find.byKey(const Key('staff_toggle_cancel')));
    await tester.pumpAndSettle();
    expect(_tag(tester, 2), 'Đang hoạt động');

    await tapVisible(tester, find.byKey(const Key('staff_2')));
    await tester.tap(find.byKey(const Key('staff_toggle_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Đã khóa Lê Văn Bình'), findsOneWidget);
    expect(_tag(tester, 2), 'Đã khóa');

    await tapVisible(tester, find.byKey(const Key('staff_2')));
    expect(find.text('Mở khóa Lê Văn Bình?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('staff_toggle_confirm')));
    await tester.pumpAndSettle();
    expect(_tag(tester, 2), 'Đang hoạt động');
  });

  testWidgets('T-20: khóa lỗi -> toast, giữ trạng thái cũ', (tester) async {
    final repo = _FlakyStaff(const [
      _owner,
      StaffMember(id: 2, email: 'b@demo.vn', name: 'Bình'),
    ])..calls = 1;
    await _openStaff(tester, repo: repo);

    await tapVisible(tester, find.byKey(const Key('staff_2')));
    await tester.tap(find.byKey(const Key('staff_toggle_confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa khóa được. Kiểm tra kết nối mạng rồi thử lại.'),
      findsOneWidget,
    );
    expect(_tag(tester, 2), 'Đang hoạt động');
  });

  testWidgets('T-20: thêm nhân viên — kiểm tra ô, email trùng, thành công', (
    tester,
  ) async {
    await _openStaff(tester);
    await tester.tap(find.byKey(const Key('staff_add')));
    await tester.pumpAndSettle();
    expect(find.text('Thêm nhân viên'), findsWidgets);

    await _addStaff(tester, 'khong-hop-le', '123');
    expect(find.text('Email không hợp lệ'), findsOneWidget);
    expect(find.text('Mật khẩu phải có ít nhất 8 ký tự'), findsOneWidget);

    await _addStaff(tester, 'staff@demo.vn', '12345678');
    expect(find.text('Email này đã có trong cửa hàng'), findsOneWidget);
    // Sửa email thì bỏ lỗi trùng.
    await tester.enterText(find.byKey(const Key('staff_email')), 'moi@');
    await tester.pump();
    expect(find.text('Email này đã có trong cửa hàng'), findsNothing);

    await _addStaff(tester, 'moi@demo.vn', '12345678');
    expect(find.byType(SoBottomSheet), findsNothing);
    expect(find.text('Đã thêm moi@demo.vn'), findsOneWidget);
    expect(find.text('Nhân viên · 4'), findsOneWidget);
    expect(_tag(tester, 7), 'Đang hoạt động');
  });

  testWidgets('T-20: lỗi tải -> Thử lại; chỉ có chủ -> dòng gợi ý', (
    tester,
  ) async {
    final repo = _FlakyStaff(const [_owner]);
    await _openStaff(tester, repo: repo);
    expect(find.byKey(const Key('staff_error')), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('Nhân viên · 0'), findsOneWidget);
    expect(find.byKey(const Key('staff_empty')), findsOneWidget);
  });

  testWidgets('T-20 vừa bề rộng 360dp', (tester) async {
    await _openStaff(tester);
    tester.view.physicalSize = const Size(360, 740);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
