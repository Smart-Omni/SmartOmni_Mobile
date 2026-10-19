# Kế hoạch nâng cấp giao diện (đang làm)

Cập nhật: 19/10/2026. Nguồn chuẩn giao diện vẫn là `docs/DESIGN.md` (bản 2 Glass); file này chỉ nói **làm gì, theo thứ tự nào**.

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

## Thứ tự nhánh (mỗi nhánh 1 PR vào `develop`)

0. `feature/ui-glass-foundation`: chuyển design system sang **bản 2 Glass** theo mục 10 của DESIGN.md (token màu, Inter + JetBrains Mono, `SoGlass`, `SoAmbientBackground`, thanh tab nổi, AppBar tiêu đề lớn). Giữ tên và tham số widget `So…`. Xong nhánh này thì các màn đợt 1 tự đổi giao diện; chạy thử và chụp lại A-02, M-10, M-20 để so với mockup glass.
1. `feature/ui-merchant-subscreens`: M-31, M-32, M-51, T-10. Bố cục giống M-21; SoAppBar.child, Lucide icon, SoButton, SoTextField, SoStatusTag, SoAiLabel. Mỗi màn 1 commit.
2. `feature/ui-customer-spec`: chưa code. Dùng brainstorming: đề xuất 2 hướng bố cục cho C-10 và C-20 theo bản 2 Glass (C-20 đã có mockup glass), hỏi người dùng chọn, rồi viết **mục 8b – Màn Customer** vào DESIGN.md (C-10, C-11, C-20, C-30, C-40). Không FAB; lối vào chatbot C-12 đặt ở AppBar.
3. `feature/ui-customer-shop`: C-10, C-11 theo mục 8b. Bỏ FAB, `MockDataBanner` → `SoMockBanner`, nút mua trên sàn dùng SoChannelTag. Thử bằng `customer@demo.vn`.
4. `feature/ui-customer-loyalty`: C-20, C-30, C-40 theo mục 8b. SoTierBadge, SoTextField mono cho mã đơn.

Để sau 4 nhánh: C-12, M-60/61, T-20…T-50 (dùng interview-me + writing-plans).

## Vòng lặp cho mỗi màn

1. **impeccable critique** màn đó so với DESIGN.md → liệt kê chỗ sai, **chưa sửa**, chờ người dùng duyệt.
2. Sửa theo danh sách đã duyệt (ponytail): chỉ dùng widget `So…` và token có sẵn, không tạo widget trùng.
3. Người dùng chạy thử: `flutter run --flavor dev -t lib/main_dev.dart` (tài khoản demo, mật khẩu `12345678`).
4. **impeccable polish**: lưới 4, thang chữ, trạng thái skeleton / rỗng / lỗi + "Thử lại", bề rộng 360dp.
5. Cập nhật widget test (giữ `Key`, không xóa test) → `dart format lib test` → `flutter analyze` → `flutter test` xanh → ponytail-review → commit Conventional Commits.

## Tiến độ

- [x] DESIGN.md bản 2 Glass + mockup 4 màn (A-02, M-10 Admin, M-20, C-20), duyệt 19/10/2026
- [ ] Nhánh 0: nền móng Glass
- [ ] Nhánh 1: M-31 · M-32 · M-51 · T-10
- [ ] Nhánh 2: mục 8b DESIGN.md
- [ ] Nhánh 3: C-10 · C-11
- [ ] Nhánh 4: C-20 · C-30 · C-40

Claude: cập nhật danh sách này khi xong mỗi màn.
