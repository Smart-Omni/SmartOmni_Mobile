# Kế hoạch nâng cấp giao diện (đang làm)

Cập nhật: 20/10/2026. Nguồn chuẩn giao diện vẫn là `docs/DESIGN.md` (bản 2 Glass); file này chỉ nói **làm gì, theo thứ tự nào**.

## Hiện trạng

Design system (`lib/core/design/`, 21 widget `So…`) và các màn Merchant đợt 1 đã xong. Còn **8 màn dùng giao diện Material cũ** (`AppBar`, `Card`, `Icons.*`, `Colors.*`, FAB), vi phạm mục "Không làm" của DESIGN.md:

| Mã | Màn | File | Vấn đề chính | Đặc tả |
|---|---|---|---|---|
| M-31 | Chi tiết sản phẩm (Merchant) | `lib/features/products/presentation/product_detail_screen.dart` | AppBar, icon Material | Theo phong cách M-21 |
| M-32 | Tạo sản phẩm | `lib/features/products/presentation/product_create_screen.dart` | AppBar, ô nhập mặc định | Dùng SoTextField |
| M-51 | AI dự báo nhu cầu | `lib/features/ai_insights/presentation/ai_screens.dart` | Chưa dùng SoAiLabel | Có SoAiLabel |
| T-10 | Kết nối sàn | `lib/features/marketplace/presentation/marketplace_screen.dart` | `Colors.green`, icon đặc | Theo M-50 |
| C-10 | Storefront | `lib/features/storefront/presentation/storefront_screens.dart` | FAB, Card, MockDataBanner | **Chưa có** |
| C-11 | Chi tiết sản phẩm (Customer) | cùng file trên | Nút mua chưa theo SoChannelTag | **Chưa có** |
| C-20 | Điểm & hạng | `lib/features/loyalty/presentation/loyalty_screen.dart` | Chưa dùng SoTierBadge | **Chưa có** |
| C-30 | Claim đơn | `lib/features/loyalty/presentation/claim_order_screen.dart` | Ô nhập, nút mặc định | **Chưa có** |

C-40 (`customer_account_screen.dart`) đã dùng design system một phần; rà lại khi làm nhánh 4.

**Chưa có code:** A-05 Đăng ký (+ OTP) và C-00 Chọn cửa hàng. Đã chốt: **một tài khoản khách dùng được ở nhiều cửa hàng**; điểm, hạng, voucher tính riêng theo từng cửa hàng.

## Thứ tự nhánh (mỗi nhánh 1 PR vào `develop`)

