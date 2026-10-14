# Thiết kế giao diện SmartOmni Mobile

Tài liệu này là **nguồn chuẩn khi code giao diện**. Nó chép lại SmartOmni Design System và mockup đợt 1 (đã được duyệt ngày 14/10/2026) để người và Claude Code trên máy đọc được ngay trong repo.

- Design system (claude.ai, cần đăng nhập tài khoản chủ dự án): https://claude.ai/artifact/MRoE6yK9bwR1e8DF3pH4nm
- Mockup đợt 1, canvas Claude Design: https://claude.ai/artifact/4JxPGaPHdtxGM7VrQxTnEw
- Logo: `assets/brand/` (SVG một màu, vẽ lại phẳng; thay khi có file gốc, giữ tên file).

## 1. Ý tưởng

Lấy cảm hứng từ kho vận: **tem vận đơn** (thẻ trắng, viền mảnh, không bóng), **thùng carton** (màu kraft chỉ cho hàng trong kho), **kệ chia ô** (bo góc nhỏ, ô vuông thay chấm tròn). Mã đơn và mã SKU luôn là chữ mono trong khung viền đen như in trên tem.

**Không làm:** gradient, kính mờ, màu tím, emoji, bo tròn mọi thứ, thanh tab dạng viên thuốc nổi, thẻ có sọc màu cạnh trái, bóng cho thẻ thường, nút nổi (FAB), căn giữa mọi thứ (nội dung căn trái, số căn phải), dữ liệu bịa (số sao, đánh giá, thời gian giao).

Chỉ giao diện sáng ở đợt này, **nhưng mọi màu phải lấy từ token** để thêm giao diện tối sau.

## 2. Token màu → `SoColors`

| Token | Hex | Dùng khi |
|---|---|---|
| `ground` | `#F2F4F5` | Nền màn hình (Scaffold) |
| `surface` | `#FFFFFF` | Thẻ, danh sách, sheet, ô nhập |
| `surfaceSunken` | `#E9EDEF` | Rãnh segmented, skeleton, nút vô hiệu, khung ảnh chờ |
| `line` | `#D5DCE0` | Đường chia, viền thẻ |
| `lineControl` | `#7F8C93` | Viền ô nhập, nút secondary, tay kéo sheet |
| `ink` | `#12191C` | Chữ chính, nền toast, chip đang chọn |
| `ink2` | `#3F4B52` | Chữ phụ, nhãn ô nhập |
| `muted` | `#5E6B72` | Chú thích, thời gian, placeholder |
| `brand` | `#0E5A6B` | Xanh dầu: nút chính, tab đang chọn, liên kết, focus |
| `brandPress` | `#0A4552` | Nút chính khi nhấn |
| `brandTint` | `#E1EEF1` | Nền thông tin, ô tab đang chọn, nhãn AI, dải "Dữ liệu mẫu" |
| `onBrand` | `#FFFFFF` | Chữ trên brand |
| `kraft` | `#A8743F` | Khối màu hàng đang giữ (thanh tồn kho). Không làm màu chữ |
| `kraftTint` / `kraftInk` | `#F3E8DC` / `#8A5A2B` | Nhãn liên quan kho/đóng gói |
| `success` / `successTint` | `#1F7A3F` / `#E5F3E9` | Hoàn tất, kết nối tốt |
| `warning` / `warningTint` | `#A65A00` / `#FDF1DC` | Chờ xử lý, sắp hết hàng |
| `danger` / `dangerTint` | `#B42318` / `#FCE8E6` | Lỗi, trả hàng, hết hàng, khóa |
| `onDanger` | `#FFFFFF` | Chữ trên danger |
| `shopee` | `#EE4D2D` | Chỉ ô vuông 10px cạnh chữ "Shopee" |
| `tiktok` | `#111111` | Chỉ ô vuông 10px cạnh chữ "TikTok Shop" |
| `scrim` | `#6612191C` | Lớp phủ sau sheet/dialog, không blur |
| `tierStandardBg` / `Ink` | `#E9EDEF` (+ viền `line`) / `#3F4B52` | Hạng Standard |
| `tierSilverBg` / `Ink` | `#C9D2D7` / `#12191C` | Hạng Silver |
| `tierPlatinumBg` / `Ink` | `#4A565C` / `#FFFFFF` | Hạng Platinum |
| `tierDiamondBg` / `Ink` | `#12191C` / `#FFFFFF` | Hạng Diamond |

