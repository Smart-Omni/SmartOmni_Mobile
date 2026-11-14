# Changelog

Ghi theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/), phiên bản theo [SemVer](https://semver.org/lang/vi/).

## [Unreleased]

Nối app với BE [Smart-Omni/SmartOmni_BE](https://github.com/Smart-Omni/SmartOmni_BE) nhánh `develop` (đối chiếu commit `4cae7a2`; trước đó `fda1ab2`). Khi `USE_MOCK=false`, chức năng đã nối gọi API thật, chức năng chưa nối được tự dùng dữ liệu mẫu và hiện dải "Dữ liệu mẫu"; bật/tắt ở `lib/app/config/api_availability.dart`. Danh sách đã nối / chưa nối được (kèm lỗi, nguyên nhân) ở `docs/API_CONTRACT.md` mục 0.

### Thêm
- Tự gia hạn phiên bằng refresh token (`/api/v1/auth/refresh`): làm mới trước khi token hết hạn và khi gặp 401, nhiều request cùng lúc chỉ gia hạn một lần. Mất mạng hoặc BE lỗi tạm thời thì giữ phiên, không đăng xuất.
- A-05 Đăng ký khách gọi API thật (`/api/v1/auth/register`), không còn bước OTP khi dùng BE thật; mã cửa hàng gửi làm `subdomain`. Chế độ mock giữ OTP.
- M-50, C-40: thẻ hồ sơ hiện họ tên, email và tên cửa hàng thật (`/api/v1/users/me`, `/api/v1/tenants/me`).
- C-40 Đổi mật khẩu (`/api/v1/auth/change-password`); đổi xong đăng xuất và báo đăng nhập lại.
- Trạng thái đơn "Tạm giữ" (`ON_HOLD`): không có nút "Chuẩn bị hàng", không in vận đơn, vẫn ghi nhận hoàn/trả được.
- M-20, M-21 và sheet hoàn/trả hiện dải "Dữ liệu mẫu" khi dữ liệu đơn là mẫu.
- T-20 Nhân viên gọi API thật (`/api/v1/users`): danh sách, thêm nhân viên (thêm ô **Họ tên** bắt buộc, cả ở chế độ mock), khóa / mở khóa. Chủ cửa hàng không tự khóa được mình.
- M-30/31/32 Sản phẩm gọi API thật (`/api/v1/products`): danh sách kèm SKU (gọi `/skus` từng sản phẩm, tối đa 4 cùng lúc), chi tiết, tạo. BE chưa trả link sàn nên ẩn chấm kênh và nhóm "Liên kết sàn".
- M-40 Tồn kho gọi API thật (`/api/v1/inventory`): ghép với danh sách sản phẩm; SKU chưa có dòng tồn hiện tồn 0 và đặt tồn được ngay; dòng không khớp SKU hiện "SKU #id".
- M-20/M-21 Đơn hàng gọi API thật (`/api/v1/orders`, `/api/v1/returns`). Thẻ "Sản phẩm" ở M-21 để trống vì BE chưa trả sản phẩm của đơn. App chỉ cho chuyển `PENDING → TO_SHIP`.
- M-51 Dự báo gọi API thật (`/api/v1/ai/forecast/{skuId}`): sắp xếp theo ngày, chỉ lấy từ hôm nay, tối đa 7 ngày.
- T-10 Kết nối sàn: trạng thái và ngắt kết nối gọi API thật. BE chỉ cho kết nối qua OAuth nên khi dùng BE thật app ẩn form App Key, nút "Kết nối" tắt "Sắp có". Công tắc tự nhập vẫn là mẫu.
- Phiên bị thu hồi (BE `4cae7a2`, 401 `TOKEN_REVOKED` khi tài khoản bị khóa hoặc đổi quyền): refresh cũng thất bại thì đăng xuất và màn đăng nhập báo "Phiên đăng nhập đã bị thu hồi (tài khoản bị khóa hoặc đổi quyền). Vui lòng đăng nhập lại." Hết phiên khác giữ thông báo cũ.
- M-51 chỉ có ở gói Pro: cửa hàng không ở gói PRO (biết qua `planType` của `/api/v1/tenants/me`, hoặc BE trả 403 `FEATURE_NOT_AVAILABLE`) thấy "Dự báo AI chỉ có ở gói Pro", không có nút "Thử lại", không mở sheet chọn SKU khi đã biết gói.

### Thay đổi
- Đăng nhập, đăng xuất, quên/đặt lại mật khẩu chuyển sang `/api/v1/auth/*` và đọc phản hồi dạng mới (`user_info`, tên trường snake_case). Đặt lại mật khẩu gửi thêm ô nhập lại.
- Mật khẩu mới: 6–100 ký tự (trước: tối thiểu 8), khớp BE.
- Đơn hàng, hoàn/trả, sản phẩm, tồn kho, dự báo AI, kết nối sàn chuyển sang `/api/v1/...` (BE `9e7c4da`).
- Hộp thư (còn mock) dùng đơn mẫu riêng khi đơn hàng đã nối BE, và thẻ đơn trong hội thoại không mở M-21 lúc đó, để không gửi id đơn mẫu lên BE.
- Đọc được phân trang `PageResponse` snake_case của `/api/v1/users`.
- Mọi đường dẫn API gom về `lib/core/network/api_paths.dart`.

### Sửa lỗi
- Đơn `ON_HOLD` từ BE bị hiện là "Chờ xử lý" và có nút "Chuẩn bị hàng".
- Test claim điểm tự hỏng theo ngày do dữ liệu mẫu lấy giờ thật thay vì đồng hồ của test.
- "Thử lại" ở M-40 và M-51 tải lại cả danh sách sản phẩm, không còn kẹt lỗi khi sản phẩm lỗi thoáng qua.
- M-32: lỗi vượt giới hạn SKU của gói (400 `SKU_LIMIT_EXCEEDED`, "Gói Free chỉ hỗ trợ tối đa 100 SKU.") hiện ở banner của form thay vì dưới ô Mã SKU.

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

[Unreleased]: https://github.com/Smart-Omni/SmartOmni_Mobile/compare/v0.1.0...develop
[0.1.0]: https://github.com/Smart-Omni/SmartOmni_Mobile/releases/tag/v0.1.0