0. `feature/ui-glass-foundation`: chuyển design system sang **bản 2 Glass** theo mục 10 của DESIGN.md (token màu, Inter + JetBrains Mono, `SoGlass`, `SoAmbientBackground`, thanh tab nổi, AppBar tiêu đề lớn). Giữ tên và tham số widget `So…`. Xong nhánh này thì các màn đợt 1 tự đổi giao diện; chạy thử và chụp lại A-02, M-10, M-20 để so với mockup glass.
1. `feature/ui-merchant-subscreens`: M-31, M-32, M-51, T-10. Bố cục giống M-21; SoAppBar.child, Lucide icon, SoButton, SoTextField, SoStatusTag, SoAiLabel. Mỗi màn 1 commit.
2. `feature/ui-customer-spec`: chưa code. Viết **mục 8b – Màn Customer** vào DESIGN.md cho: A-05 Đăng ký (+ OTP), C-00 Chọn cửa hàng (+ sheet Thêm cửa hàng), widget `SoShopSwitcher` (nút đổi cửa hàng trên AppBar), C-10, C-11, C-20, C-30 (+ kết quả và 4 ca lỗi), C-40.
   - Nội dung lấy từ mockup đợt 2 (https://claude.ai/artifact/5jYxMTRbbvn9wTmy663nWC), vẽ lại theo bản 2 Glass.
   - C-20 đã có mockup glass được duyệt (https://claude.ai/artifact/WE5CeBwvbjgsRvMcrewpCQ): chỉ chép đặc tả, **không** đề xuất lại.
   - Chỉ C-10 cần brainstorming: 2 hướng bố cục, hỏi người dùng chọn.
   - Không FAB; lối vào chatbot C-12 là nút trên AppBar của C-10 (thay thẻ "Chưa biết chọn gì?" trong mockup đợt 2).
3. `feature/ui-customer-shop`: C-00 + `SoShopSwitcher`, C-10, C-11 theo mục 8b. Bỏ FAB, `MockDataBanner` → `SoMockBanner`, nút mua trên sàn dùng SoChannelTag. Thử bằng `customer@demo.vn`.
   - **Nhiều cửa hàng chạy bằng mock:** backend chưa có API (xem `docs/API_CONTRACT.md` mục 3). Thêm `CustomerShopRepository` (interface ở `domain/`, Mock ở `data/`) và provider "cửa hàng đang xem"; điểm, voucher, sản phẩm, claim đều đọc theo cửa hàng này.
4. `feature/ui-customer-loyalty`: C-20, C-30, C-40 theo mục 8b. SoTierBadge, SoTextField mono cho mã đơn. Dữ liệu tách theo cửa hàng đang xem.
5. `feature/ui-customer-register`: A-05 Đăng ký + OTP, chạy bằng mock (backend chưa có `POST /api/customers/register`). Nút "Chưa có tài khoản? Đăng ký" trên A-02. Thêm route vào `resolveRedirect()` (trang công khai) và test cho router.

Để sau 5 nhánh (đặc tả đã có ở DESIGN.md mục 8b, làm theo thứ tự): ~~M-60/61 Hộp thư CSKH~~ (xong) → ~~C-12 Chatbot~~ (xong) → ~~M-22 In vận đơn~~ (xong) → ~~T-20 Nhân viên~~ (xong) → ~~T-30 Phát voucher~~ (xong) → ~~T-40 Gói dịch vụ~~ (xong) → ~~T-50 Hỗ trợ~~ (xong) → T-10 OAuth (khi backend có). Mỗi nhóm 1 nhánh, dùng mock khi chưa có API.

## Vòng lặp cho mỗi màn

1. **impeccable critique** màn đó so với DESIGN.md → liệt kê chỗ sai, **chưa sửa**, chờ người dùng duyệt.
2. Sửa theo danh sách đã duyệt (ponytail): chỉ dùng widget `So…` và token có sẵn, không tạo widget trùng.
3. Người dùng chạy thử: `flutter run --flavor dev -t lib/main_dev.dart` (tài khoản demo, mật khẩu `12345678`).
4. **impeccable polish**: lưới 4, thang chữ, trạng thái skeleton / rỗng / lỗi + "Thử lại", bề rộng 360dp.
5. Cập nhật widget test (giữ `Key`, không xóa test) → `dart format lib test` → `flutter analyze` → `flutter test` xanh → ponytail-review → commit Conventional Commits.

## Tiến độ

- [x] DESIGN.md bản 2 Glass + mockup 4 màn (A-02, M-10 Admin, M-20, C-20), duyệt 19/10/2026
- [x] Nhánh 0: nền móng Glass (PR #14, xong 20/10/2026; sửa tiếp ở `fix/glass-followups`: đồng hồ dữ liệu mẫu, thẻ nhóm ngày M-20)
- [x] Nhánh 1: M-31 · M-32 · M-51 (PR #17, xong 20/10/2026). Kèm `SoScaffold` + `SoAppBar` dạng sliver cho mọi màn Merchant, A-03, A-04, C-40
- [x] Nhánh 1b `feature/ui-marketplace`: T-10 (danh sách sàn + sheet App Key; OAuth để sau), xong 20/10/2026. Danh sách, ngắt kết nối, công tắc tự nhập chạy mock; kết nối App Key gọi API thật
- [x] Nhánh 2: mục 8b DESIGN.md — viết xong 20/10/2026 cho **mọi màn còn lại** (kể cả M-22, M-60/61, T-10…T-50, C-12) từ mockup glass 41 màn
- [x] Nhánh 3: C-00 · SoShopSwitcher · C-10 · C-11, xong 20/10/2026. Nhiều cửa hàng chạy mock (`CustomerShopRepository`, `currentShopProvider`); quét QR mã cửa hàng để sau (nút báo "sắp có")
- [x] Nhánh 4: C-20 · C-30 (+ màn kết quả, 5 lỗi) · C-40, xong 20/10/2026. Điểm, voucher, lịch sử, claim tách theo cửa hàng đang xem (mock); khung tab Customer bật `extendBody`; quét mã đơn để sau (báo "sắp có")
- [x] Nhánh 5: A-05 (+ OTP), xong 20/10/2026. Đăng ký + OTP chạy mock (`RegistrationRepository`, mã mẫu `123456`); tài khoản mới chỉ có cửa hàng vừa tham gia, đăng nhập lại được trong phiên chạy app; tra mã cửa hàng dùng chung `ShopCodeLookup` với sheet C-00; quét QR để sau
- [x] Nhánh 6 `feature/ui-inbox`: M-60 · M-61 (khiếu nại + thường) · sheet gắn đơn, xong 21/10/2026. Chạy mock (`InboxRepository`, chưa có Remote vì backend chưa có Message Service). Mỗi hàng một nhãn theo ưu tiên Đã giải quyết > Khiếu nại > Cần kiểm tra > Chưa trả lời; tin shop có Đang gửi… / Đã gửi / Chưa rõ (lỗi hoặc quá 15 giây); gửi ảnh để sau (báo "sắp có"). Design system thêm `SoChipBar` (M-20 dùng chung), `SoAppBar.channel`, `SoScaffold.controller`, `SoOrderRow.selected`
- [x] Nhánh 7 `feature/ui-chatbot`: C-12, xong 21/10/2026. Chạy mock (`ChatbotRepository`; gợi ý sản phẩm của cửa hàng đang xem theo từ trong tên, tối đa 3 thẻ → C-11; không khớp hoặc gọi lỗi thì câu dự phòng nền warningTint; hỏi đặt/mua thì nhắc mua trên sàn, quy tắc `isOrderIntent` có test). Không câu hỏi gợi ý, không nút ảnh. "Hỏi AI" trên C-10 mở C-12. Design system thêm `SoChatBubble`, `SoChatComposer` (M-61 dùng chung), `SoAppBar.subtitleIsCode`
- [x] Nhánh 8 `feature/ui-shipping-label`: M-22, xong 22/10/2026. Chạy mock (`ShippingLabelRepository` đọc tem mẫu `assets/mock/shipping_label_sample.pdf`); gói `printing` vẽ xem trước, chia sẻ, in bằng hộp thoại hệ thống (`PdfTools` sau provider). Mở từ M-21 khi đơn Chờ giao / Đã giao cho ĐVVC / Đang giao; PENDING hiện mờ "Có sau khi Chuẩn bị hàng"; xong / hủy / trả thì ẩn (`labelAvailability`). Phóng to bằng hai ngón; lỗi "sàn chưa tạo tem" tách khỏi lỗi mạng. Design system thêm `SoListRow.enabled`
- [x] Nhánh 9 `feature/ui-staff`: T-20, xong 22/10/2026. Chạy mock (`StaffRepository`, danh sách khớp tài khoản demo; khóa chỉ đổi danh sách, không chặn đăng nhập mock). Chủ cửa hàng "Bạn" đứng đầu, không khóa được (`canToggleStaff`); thứ tự Bạn → đang hoạt động → đã khóa (`sortStaff`). Sheet xác nhận Khóa / Mở khóa nói rõ hệ quả; sheet Thêm nhân viên (email + mật khẩu tạm ≥ 8, báo email trùng). `/m/staff` trong `Routes.tenantAdminOnly` (có test); M-50 bỏ "Sắp có". Không có phân quyền con
- [x] Nhánh 10 `feature/ui-voucher`: T-30, xong 22/10/2026. Chạy mock (`VoucherRepository`: 128 khách theo hạng; Shopee tạo được, TikTok Shop khóa; đợt phát trong phiên tự "Đang tạo" → "Thành công" sau 3 giây). Chip "từ hạng trở lên" có số khách cộng dồn + sheet "Chọn từng khách" (tìm theo tên/email); chỉ giảm số tiền ₫; hạn dùng chip 7/14/30 ngày (không dialog); đơn tối thiểu phải lớn hơn giá trị giảm. Sheet xác nhận tóm tắt trước khi phát; đợt "Chưa rõ · đối soát" không có nút phát lại. Quy tắc ở domain có test; `/m/vouchers` chỉ Tenant Admin (có test). Design system thêm `SoSegment.enabled`
- [x] Nhánh 11 `feature/ui-subscription`: T-40, xong 22/10/2026. Chạy mock (`SubscriptionRepository`, "Gói mẫu", không có bảng giá). Thẻ kính: tên gói, hạn, nhãn Đang dùng / Sắp hết hạn (≤ 7 ngày) / Đã hết hạn (`planStatus`). Thẻ trắng "Mức đã dùng": SKU, kết nối sàn, dung lượng ảnh; ≥ 80% warning, đầy danger, không giới hạn thì không vẽ thanh (`usageLevel`). Banner khi còn hóa đơn chưa thanh toán; nhóm "Hóa đơn" (mã mono, số tiền, Đã/Chưa thanh toán). Đổi gói / Thanh toán chỉ toast "sắp có". `/m/subscription` chỉ Tenant Admin (có test). Design system thêm `SoProgressBar` (C-20 dùng chung)
- [x] Nhánh 12 `feature/ui-support`: T-50, xong 22/10/2026. Chạy mock (`SupportRepository`; bảng `support_tickets` và route Nginx đã có nhưng chưa có API trong hợp đồng). Segmented "Chưa xong · n / Đã giải quyết · n"; hàng ticket là khối tĩnh (mã mono, thời gian, nhãn Mở warning / Đang xử lý info / Đã giải quyết success, tiêu đề, trả lời cuối "Hỗ trợ:" / "Bạn:" / "Chưa có trả lời"). Sheet Tạo yêu cầu (tiêu đề ≤ 120, mô tả ≤ 2.000); gửi xong về tab Chưa xong, ticket mới ở đầu. Không màn chi tiết, không FAQ. `/m/support` chỉ Tenant Admin (có test); M-50 không còn mục "Sắp có" trong nhóm Quản trị

Claude: cập nhật danh sách này khi xong mỗi màn.