`ColorScheme`: primary = brand, onPrimary = trắng, primaryContainer = brandTint, surface = surface, onSurface = ink, onSurfaceVariant = ink2, outline = lineControl, outlineVariant = line, error = danger. `scaffoldBackgroundColor` = ground.

**Trạng thái không bao giờ chỉ nói bằng màu**: luôn có chữ đi kèm.

## 3. Chữ (gói `google_fonts`)

| Họ | Dùng cho |
|---|---|
| **Archivo** 700, `FontVariation('wdth', 112)` | Tiêu đề màn, số lớn |
| **IBM Plex Sans** | Toàn bộ nội dung, điều khiển |
| **IBM Plex Mono** + `FontFeature.tabularFigures()` | Mã SKU, mã đơn, tiền, số lượng |

| Style | Họ | Cỡ/dòng | Đậm | TextTheme |
|---|---|---|---|---|
| display | Archivo | 32/36 | 700 | headlineMedium |
| title-lg | Archivo | 24/30 | 700 | titleLarge (tiêu đề tab gốc) |
| title-md | Archivo | 18/24 | 700 | titleMedium (app bar màn con, tiêu đề sheet) |
| body-lg | Plex Sans | 16/24 | 400 | bodyLarge |
| body | Plex Sans | 15/22 | 400 | bodyMedium (mặc định) |
| body-strong | Plex Sans | 15/22 | 600 | tiêu đề hàng danh sách, nhãn nút |
| label | Plex Sans | 13/18 | 600 | labelLarge (nhãn ô nhập, chip) |
| caption | Plex Sans | 12/16 | 400 | bodySmall |
| code | Plex Mono | 13/18 | 500, +0.02em | `SoText.code` |
| numeral | Plex Mono | 15/20 | 500 | `SoText.numeral` |
| overline | Plex Mono | 11/14 | 600, +0.08em, VIẾT HOA | `SoText.overline` |

`code`, `numeral`, `overline` đặt trong `ThemeExtension<SoText>`. Không dùng cỡ chữ ngoài thang này.

## 4. Khoảng cách, bo góc, kích thước

- Lưới 4px. `space` 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40.
- Lề màn 16. Trong thẻ: ngang 16, dọc 12. Giữa các nhóm 24, mỗi nhóm có tiêu đề `overline`. Giữa thẻ cùng nhóm 12.
- Bo: `xs` 4 (nhãn, CodeTag) · `sm` 8 (nút, ô nhập, chip) · `md` 12 (thẻ, nhóm danh sách) · `lg` 16 (hai góc trên của sheet). Chỉ switch được bo tròn.
- Vùng chạm ≥ 48. AppBar 56. BottomNav 64. Nút/ô nhập 48, nút nhỏ/chip 36.
- Bóng: chỉ bottom sheet (`0 -6 24 #12191C1F`) và toast (`0 2 8 #12191C1A`).
- Icon: nét 1.75px, cỡ 24, gói `lucide_icons_flutter`. Không trộn icon đặc.

## 5. Thành phần (mỗi cái là một widget `So…` trong `lib/core/design/`)

