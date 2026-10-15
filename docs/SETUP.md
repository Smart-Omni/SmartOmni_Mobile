# Cài đặt và chạy app

Hướng dẫn cho **MacBook Pro M1** (chạy được cả Android và iOS). Toàn bộ **miễn phí**.

## 1. Cài công cụ (làm 1 lần)

### 1.1 Flutter SDK
1. Cài [Homebrew](https://brew.sh) nếu chưa có.
2. Cài Flutter:
   ```bash
   brew install --cask flutter
   flutter --version          # kiểm tra
   ```
   (Hoặc tải zip từ https://docs.flutter.dev/get-started/install/macos.)
3. Chạy `flutter doctor` - lệnh này liệt kê những gì còn thiếu. Mục tiêu: các dòng Android và Xcode đều ✓.

### 1.2 Android (đã làm quen)
1. Cài **Android Studio** → mở **More Actions → SDK Manager** → cài Android SDK + **Command-line Tools**.
2. `flutter doctor --android-licenses` → gõ `y` để đồng ý.
3. Tạo máy ảo: **Device Manager → Create Virtual Device** → chọn Pixel bất kỳ, image **arm64** (máy M1).

### 1.3 iOS (Xcode - miễn phí)
1. Cài **Xcode** từ App Store (khá nặng, ~10GB+).
2. Chạy:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   xcodebuild -downloadPlatform iOS      # tải iOS Simulator
   ```
3. Cài CocoaPods nếu `flutter doctor` yêu cầu: `brew install cocoapods`.

### 1.4 Trình soạn code
VS Code + extension **Flutter**, hoặc Android Studio + plugin **Flutter**.

## 2. Lấy code và chạy (chế độ mock - không cần backend)

```bash
git clone https://github.com/tuankiet710/SmartOmni_Mobile.git
cd SmartOmni_Mobile
git switch develop
flutter pub get
flutter devices                     # xem các thiết bị đang có
```

### Android (máy ảo hoặc điện thoại thật)
```bash
flutter run --flavor dev -t lib/main_dev.dart
```
> Android có 3 flavor nên **bắt buộc** `--flavor`. Quên sẽ báo lỗi "Gradle build failed to produce an .apk".

### iOS Simulator
```bash
open -a Simulator
flutter run -t lib/main_dev.dart
```
> iOS **chưa cấu hình flavor** nên **không** dùng `--flavor`. Môi trường được chọn qua `-t lib/main_<flavor>.dart`.

Đăng nhập bằng tài khoản demo: `customer@demo.vn`, `staff@demo.vn`, `admin@demo.vn` - mật khẩu `12345678`.

## 3. Chạy trên iPhone 14 Plus thật - MIỄN PHÍ (không cần Apple Developer 99 USD)

Apple cho phép dùng **Apple ID thường** để cài app lên iPhone của chính mình. Giới hạn: app **hết hạn sau 7 ngày** (cắm lại và chạy lại là được), tối đa 3 app cùng lúc, không gửi được cho người khác qua TestFlight.

1. **Bật Developer Mode trên iPhone:** Cài đặt → Quyền riêng tư & Bảo mật → **Chế độ nhà phát triển** → Bật → khởi động lại.
   (Nếu chưa thấy mục này: cắm iPhone vào Mac và mở Xcode một lần.)
2. Cắm iPhone vào Mac bằng cáp, bấm **Tin cậy máy tính này**.
3. Mở project iOS bằng Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
4. Trong Xcode: chọn **Runner** (cột trái) → tab **Signing & Capabilities** →
   - Tick **Automatically manage signing**
   - **Team** → *Add an Account…* → đăng nhập Apple ID → chọn "<Tên bạn> (Personal Team)"
   - **Bundle Identifier**: mặc định `com.smartomni.mobile`. Nếu Xcode báo *"is not available"* → đổi thành duy nhất, ví dụ `com.tuankiet710.smartomni` (**chỉ trên máy bạn, không commit thay đổi này**).
5. Chạy từ terminal:
   ```bash
   flutter run -t lib/main_dev.dart     # chọn iPhone trong danh sách thiết bị
   ```
6. Lần đầu iPhone báo *"Untrusted Developer"*: Cài đặt → Cài đặt chung → **Quản lý VPN & Thiết bị** → chọn Apple ID của bạn → **Tin cậy**. Mở lại app.

> Thay đổi Team trong Xcode sẽ sửa file `ios/Runner.xcodeproj/project.pbxproj` (dòng `DEVELOPMENT_TEAM`). **Đừng commit** dòng này vì mỗi người có Team khác nhau: `git checkout ios/Runner.xcodeproj/project.pbxproj` trước khi commit.

## 4. Nối với backend chạy trên máy (USE_MOCK=false)

1. Chạy backend theo README của [SmartOmmi_BE](https://github.com/Hxvf123/SmartOmmi_BE): `docker compose up -d --build` → API ở `http://localhost:8080`.
2. Tạo tài khoản: dùng `POST /api/tenants/onboarding` (Postman) để tạo tenant + admin.
3. Chạy app trỏ vào backend:

| Thiết bị | Lệnh |
|---|---|
| Android Emulator | `flutter run --flavor dev -t lib/main_dev.dart --dart-define=USE_MOCK=false` (mặc định `10.0.2.2:8080` = localhost của Mac) |
| iOS Simulator | `flutter run -t lib/main_dev.dart --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://localhost:8080` |
| Điện thoại thật (Android/iPhone) | Điện thoại và Mac **cùng Wi-Fi**. Lấy IP Mac: `ipconfig getifaddr en0` → `--dart-define=API_BASE_URL=http://192.168.x.x:8080` |

> Bản dev đã cho phép gọi `http://` (Android: `src/dev/AndroidManifest.xml`; iOS: `NSAllowsLocalNetworking`). Lần đầu iPhone hỏi quyền **Mạng cục bộ** → chọn Cho phép.

Các màn hình backend chưa có API vẫn hiển thị dữ liệu mẫu (dải tím "Dữ liệu mẫu").

## 5. Build file cài đặt

```bash
# APK Android cài trực tiếp (gửi file .apk cho bạn bè cài thử)
flutter build apk --release --flavor dev -t lib/main_dev.dart
# → build/app/outputs/flutter-apk/app-dev-release.apk
```

Không muốn build ở máy? Mỗi lần CI chạy xong, vào tab **Actions** trên GitHub → chọn lần chạy → mục **Artifacts** → tải `smartomni-apk-<số>`.

## 6. Lỗi thường gặp

| Lỗi | Cách sửa |
|---|---|
| `Gradle build failed to produce an .apk file` | Thiếu `--flavor dev` |
| Windows: `Could not close incremental caches ... compileDebugKotlin` | Project và Pub cache nằm khác ổ đĩa (vd. `D:\` và `C:\`). Repo đã đặt `kotlin.incremental=false` trong `android/gradle.properties`; chạy `cd android && gradlew --stop`, rồi `flutter clean` và `flutter run --flavor dev -t lib/main_dev.dart`. Nếu còn lỗi: đặt biến môi trường `PUB_CACHE=D:\pub-cache` (cùng ổ với project) rồi `flutter pub get` |
| Android Studio bấm Run báo lỗi flavor / chạy `lib\main.dart` | Run → Edit Configurations → **Build flavor**: `dev`, **Dart entrypoint**: `lib/main_dev.dart` |
| `Target of URI doesn't exist: ...l10n/generated/app_localizations.dart` | Chạy `flutter pub get` (hoặc `flutter gen-l10n`) |
| Android gọi API báo `Không thể kết nối máy chủ` | Emulator dùng `10.0.2.2`, không dùng `localhost`; kiểm tra backend đã chạy (`curl localhost:8080/health`) |
| iOS: `CocoaPods not installed` | `brew install cocoapods`, rồi `cd ios && pod install` |
| iOS: `Signing for "Runner" requires a development team` | Làm bước 3.4 (chọn Personal Team) |
| iPhone không hiện trong `flutter devices` | Mở khóa iPhone, Tin cậy máy tính, bật Developer Mode, thử cáp khác |
| CI báo lỗi format | Chạy `dart format lib test` rồi commit lại |
