/// Vai trò người dùng trong app mobile.
///
/// Ánh xạ từ giá trị `role` trong JWT / LoginResponse của backend:
///
/// | Backend        | App           | Ghi chú                                   |
/// |----------------|---------------|-------------------------------------------|
/// | `ADMIN`        | tenantAdmin   | Chủ cửa hàng (Tenant Admin)               |
/// | `MANAGER`      | staff         | Tên cũ trong code BE, nghiệp vụ gọi Staff |
/// | `STAFF`        | staff         | Dự phòng nếu BE đổi tên enum              |
/// | `CUSTOMER`     | customer      | BE chưa có, hiện chỉ có ở mock            |
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
