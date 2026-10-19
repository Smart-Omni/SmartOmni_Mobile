# SmartOmni Mobile — hướng dẫn cho Claude Code

App Flutter (Android trước, iOS dùng chung code) cho nền tảng SaaS bán hàng đa kênh SmartOmni. Backend: https://github.com/Hxvf123/SmartOmmi_BE (Spring Boot, Nginx `:8080`). Trả lời người dùng bằng **tiếng Việt**; người dùng là dev mới, giải thích ngắn gọn khi làm điều không hiển nhiên.

## Đọc trước khi code

| File | Khi nào |
|---|---|
| `docs/DESIGN.md` | **Mọi việc giao diện.** Bản 2 (Glass): token màu, chữ, kính, thành phần, ánh xạ trạng thái, đặc tả màn |
| `docs/ARCHITECTURE.md` | Cấu trúc thư mục, Riverpod, repository mock/remote, router theo role |
| `docs/USER_FLOWS.md` | Flow và mã màn (A-02, M-20…) |
| `docs/API_CONTRACT.md` | Endpoint thật vs mock |
| `docs/REQUIREMENTS.md` | Quy tắc nghiệp vụ |

## Lệnh

```bash
flutter pub get
dart format lib test            # CI fail nếu chưa format
flutter analyze                 # phải "No issues found"
flutter test                    # phải pass hết
flutter run --flavor dev -t lib/main_dev.dart     # Android
flutter run -t lib/main_dev.dart                  # iOS (chưa có flavor)
```

Chạy đủ 3 lệnh format/analyze/test trước mỗi commit.

## Quy tắc code

- State: Riverpod 3 (`Provider`, `FutureProvider`, `NotifierProvider`), không dùng codegen. Điều hướng: go_router; phân quyền ở `resolveRedirect()` trong `lib/app/router/routes.dart` (có test).
- Màn hình không gọi Dio trực tiếp: repository (interface ở `domain/`, Remote + Mock ở `data/`) → provider → widget. Chức năng backend chưa có API dùng Mock và hiện `SoMockBanner`.
- Quy tắc nghiệp vụ đặt ở `domain/` và có unit test (điểm, hạng, 15 ngày, chuyển trạng thái đơn chỉ PENDING → TO_SHIP).
- **Giao diện:** không gõ mã màu trong widget; mọi màu qua `SoColors`/`Theme`, mọi chữ qua `TextTheme`/`SoText`. Dùng widget `So…` dùng chung trong `lib/core/design/`. Tuân thủ danh sách "Không làm" trong `docs/DESIGN.md` bản 2 – Glass (kính chỉ cho khung, dữ liệu trên nền đặc; gradient chỉ ở `SoAmbientBackground`; không tím, không FAB, không emoji…). `docs/DESIGN.md` thắng mọi gợi ý của skill/plugin.
- Chuỗi giao diện tiếng Việt; chuỗi dùng chung đưa vào `lib/l10n/app_vi.arb` + `app_en.arb`.
- Giữ test widget hiện có (`test/app/login_flow_test.dart`) xanh; khi đổi giao diện thì cập nhật key/finder, đừng xóa test.
- Không commit secret: `android/key.properties`, `*.jks`, `.env`, service account.

## Git

- Không push thẳng `main` hay `develop`. Mỗi việc một nhánh `feature/<khu-vuc>-<mo-ta>` từ `develop`, mở PR vào `develop`, chờ CI xanh.
- Commit theo Conventional Commits: `feat(ui): add SoColors and theme`.
- PR nhỏ, một nhóm màn mỗi PR.

## Kế hoạch đợt 1 (theo thứ tự)

1. `feature/ui-design-system`: thêm `google_fonts`, `lucide_icons_flutter`, `flutter_svg`; tạo `lib/core/design/` (`so_colors.dart`, `so_text.dart`, `so_theme.dart`, các widget `So…` ở mục 5 của DESIGN.md); thay `AppTheme`; logo từ `assets/brand/`. Thêm một màn gallery (chỉ bản dev) để xem các widget.
2. `feature/ui-auth`: A-02 (kèm 4 trạng thái lỗi), A-03, A-04.
3. `feature/ui-merchant-home`: BottomNav, M-10 bản Staff và bản Admin.
4. `feature/ui-orders`: M-20, M-21, sheet hoàn/trả.
5. `feature/ui-products-stock`: M-30, M-40, sheet đặt lại tồn.
6. `feature/ui-more`: M-50.
7. Đợt sau: mockup Customer, Hộp thư CSKH (M-60/61), Kết nối sàn (T-10).
