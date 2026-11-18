# Changelog

Ghi theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/), phiên bản theo [SemVer](https://semver.org/lang/vi/).

## [Unreleased]

## [0.2.0] - 2026-11-18

Bản demo (pre-release), không đưa lên Google Play. Nối app với BE [Smart-Omni/SmartOmni_BE](https://github.com/Smart-Omni/SmartOmni_BE) nhánh `develop`; **đã test với BE `develop` commit `9558375`**. Khi `USE_MOCK=false`, chức năng đã nối gọi API thật, chức năng chưa nối tự dùng dữ liệu mẫu và hiện dải "Dữ liệu mẫu" (bật/tắt ở `lib/app/config/api_availability.dart`; danh sách ở `docs/API_CONTRACT.md` mục 0).

### Nối API BE
- Mọi API chuyển sang `/api/v1/...`, đường dẫn gom về `lib/core/network/api_paths.dart`; đọc phản hồi snake_case và phân trang `PageResponse`.
- Phiên đăng nhập: tự gia hạn bằng refresh token (trước khi hết hạn và khi gặp 401, chỉ gia hạn một lần; mất mạng thì giữ phiên). Phiên bị thu hồi (401 `TOKEN_REVOKED`) thì đăng xuất và báo rõ lý do. Nhân viên chưa thuộc cửa hàng nào (`STAFF_NO_TENANT`) không vào được app.
- Tài khoản: A-05 đăng ký gọi API thật (bỏ OTP khi dùng BE thật, báo "Không tìm thấy cửa hàng" khi sai mã); M-50/C-40 hiện hồ sơ và cửa hàng thật; C-40 đổi mật khẩu; mật khẩu mới 6–100 ký tự.
- Đơn hàng M-20/M-21 và hoàn/trả gọi API thật; M-21 hiện sản phẩm của đơn; thêm trạng thái "Tạm giữ" (`ON_HOLD`). App chỉ cho chuyển `PENDING → TO_SHIP`.
- Sản phẩm M-30/31/32 (lấy SKU cả danh sách trong 1 request), tồn kho M-40 (`InventoryItemDto`, SKU tồn 0 vẫn đặt tồn được) gọi API thật.
- M-51 Dự báo AI gọi API thật (`from=<hôm nay>&days=14`, hiện tối đa 7 ngày); chỉ có ở gói Pro.
- T-20 Nhân viên gọi API thật: danh sách, thêm (ô Họ tên bắt buộc, role `STAFF` thay `MANAGER`), khóa / mở khóa.

### Kết nối sàn OAuth
- T-10 kết nối Shopee / TikTok Shop qua OAuth: sheet "Kết nối <sàn>" 3 bước, mở trang ủy quyền của sàn, quay về app qua `smartomni://oauth/<sàn>` (`app_links`), gửi kết quả cho BE và hiện thẻ "Đã kết nối …". Chạy được cả khi app bị tắt lúc đang ở trình duyệt; lỗi báo tiếng Việt; Staff không thấy nút Kết nối / Ngắt kết nối.
- Trạng thái, ngắt kết nối và công tắc tự nhập Shopee gọi API thật (TikTok tự nhập còn mẫu).
- Bỏ form "Kết nối bằng App Key" vì BE chỉ cho OAuth; chế độ mock chạy OAuth giả.

### Sửa lỗi
- Đơn `ON_HOLD` bị hiện là "Chờ xử lý" và có nút "Chuẩn bị hàng".
- "Thử lại" ở M-40 và M-51 không còn kẹt lỗi khi danh sách sản phẩm lỗi thoáng qua.
- M-32: lỗi vượt giới hạn SKU của gói hiện ở banner form thay vì dưới ô Mã SKU.
- Hộp thư (còn mock) không gửi id đơn mẫu lên BE khi đơn hàng đã nối BE.
- Test claim điểm tự hỏng theo ngày do dữ liệu mẫu lấy giờ thật.
- CI ghim Flutter 3.44.3 cho mọi workflow (Flutter 3.47+ làm `flutter analyze` đỏ; xem `docs/CICD.md`).

### Tài liệu
- `docs/API_CONTRACT.md` mục 0: đối chiếu với BE `9558375` (trước đó `3eb89ec`, `4cae7a2`, `fda1ab2`), danh sách đã nối / chưa nối kèm nguyên nhân.
- Mô tả OAuth T-10 và cách test (`docs/API_CONTRACT.md`, `docs/USER_FLOWS.md`); `docs/DESIGN.md` bỏ sheet App Key.
- Link repo trỏ về Smart-Omni/SmartOmni_Mobile và Smart-Omni/SmartOmni_BE.

## [0.1.0] - 2026-10-22

Bản đầu tiên: đủ giao diện 29 màn (bản 2 Glass, `docs/DESIGN.md`). Chức năng backend chưa có API chạy bằng dữ liệu mẫu và hiện dải "Dữ liệu mẫu"; danh sách API đang chờ ở `docs/API_CONTRACT.md` mục 4.

Bản demo: chạy dữ liệu mẫu, đăng nhập bằng tài khoản demo (xem docs/CICD.md).

### Chung
- A-01 Splash, A-02 Đăng nhập (4 trạng thái lỗi), A-03 Quên mật khẩu, A-04 Đặt lại mật khẩu: API thật.
- Điều hướng theo role (Customer / Staff / Tenant Admin), chặn route ở `resolveRedirect()`.
- Design system `lib/core/design/` (widget `So…`, token màu, chữ Inter + JetBrains Mono, kính, nền loang) và màn gallery cho bản dev.

### Customer
- A-05 Đăng ký tài khoản khách + OTP email (mock).
- C-00 Chọn / thêm cửa hàng: một tài khoản dùng nhiều cửa hàng (mock).
- C-10 Sản phẩm, C-11 Chi tiết sản phẩm + nút mua trên sàn (mock).
- C-12 Trợ lý tư vấn sản phẩm (mock).
- C-20 Điểm & hạng, voucher, lịch sử điểm (mock).
- C-30 Claim đơn + màn kết quả và các ca lỗi (mock).
- C-40 Tài khoản.

### Merchant (Staff + Tenant Admin)
- M-10 Tổng quan: bản Staff "Việc hôm nay" và bản Admin có doanh thu (mock; đơn cần xử lý lấy API thật).
- M-20 Danh sách đơn, M-21 Chi tiết đơn (Chuẩn bị hàng, ghi nhận hoàn/trả): API thật.
- M-22 In vận đơn: xem trước, chia sẻ PDF, in (tem mẫu).
- M-30 Sản phẩm (danh sách mock), M-31 Chi tiết sản phẩm, M-32 Tạo sản phẩm: API thật.
- M-40 Tồn kho (danh sách mock) + đặt lại số tồn: API thật.
- M-50 Thêm, M-51 Dự báo nhu cầu (AI): API thật.
- M-60 Hộp thư CSKH, M-61 Hội thoại (mock).

### Chỉ Tenant Admin
- T-10 Kết nối sàn: kết nối bằng App Key gọi API thật; danh sách, ngắt kết nối, tự nhập chạy mock. OAuth để sau.
- T-20 Quản lý nhân viên (mock).
- T-30 Phát voucher (mock).
- T-40 Gói dịch vụ (mock, không thanh toán trong app).
- T-50 Yêu cầu hỗ trợ (mock).

### Sửa lỗi
- Màn tải lỗi hiện lỗi + "Thử lại" ngay, không còn skeleton ~38 giây do Riverpod tự thử lại.

[Unreleased]: https://github.com/Smart-Omni/SmartOmni_Mobile/compare/v0.2.0...develop
[0.2.0]: https://github.com/Smart-Omni/SmartOmni_Mobile/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Smart-Omni/SmartOmni_Mobile/releases/tag/v0.1.0