| Widget | Mô tả ngắn |
|---|---|
| `SoButton` | primary (brand) / secondary (viền lineControl) / ghost / danger; cao 48 hoặc 36; disabled = surfaceSunken + muted |
| `SoTextField` | nhãn trên, viền 1px lineControl, focus 2px brand, lỗi 2px danger + help đỏ; biến thể mono |
| `SoFilterChip` | cao 36, viền line; đang chọn = nền ink chữ trắng; có số đếm mono |
| `SoSegmented` | rãnh surfaceSunken, mục chọn nền trắng viền line |
| `SoStatusTag` | cao 24, bo 4, ô vuông 8px cùng màu chữ + chữ 12/600; nhận `SoStatus` |
| `SoTierBadge` | cao 24 (bản lớn 32), chữ overline viết hoa; nhận `LoyaltyTier` |
| `SoChannelTag` | ô vuông 10px màu sàn + chữ "Shopee"/"TikTok Shop" màu ink |
| `SoCodeTag` | khung viền 1px ink, bo 4, chữ mono 12 — cho mã đơn, SKU |
| `SoAiLabel` | chữ mono "AI" trên brandTint |
| `SoStatTile` | thẻ: overline + số Archivo 28/32 + ghi chú (warning khi cần chú ý) |
| `SoStockMeter` | thanh 10px: phần giữ chỗ kraft + phần có thể bán brand + chú giải 3 cột số mono |
| `SoOrderRow` | lưới 2 cột: [kênh + mã đơn | giá] [sản phẩm (cắt …) | StatusTag] [khách · giờ] |
| `SoAppBar` | nền surface, viền dưới line; tab gốc: tiêu đề title-lg + dòng phụ mono; màn con: nút back + title-md |
| `SoBottomNav` | 5 mục (Merchant), ô chọn 56×28 bo 8 nền brandTint, chữ 11 |
| `SoBottomSheet` | bo trên 16, tay kéo 36×4, tiêu đề title-md, nút dưới: phụ 1 phần + chính 2 phần |
| `SoBanner` | info / warning / danger: icon + tiêu đề + mô tả (chữ ink) + liên kết hành động gạch chân |
| `SoToast` | nền ink, chữ trắng, nút hành động brandTint |
| `SoEmptyState` | ô icon 56 bo 8 + tiêu đề title-md + mô tả + nút; biến thể lỗi: ô danger-tint |
| `SoSkeleton` | khối surfaceSunken cùng hình nội dung, không vòng xoay giữa màn |
| `SoMockBanner` | dải brandTint dưới AppBar: nhãn mono "DỮ LIỆU MẪU" + một câu |
| `SoTimeline` | nút vuông 12px: xong = brand đặc, hiện tại = viền brand, chưa = viền lineControl |

## 6. Ánh xạ nghiệp vụ → giao diện

**Trạng thái đơn → `SoStatus`:**

| Backend | Chữ | SoStatus |
|---|---|---|
| PENDING | Chờ xử lý | warning |
| TO_SHIP | Chờ giao | kraft |
| SHIPPED | Đã giao cho ĐVVC | info |
| DELIVERING | Đang giao | info |
| COMPLETED | Hoàn tất | success |
| CANCELLED | Đã hủy | neutral |
| RETURNED | Trả hàng | danger |

**Hạng khách:** Standard < 500 · Silver ≥ 500 · Platinum ≥ 1.000 · Diamond ≥ 1.500 (màu ở mục 2).

**Tồn kho:** có thể bán = tồn − giữ chỗ. Hết hàng (≤ 0) → danger "Hết hàng"; sắp hết (≤ 5) → warning "Sắp hết".

**Tiền:** `318.000 ₫` (mono). Số lớn trên ô chỉ số rút gọn `3,87 tr`.

## 7. Bố cục

- Khung chính 428×926 (iPhone 14 Plus); phải ổn ở bề rộng **360dp**: không cắt chữ, không tràn ngang.
- Màn gốc có BottomNav: **Tổng quan · Đơn hàng · Sản phẩm · Tồn kho · Thêm**. Màn con không có BottomNav; nút chính nằm ở **thanh hành động dưới** (tối đa 2 nút: phụ 1 phần, chính 2 phần).
- Thao tác nhanh (hoàn/trả, đặt lại tồn) dùng **bottom sheet**, không dùng dialog giữa màn.
- Nút thêm sản phẩm là icon "+" trên AppBar (không FAB).
- Mỗi màn có dữ liệu: skeleton → có dữ liệu / rỗng / lỗi + "Thử lại".

## 8. Màn đợt 1 (Merchant) — tóm tắt từ mockup

