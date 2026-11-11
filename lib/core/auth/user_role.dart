/// Vai trò người dùng trong app mobile.
///
/// Ánh xạ từ `role` trong JWT / `user_info.role` (enum `User.UserRole` của BE):
///
/// | Backend        | App           | Ghi chú                                   |
/// |----------------|---------------|-------------------------------------------|
/// | `TENANT_ADMIN` | tenantAdmin   | Chủ cửa hàng (Tenant Admin)               |
/// | `ADMIN`        | tenantAdmin   | Tên cũ, giữ để tương thích                |
/// | `MANAGER`      | staff         | Tên trong code BE, nghiệp vụ gọi Staff    |
/// | `STAFF`        | staff         | Dự phòng nếu BE đổi tên enum              |
/// | `CUSTOMER`     | customer      | Khách đăng ký qua A-05                    |
/// | `SUPER_ADMIN`  | superAdmin    | Không hỗ trợ trên mobile (dùng web)       |
enum UserRole {
  customer,
  staff,
  tenantAdmin,
  superAdmin,
  unknown;

  static UserRole fromBackend(String? value) {
    switch (value?.toUpperCase()) {
      case 'ADMIN':
      case 'TENANT_ADMIN':
        return UserRole.tenantAdmin;
      case 'MANAGER':
      case 'STAFF':
        return UserRole.staff;
      case 'CUSTOMER':
        return UserRole.customer;
      case 'SUPER_ADMIN':
        return UserRole.superAdmin;
      default:
        return UserRole.unknown;
    }
  }

  /// Staff và Tenant Admin dùng chung khu vực Merchant.
  bool get isMerchant => this == UserRole.staff || this == UserRole.tenantAdmin;

  bool get isCustomer => this == UserRole.customer;

  /// Role được phép dùng app mobile.
  bool get isSupportedOnMobile => isMerchant || isCustomer;

  String get label => switch (this) {
    UserRole.customer => 'Khách hàng',
    UserRole.staff => 'Nhân viên',
    UserRole.tenantAdmin => 'Chủ cửa hàng',
    UserRole.superAdmin => 'Super Admin',
    UserRole.unknown => 'Không xác định',
  };
}
