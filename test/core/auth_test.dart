import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/auth/jwt_decoder.dart';
import 'package:smartomni_mobile/core/auth/session.dart';
import 'package:smartomni_mobile/core/auth/user_role.dart';

void main() {
  group('UserRole.fromBackend', () {
    test('ánh xạ đúng role backend sang role app', () {
      expect(UserRole.fromBackend('ADMIN'), UserRole.tenantAdmin);
      expect(UserRole.fromBackend('MANAGER'), UserRole.staff);
      expect(UserRole.fromBackend('STAFF'), UserRole.staff);
      expect(UserRole.fromBackend('CUSTOMER'), UserRole.customer);
      expect(UserRole.fromBackend('SUPER_ADMIN'), UserRole.superAdmin);
      expect(UserRole.fromBackend('xyz'), UserRole.unknown);
      expect(UserRole.fromBackend(null), UserRole.unknown);
    });

    test('Super Admin không dùng được trên mobile', () {
      expect(UserRole.superAdmin.isSupportedOnMobile, isFalse);
      expect(UserRole.unknown.isSupportedOnMobile, isFalse);
      expect(UserRole.staff.isMerchant, isTrue);
      expect(UserRole.tenantAdmin.isMerchant, isTrue);
      expect(UserRole.customer.isCustomer, isTrue);
    });
  });

  group('JwtDecoder', () {
    test('đọc payload và hạn dùng của token', () {
      final exp = DateTime(2030, 1, 1);
      final token = JwtDecoder.buildUnsigned({
        'sub': '7',
        'role': 'ADMIN',
        'tenantId': 3,
        'exp': exp.millisecondsSinceEpoch ~/ 1000,
      });

      expect(JwtDecoder.decodePayload(token)?['role'], 'ADMIN');
      expect(JwtDecoder.expiry(token), exp);
      expect(JwtDecoder.isExpired(token, now: DateTime(2029)), isFalse);
      expect(JwtDecoder.isExpired(token, now: DateTime(2031)), isTrue);
    });

    test('token sai định dạng trả về null', () {
      expect(JwtDecoder.decodePayload('abc'), isNull);
      expect(JwtDecoder.decodePayload('a.###.c'), isNull);
      expect(JwtDecoder.isExpired('abc'), isTrue);
    });
  });

  group('Session.fromToken', () {
    test('dựng phiên từ JWT của backend', () {
      final token = JwtDecoder.buildUnsigned({
        'sub': '12',
        'role': 'MANAGER',
        'tenantId': 5,
        'exp': 1893456000,
      });
      final session = Session.fromToken(token)!;
      expect(session.userId, 12);
      expect(session.role, UserRole.staff);
      expect(session.tenantId, 5);
    });

    test('Super Admin không có tenantId', () {
      final token = JwtDecoder.buildUnsigned({
        'sub': '1',
        'role': 'SUPER_ADMIN',
        'exp': 1893456000,
      });
      expect(Session.fromToken(token)!.tenantId, isNull);
    });

    test('thiếu sub -> null', () {
      final token = JwtDecoder.buildUnsigned({'role': 'ADMIN'});
      expect(Session.fromToken(token), isNull);
    });
  });
}
