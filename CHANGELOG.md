# Changelog

Ghi theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/), phiên bản theo [SemVer](https://semver.org/lang/vi/).

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

[0.1.0]: https://github.com/tuankiet710/SmartOmni_Mobile/releases/tag/v0.1.0
