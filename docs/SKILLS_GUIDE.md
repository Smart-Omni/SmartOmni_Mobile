# Dùng skill với Claude Code trong SmartOmni

**Skill** là một gói hướng dẫn soạn sẵn cho một loại việc, ví dụ "review code", "sửa lỗi tràn layout Flutter". Claude Code đọc skill rồi làm theo các bước trong đó. Bạn không cần nhớ nội dung skill, chỉ cần biết **việc nào dùng skill nào**.

> Quy tắc trên hết: `docs/DESIGN.md` và `CLAUDE.md` luôn thắng gợi ý của skill. Nếu skill đề xuất gradient, FAB, đổi font… trái với DESIGN.md thì bỏ qua.

## 1. Gọi skill thế nào

- **Xem skill đang có:** trong Claude Code gõ `/` để hiện danh sách lệnh, skill nằm trong đó. Hoặc hỏi thẳng: "Liệt kê các skill bạn đang có."
- **Gọi theo tên:** gõ `/impeccable critique lib/features/products/presentation/product_detail_screen.dart`.
- **Gọi bằng lời:** "Dùng skill ponytail-review để review nhánh này."
- Nhiều skill tự kích hoạt khi việc khớp mô tả của nó. Tuy vậy, nói rõ tên skill vẫn chắc chắn nhất.
- Mỗi lần chỉ giao **một việc nhỏ** (một màn, một nhánh). Đọc kết quả xong mới giao việc tiếp.

## 2. Việc nào dùng skill nào

| Khi bạn muốn… | Skill | Ghi chú |
|---|---|---|
| Bắt đầu nhánh mới, commit, mở PR | `git-workflow-and-versioning` | Nhánh `feature/...` từ `develop`; commit theo Conventional Commits |
| Bàn ý tưởng khi yêu cầu còn mơ hồ | `brainstorming` hoặc `interview-me` | Claude hỏi từng câu trước khi làm |
| Chia một việc lớn thành bước nhỏ | `writing-plans`, `incremental-implementation` | Dùng cho M-60/61, T-20… sau này |
| Soi một màn so với DESIGN.md | `impeccable` → `critique` | Chỉ liệt kê lỗi, **chưa sửa** |
| Sửa giao diện tối thiểu | `ponytail` | Sửa đúng chỗ, không thêm widget trùng |
| Hoàn thiện chi tiết trước khi xong màn | `impeccable` → `polish` | Lưới 4, thang chữ, skeleton / rỗng / lỗi, 360dp |
| Màn bị lỗi "RenderFlex overflowed" | `flutter-fix-layout-issues` | |
| Màn phải ổn ở 360dp và màn lớn | `flutter-build-responsive-layout` | |
| Viết test widget cho màn | `flutter-add-widget-test` | Giữ `Key` cũ, không xóa test |
| Viết unit test cho quy tắc nghiệp vụ | `dart-add-unit-test` (+ `test-driven-development`) | Điểm, hạng, 15 ngày, trạng thái đơn |
| `flutter analyze` báo lỗi | `dart-run-static-analysis` | Dùng `dart fix --apply` cho lỗi máy móc |
| `flutter pub get` báo xung đột phiên bản | `dart-resolve-package-conflicts` | |
| Có lỗi lạ, chưa rõ nguyên nhân | `systematic-debugging` | Tìm nguyên nhân trước rồi mới sửa |
| Review code trước khi mở PR | `ponytail-review` | Giải thích từng lỗi bằng lời dễ hiểu |
| Trước khi nói "xong" | `verification-before-completion` | Bắt chạy format/analyze/test và đọc kết quả |

Không cần dùng cho dự án này: `design-taste-frontend` (dành cho trang web marketing), `docx`, `pptx`, `xlsx`, `pdf` (dành cho file văn phòng).

## 3. Một vòng làm một màn (ví dụ M-31)

Copy từng câu dưới đây vào Claude Code, **chờ xong câu này rồi mới gửi câu tiếp**.

1. **Tạo nhánh:**
   > Dùng git-workflow-and-versioning: từ `develop` mới nhất tạo nhánh `feature/ui-merchant-subscreens`.
2. **Soi lỗi (chưa sửa):**
   > Dùng impeccable critique màn M-31 (`lib/features/products/presentation/product_detail_screen.dart`) so với `docs/DESIGN.md` bản 2 Glass. Chỉ liệt kê chỗ sai, chưa sửa.
3. **Bạn đọc danh sách**, gạch những mục không muốn sửa, rồi trả lời:
   > Sửa các mục 1, 2, 4. Dùng ponytail, chỉ dùng widget `So…` có sẵn.
4. **Chạy thử trên máy:** `flutter run --flavor dev -t lib/main_dev.dart`, đăng nhập `admin@demo.vn` / `12345678`, mở màn đó để xem.
5. **Hoàn thiện:**
   > Dùng impeccable polish cho M-31: skeleton, rỗng, lỗi + Thử lại, kiểm 360dp.
6. **Test và kiểm tra:**
   > Cập nhật widget test nếu cần (flutter-add-widget-test). Sau đó dùng verification-before-completion: chạy `dart format lib test`, `flutter analyze`, `flutter test` và cho tôi xem kết quả.
7. **Review và commit:**
   > Dùng ponytail-review cho thay đổi của M-31. Sửa các lỗi nghiêm trọng, rồi commit `feat(ui): restyle M-31 product detail`.
8. Lặp lại bước 2–7 cho M-32, M-51, T-10. Cuối nhánh:
   > Push nhánh và mở PR vào `develop`, liệt kê các màn đã đổi.
9. Đánh dấu tiến độ trong `docs/UI_UPGRADE_PLAN.md`.

## 4. Mẹo cho người mới

- Claude Code hỏi xin quyền chạy lệnh thì đọc lệnh trước khi bấm cho phép. Lệnh xóa (`rm`, `git reset --hard`, `git push --force`) thì hỏi lại trước khi đồng ý.
- Nếu Claude Code định sửa nhiều file ngoài màn đang làm, bảo nó dừng: "Chỉ sửa màn M-31."
- Hết ngữ cảnh hoặc bắt đầu phiên mới thì nhắc nó: "Đọc `CLAUDE.md` và `docs/UI_UPGRADE_PLAN.md`, cho biết đang ở bước nào."
- Không dán mật khẩu thật, key sàn hay file `key.properties` vào chat.
