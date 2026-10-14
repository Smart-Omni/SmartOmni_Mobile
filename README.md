# SmartOmni Mobile

App Flutter cho nền tảng **SmartOmni** - SaaS quản lý bán hàng đa kênh trên **Shopee** và **TikTok Shop**.
Backend: [Hxvf123/SmartOmmi_BE](https://github.com/Hxvf123/SmartOmmi_BE) (Java Spring Boot, đi qua Nginx Gateway cổng `8080`).

Một app duy nhất, **một màn hình đăng nhập chung**. Sau khi đăng nhập, app tự đưa người dùng vào khu vực theo role:

| Role (backend) | Khu vực trong app | Chức năng chính |
|---|---|---|
| `CUSTOMER` | Customer | Xem sản phẩm → mua trên sàn, claim đơn tích điểm, xem hạng & voucher |
| `MANAGER` (Staff) | Merchant | Xử lý đơn, sản phẩm, tồn kho, cảnh báo AI |
| `ADMIN` (Tenant Admin) | Merchant + quản trị | Như Staff + doanh thu, kết nối sàn, (sắp có) nhân viên, voucher, gói SaaS |
| `SUPER_ADMIN` | ❌ Không hỗ trợ trên mobile | Dùng Super Admin Console trên web |

> **Trạng thái:** đây là **khung dự án** (scaffold). Đăng nhập, điều hướng theo role, gọi API, mock dữ liệu, test và CI/CD đã chạy được. Giao diện đang ở mức cơ bản và sẽ được thiết kế lại theo [docs/USER_FLOWS.md](docs/USER_FLOWS.md).

## Chạy nhanh (5 phút)

```bash
git clone https://github.com/tuankiet710/SmartOmni_Mobile.git
cd SmartOmni_Mobile
flutter pub get

# Android (máy ảo hoặc máy thật) - chế độ mock, không cần backend
flutter run --flavor dev -t lib/main_dev.dart

# iPhone / iOS Simulator (trên Mac)
flutter run -t lib/main_dev.dart
```

Tài khoản demo (chế độ mock), mật khẩu chung **`12345678`**:

| Email | Role |
|---|---|
| `customer@demo.vn` | Customer |
| `staff@demo.vn` | Staff |
| `admin@demo.vn` | Tenant Admin |
| `superadmin@demo.vn` | Super Admin (để thử thông báo bị từ chối) |

Hướng dẫn chi tiết từ A-Z (cài Flutter, Android Studio, Xcode, chạy trên iPhone miễn phí, nối backend local): **[docs/SETUP.md](docs/SETUP.md)**.

## Tài liệu

| File | Nội dung |
|---|---|
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | Yêu cầu nghiệp vụ của dự án, rút ra từ repo backend |
| [docs/USER_FLOWS.md](docs/USER_FLOWS.md) | Các flow theo role - đầu vào cho bước thiết kế giao diện |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Kiến trúc, cấu trúc thư mục, Riverpod, cách thêm 1 feature mới |
| [docs/API_CONTRACT.md](docs/API_CONTRACT.md) | Màn hình ↔ API backend; chỗ nào đang dùng mock; API đề xuất cho backend |
| [docs/SETUP.md](docs/SETUP.md) | Cài đặt môi trường và chạy app (Android + iOS miễn phí) |
| [docs/CICD.md](docs/CICD.md) | CI/CD là gì, pipeline đang có, cách bật phân phối bản test / Google Play |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Quy trình nhánh, commit, Pull Request |

## Công nghệ

Flutter (stable) · Dart 3 · **Riverpod 3** (state) · **go_router** (điều hướng) · **Dio** (HTTP) · flutter_secure_storage (lưu JWT) · intl + gen-l10n (tiếng Việt / tiếng Anh) · GitHub Actions (CI/CD).

## Cấu trúc rút gọn

```
lib/
├── main_dev.dart / main_staging.dart / main_prod.dart   # entry point theo môi trường
├── app/        # cấu hình, router + phân quyền theo role, theme
├── core/       # network (Dio, lỗi, response), auth (JWT, role), storage, widgets dùng chung, mock data
├── features/   # mỗi chức năng: data / domain / presentation
└── l10n/       # chuỗi tiếng Việt / tiếng Anh
test/           # unit test + widget test
.github/        # CI/CD, Dependabot, mẫu PR
docs/           # tài liệu
```

## Lệnh hay dùng

```bash
flutter pub get                 # tải thư viện
dart format lib test            # format code (CI bắt buộc)
flutter analyze                 # kiểm tra lỗi
flutter test                    # chạy test
flutter build apk --flavor dev -t lib/main_dev.dart   # build APK để cài thử
```
