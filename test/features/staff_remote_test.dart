import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/core/network/api_exception.dart';
import 'package:smartomni_mobile/core/network/api_paths.dart';
import 'package:smartomni_mobile/features/staff/data/staff_remote_repository.dart';
import 'package:smartomni_mobile/features/staff/domain/staff.dart';
import 'package:smartomni_mobile/features/staff/presentation/staff_providers.dart';

import '../helpers/fake_backend.dart';
import '../helpers/test_app.dart';

/// `UserProfileResponse` như BE gửi (snake_case).
Map<String, Object?> _user(
  int id,
  String role, {
  String? name,
  String status = 'ACTIVE',
}) => {
  'id': id,
  'email': 'u$id@shop.vn',
  'full_name': name,
  'role': role,
  'status': status,
  'tenant_id': 3,
};

/// `PageResponse` snake_case của `/api/v1/users`.
Map<String, Object?> _page(List<Object?> content) => ok({
  'content': content,
  'total_elements': content.length,
  'total_pages': 1,
  'page_number': 0,
  'page_size': 100,
  'first': true,
  'last': true,
  'has_next': false,
  'has_previous': false,
});

final _users = [
  _user(1, 'TENANT_ADMIN', name: 'Chủ Shop'),
  _user(2, 'MANAGER', name: 'Lê Bình'),
  _user(4, 'MANAGER', name: 'Đỗ Dũng', status: 'DISABLED'),
  _user(9, 'CUSTOMER', name: 'Khách lạc vào'),
];

void main() {
  group('StaffRemoteRepository', () {
    test('đọc PageResponse: chủ cửa hàng, DISABLED = đã khóa, bỏ role '
        'không phải nhân viên', () async {
      final backend = FakeBackend((o) async => (200, _page(_users)));
      final members = await StaffRemoteRepository(fakeDio(backend)).list();

      final req = backend.requests.single;
      expect(req.path, ApiPaths.users);
      expect(req.queryParameters['page'], 0);
      expect([for (final m in members) m.id], [1, 2, 4]);
      expect(members[0].isOwner, isTrue);
      expect(members[0].name, 'Chủ Shop');
      expect(members[1].isOwner, isFalse);
      expect(members[1].active, isTrue);
      expect(members[2].active, isFalse);
    });

    test('thêm nhân viên gửi CreateUserRequest với role MANAGER', () async {
      final backend = FakeBackend(
        (o) async => (200, ok(_user(7, 'MANAGER', name: 'Nguyễn Mới'))),
      );
      final added = await StaffRemoteRepository(fakeDio(backend)).add(
        name: ' Nguyễn Mới ',
        email: ' moi@shop.vn ',
        password: 'tam123456',
      );

      final req = backend.requests.single;
      expect(req.method, 'POST');
      expect(req.path, ApiPaths.users);
      expect(req.data, {
        'email': 'moi@shop.vn',
        'password': 'tam123456',
        'full_name': 'Nguyễn Mới',
        'role': 'MANAGER',
      });
      expect(added.id, 7);
      expect(added.name, 'Nguyễn Mới');
    });

    test('409 EMAIL_EXISTS → email trùng; lỗi khác giữ message BE', () async {
      var status = 409;
      final repo = StaffRemoteRepository(
        fakeDio(
          FakeBackend(
            (o) async => (
              status,
              apiError(
                status == 409
                    ? 'Email đã tồn tại trong tenant'
                    : 'Họ và tên không được để trống',
              ),
            ),
          ),
        ),
      );
      Future<StaffMember> add() =>
          repo.add(name: 'A', email: 'a@shop.vn', password: '123456');

      await expectLater(add(), throwsA(isA<DuplicateStaffEmailException>()));
      status = 400;
      await expectLater(
        add(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Họ và tên không được để trống',
          ),
        ),
      );
    });

    test(
      'khóa / mở khóa gửi PATCH status; không gửi khi là chủ cửa hàng',
      () async {
        final backend = FakeBackend((o) async {
          if (o.method == 'GET') return (200, _page(_users));
          final status = (o.data as Map)['status'] as String;
          return (200, ok(_user(2, 'MANAGER', status: status)));
        });
        final repo = StaffRemoteRepository(fakeDio(backend));
        await repo.list();

        final locked = await repo.setActive(2, active: false);
        final patch = backend.requests.last;
        expect(patch.method, 'PATCH');
        expect(patch.path, ApiPaths.userStatus(2));
        expect(patch.data, {'status': 'DISABLED'});
        expect(locked.active, isFalse);

        await repo.setActive(2, active: true);
        expect(backend.requests.last.data, {'status': 'ACTIVE'});

        final before = backend.requests.length;
        await expectLater(repo.setActive(1, active: false), throwsStateError);
        expect(backend.requests.length, before);
      },
    );
  });

  testWidgets('T-20 BE thật: không có banner mẫu, danh sách từ API, thêm '
      'nhân viên có họ tên', (tester) async {
    final users = [..._users];
    final backend = FakeBackend((o) async {
      if (o.method == 'POST') {
        final body = o.data as Map;
        final created = _user(7, 'MANAGER', name: body['full_name'] as String)
          ..['email'] = body['email'];
        users.add(created);
        return (200, ok(created));
      }
      return (200, _page(users));
    });
    await loginAs(
      tester,
      'admin@demo.vn',
      tallView: true,
      overrides: [
        staffUseRemoteProvider.overrideWithValue(true),
        staffRepositoryProvider.overrideWithValue(
          StaffRemoteRepository(fakeDio(backend)),
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('nav_more')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('menu_staff')));

    expect(find.byType(SoMockBanner), findsNothing);
    expect(find.text('Chủ Shop'), findsOneWidget);
    expect(find.text('Khách lạc vào'), findsNothing);
    expect(find.text('Nhân viên · 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('staff_add')));
    await tester.pumpAndSettle();
    // Họ tên tối đa 100 ký tự.
    await tester.enterText(find.byKey(const Key('staff_name')), 'a' * 120);
    expect(find.text('a' * 100), findsOneWidget);
    await tester.enterText(find.byKey(const Key('staff_name')), 'Nguyễn Mới');
    await tester.enterText(find.byKey(const Key('staff_email')), 'moi@shop.vn');
    await tester.enterText(
      find.byKey(const Key('staff_password')),
      'tam123456',
    );
    await tester.tap(find.byKey(const Key('staff_add_submit')));
    await tester.pumpAndSettle();

    expect(find.byType(SoBottomSheet), findsNothing);
    expect(find.text('Nguyễn Mới'), findsOneWidget);
    expect(find.text('Nhân viên · 3'), findsOneWidget);
  });
}
