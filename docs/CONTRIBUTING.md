# Quy trình đóng góp

Giống quy trình của repo backend để cả team quen một kiểu.

## Nhánh

```
main      ← luôn ở trạng thái phát hành được (chỉ merge từ develop)
develop   ← nhánh tích hợp hằng ngày
feature/<khu-vuc>-<mo-ta>   vd: feature/orders-filter-by-platform
fix/<khu-vuc>-<mo-ta>       vd: fix/auth-expired-token-loop
```

```
feature/* hoặc fix/*  →  Pull Request vào develop  →  Pull Request develop → main
```

**Không push thẳng** lên `main` hoặc `develop`.

## Làm một việc từ đầu tới cuối

```bash
git fetch origin
git switch develop
git pull --ff-only origin develop
git switch -c feature/orders-filter-by-platform

# ... sửa code ...

dart format lib test       # CI sẽ fail nếu code chưa format
flutter analyze            # phải không còn lỗi / cảnh báo
flutter test               # phải pass

git add -A
git status                 # kiểm tra KHÔNG có key.properties, *.jks, .env
git commit -m "feat(orders): filter orders by platform"
git push -u origin feature/orders-filter-by-platform
```

Lên GitHub mở Pull Request: **base = `develop`**, compare = nhánh của bạn. Điền mẫu PR, chờ CI xanh ✅ và ít nhất 1 người review.

## Commit message (Conventional Commits)

```
<loại>(<khu vực>): <mô tả ngắn, tiếng Anh, thì hiện tại>
```

| Loại | Dùng khi |
|---|---|
| `feat` | Thêm chức năng |
| `fix` | Sửa lỗi |
| `refactor` | Sửa code không đổi hành vi |
| `test` | Thêm/sửa test |
| `docs` | Tài liệu |
| `ci` | Workflow GitHub Actions |
| `chore` | Việc vặt (nâng thư viện...) |

Ví dụ: `feat(loyalty): show points history`, `fix(auth): logout on 401`, `ci: cache gradle`.

## Quy ước code

- Tuân theo `analysis_options.yaml` (CI chạy `flutter analyze`).
- Màn hình không gọi Dio trực tiếp - luôn qua repository + provider.
- Quy tắc nghiệp vụ đặt trong `domain/` và **có unit test**.
- Chuỗi hiển thị mới: ưu tiên thêm vào `lib/l10n/app_vi.arb` + `app_en.arb`.
- Endpoint mới hoặc mock mới → cập nhật `docs/API_CONTRACT.md`.

## Gợi ý bảo vệ nhánh (Settings → Branches → Add rule)

Cho `main` và `develop`:
- ✅ Require a pull request before merging (1 approval)
- ✅ Require status checks to pass → chọn **Format · Analyze · Test** và **Build APK (dev + staging)**
- ✅ Do not allow bypassing the above settings