| Mã | Nội dung chính |
|---|---|
| A-02 | Logo ngang (mark + "Smart" ink + "Omni" brand), tiêu đề "Đăng nhập", phụ đề "Một tài khoản cho khách hàng, nhân viên và chủ cửa hàng.", Email, Mật khẩu (nút hiện/ẩn), "Quên mật khẩu?" căn phải, nút "Đăng nhập" full. Bản dev: thẻ tài khoản demo (CodeTag). |
| A-02 lỗi | Sai mật khẩu: viền đỏ + "Email hoặc mật khẩu không đúng." · Khóa 15 phút: Banner warning + link "Đặt lại mật khẩu", nút vô hiệu · Tenant khóa: Banner danger · Super Admin: Banner info "Tài khoản này dùng trên web" + nút phụ "Dùng tài khoản khác". |
| A-03 | AppBar con "Quên mật khẩu", mô tả, ô Email, sau khi gửi: Banner info "Kiểm tra hộp thư" + link "Tôi đã có mã". Nút dưới "Gửi mã đặt lại". |
| A-04 | Mã đặt lại (mono), Mật khẩu mới (≥ 8), Nhập lại; Banner danger khi mã hết hạn + "Gửi lại mã". Nút dưới "Lưu mật khẩu mới". |
| M-10 Staff | Tiêu đề "Việc hôm nay" + dòng phụ "Shop Demo · Nhân viên"; 4 ô: Đơn hôm nay, Chờ xử lý, Chờ giao, SKU sắp hết (**không doanh thu**); nhóm "Đơn cần xử lý" (3 OrderRow + "Xem tất cả"); nhóm "Cảnh báo AI". |
| M-10 Admin | "Tổng quan cửa hàng"; ô Doanh thu hôm nay thay ô Chờ giao; thẻ "Doanh thu theo kênh" (thanh ngang brand + %); "Doanh thu 7 ngày" (7 cột, hôm nay brand, còn lại brandTint); Cảnh báo AI. |
| M-20 | Tiêu đề "Đơn hàng" + nút tìm; hàng chip 8 lọc (Tất cả + 7 trạng thái, có số đếm) cuộn ngang trên nền trắng; danh sách OrderRow theo nhóm. |
| M-21 | AppBar con "Chi tiết đơn" + mã đơn mono; Banner warning khi PENDING; thẻ đầu (kênh, CodeTag, StatusTag, thời gian, tổng tiền Archivo); Sản phẩm (ảnh 48, tên, biến thể, CodeTag SKU, số lượng × giá); Khách hàng (lưới 2 cột); Tiến trình (Timeline, bước từ sàn ghi "Sàn tự cập nhật"); "In vận đơn PDF" + nhãn "Sắp có". Thanh dưới: "Hoàn/trả" + "Chuẩn bị hàng" (chỉ khi PENDING). |
| M-21 sheet | "Ghi nhận hoàn/trả": kênh + mã + trạng thái; 4 chip lý do (Khách từ chối nhận, Khách yêu cầu trả, Hàng lỗi/hư hỏng, Giao sai hàng); ghi chú bắt buộc; Banner info "Đây là ghi nhận nội bộ…"; Hủy / Ghi nhận. Gửi `reason` = "<lý do chip>: <ghi chú>". |
| M-30 | Tiêu đề + tìm + "+"; dải Dữ liệu mẫu; segmented "Đang bán · n / Đã ẩn · n"; hàng: ảnh 56×70, tên, "n SKU · mã-*", ChannelTag, giá "từ", StatusTag hết/sắp hết. |
| M-40 | Dải Dữ liệu mẫu; thẻ StockMeter toàn kho; chip Tất cả / Cần chú ý / Hết hàng; hàng: tên · biến thể, CodeTag SKU, thanh mini, số có thể bán (màu theo mức) + StatusTag. |
| M-40 sheet | "Đặt lại số tồn": tên + CodeTag; StockMeter hiện tại; ô số mono có nút −/+ ; help "Nhập số đếm được trong kho, không phải số cộng thêm. Sau khi lưu: có thể bán N"; Banner info đồng bộ sàn; Hủy / Lưu số tồn. |
| M-50 | Thẻ hồ sơ (ô chữ cái brand, email, vai trò · cửa hàng, CodeTag tenant); nhóm "Công cụ"; nhóm "Quản trị cửa hàng" (chỉ Admin): Kết nối sàn (trạng thái 2 sàn) + các mục "Sắp có"; Đăng xuất chữ danger. |

## 9. Giọng văn

Ngắn, rõ việc cần làm. Nút nói đúng hành động ("Chuẩn bị hàng", "Lưu số tồn"). Lỗi nói chuyện gì xảy ra và cách sửa. Không dấu chấm than, không "Oops". Tránh thuật ngữ kỹ thuật (webhook, outbox) trên giao diện.
