# Thiết kế giao diện SmartOmni Mobile — bản 2 (Glass)

Tài liệu này là **nguồn chuẩn khi code giao diện**. Nếu skill, plugin hay gợi ý nào khác với file này thì làm theo file này.

- **Bản 2 (Glass)**, viết ngày 19/10/2026, thay cho bản 1 (phong cách kho vận, duyệt ngày 14/10/2026). Luồng, mã màn và nội dung từng màn **giữ nguyên**, chỉ đổi ngôn ngữ hình ảnh: chữ, màu, vật liệu kính, bo góc, bố cục.
- Trạng thái: **bản nháp**, chốt khi người dùng duyệt mockup glass (A-02, M-10 Admin, M-20, C-20). Số đo có thể chỉnh nhẹ sau khi duyệt; khi chỉnh thì sửa ở đây trước rồi mới code.
- Mockup bản 2 (đủ 41 màn, chốt 20/10/2026): https://claude.ai/artifact/WE5CeBwvbjgsRvMcrewpCQ. Mockup bản 1 (chỉ để xem nội dung, **không** lấy phong cách): đợt 1 https://claude.ai/artifact/4JxPGaPHdtxGM7VrQxTnEw · đợt 2 https://claude.ai/artifact/5jYxMTRbbvn9wTmy663nWC
- Logo: `assets/brand/` (SVG một màu xanh dầu, giữ nguyên).

## 1. Ý tưởng

Vật liệu kính kiểu Apple: **khung điều hướng là kính mờ nổi trên nội dung, nội dung là thẻ trắng đặc**. Nền màn sáng có vài mảng màu loang thật mờ phía sau để kính có cái mà nhìn xuyên qua. Bo góc lớn, kiểu "squircle", nhiều khoảng trắng, ít đường kẻ. Cảm giác nhẹ và gọn, nhưng app vẫn là **công cụ làm việc**: đọc nhanh, bấm trúng, số liệu rõ.

Ba nguyên tắc:

1. **Kính cho khung, đặc cho dữ liệu.** Thanh tab, AppBar khi cuộn, bottom sheet, toast và tối đa một thẻ nổi bật mỗi màn là kính. Danh sách đơn, ô nhập, bảng số và đoạn văn dài luôn nằm trên nền trắng đặc.
2. **Màu nằm ở nền và ở hành động.** Màu thương hiệu dùng cho nút chính, mục đang chọn và liên kết. Các mảng màu loang chỉ nằm ở lớp nền. Phần còn lại là trắng và xám lạnh.
3. **Chữ làm thứ bậc.** Tiêu đề lớn kiểu iOS ở màn gốc. Số tiền và số đếm to, dùng chữ số đều cột. Phân tầng thông tin bằng cỡ và độ đậm của chữ, không dùng khung viền.

**Không làm:**
- màu tím, neon, chữ phát sáng;
- emoji;
- nút nổi (FAB). Thêm sản phẩm vẫn là icon "+" trên AppBar;
- thẻ có sọc màu ở cạnh trái;
- gradient trên nút, chữ hay thẻ (gradient chỉ được dùng ở lớp nền `SoAmbientBackground`);
- kính chồng lên kính;
- kính làm nền cho danh sách dài, ô nhập hay đoạn văn;
- chữ `muted` đặt trên kính mỏng;
- bóng đậm hoặc viền sáng chói;
- căn giữa mọi thứ (nội dung căn trái, số căn phải);
- dữ liệu bịa (số sao, đánh giá, thời gian giao).

Chỉ có giao diện sáng ở đợt này, **nhưng mọi màu phải lấy từ token** để sau thêm giao diện tối.

## 2. Token màu → `SoColors`

| Token | Giá trị | Dùng khi |
|---|---|---|
| `ground` | `#EEF3F5` | Nền màn (Scaffold), nằm dưới `SoAmbientBackground` |
| `ambientTeal` · `ambientSky` · `ambientSand` | `#8FD3DB` · `#A9C8F2` · `#F2DDBF` | Ba mảng màu loang của nền. Chỉ dùng trong `SoAmbientBackground` |
| `surface` | `#FFFFFF` | Thẻ đặc, nhóm danh sách, ô nhập |
| `fill` | `#0B2A33` α 6% | Nền chip chưa chọn, `SoCodeTag`, rãnh segmented, skeleton |
| `fillStrong` | `#0B2A33` α 10% | Nút vô hiệu, tay kéo sheet, đường chia |
| `glassThin` | `#FFFFFF` α 58% | Kính mỏng: AppBar khi cuộn, toast |
| `glassRegular` | `#FFFFFF` α 72% | Kính thường: thanh tab nổi, thẻ nổi bật |
| `glassThick` | `#FFFFFF` α 86% | Kính dày: bottom sheet |
| `glassStroke` | `#FFFFFF` α 70% | Viền trong 1px của mọi tấm kính, đậm hơn ở mép trên |
| `ink` | `#0B1A1F` | Chữ chính |
| `ink2` | `#44555C` | Chữ phụ, nhãn ô nhập |
| `muted` | `#5F7078` | Chú thích, thời gian, placeholder. Chỉ đặt trên nền đặc hoặc kính dày |
| `brand` | `#0F6E80` | Xanh dầu: nút chính, tab đang chọn, liên kết, focus |
| `brandPress` | `#0E5A6B` | Nút chính khi nhấn; màu của logo |
| `brandTint` | `#E2F1F3` | Nền thông tin, nhãn AI, dải "Dữ liệu mẫu" |
| `onBrand` | `#FFFFFF` | Chữ trên brand |
| `info` / `infoTint` | `#1F64C8` / `#E4EEFC` | Đơn đang vận chuyển |
| `success` / `successTint` | `#1E7B45` / `#E3F4EA` | Hoàn tất, kết nối tốt |
| `warning` / `warningTint` | `#9A5B00` / `#FDF0DA` | Chờ xử lý, sắp hết hàng |
| `danger` / `dangerTint` | `#C4321F` / `#FDE8E5` | Lỗi, trả hàng, hết hàng, khóa |
| `onDanger` | `#FFFFFF` | Chữ trên danger |
| `held` | `#C48A3A` | Phần hàng đang giữ chỗ trên thanh tồn kho (thay `kraft`). Không dùng làm màu chữ |
| `shopee` | `#EE4D2D` | Chỉ dùng cho chấm tròn 8px cạnh chữ "Shopee" |
| `tiktok` | `#111111` | Chỉ dùng cho chấm tròn 8px cạnh chữ "TikTok Shop" |
| `scrim` | `#0B1A1F` α 28% | Lớp phủ sau sheet, kèm làm mờ nền 8 |
| `shadowTint` | `#0B2A33` | Màu gốc của mọi bóng (mục 4) |
| `tierStandardBg` / `Ink` | `#E7ECEE` / `#44555C` | Hạng Standard |
| `tierSilverBg` / `Ink` | `#D4DCE1` / `#0B1A1F` | Hạng Silver |
| `tierPlatinumBg` / `Ink` | `#3E4E55` / `#FFFFFF` | Hạng Platinum |
| `tierDiamondBg` / `Ink` | `#0B1A1F` / `#FFFFFF` | Hạng Diamond |

Bỏ khỏi bản 1: `kraft`, `kraftTint`, `kraftInk`, `line`, `lineControl`, `surfaceSunken`. Viền và đường chia giờ dùng `fillStrong`; ô nhập không còn viền xám đậm (xem `SoTextField`).

`ColorScheme`: primary = brand, onPrimary = trắng, primaryContainer = brandTint, surface = surface, onSurface = ink, onSurfaceVariant = ink2, outline = fillStrong, outlineVariant = fill, error = danger. `scaffoldBackgroundColor` = ground.

Độ tương phản đã kiểm trên nền trắng: ink, ink2, muted, brand và các màu trạng thái đều ≥ 4,5:1. Trên kính, chữ chỉ dùng `ink` hoặc `ink2`.

**Trạng thái không bao giờ chỉ thể hiện bằng màu**: luôn có chữ đi kèm.

## 3. Chữ (gói `google_fonts`)

| Họ | Dùng cho |
|---|---|
| **Inter**, bật `FontFeature.tabularFigures()` cho số | Mọi chữ: tiêu đề, nội dung, điều khiển, số tiền |
| **JetBrains Mono** 500 | Chỉ mã đơn, mã SKU, mã cửa hàng, App Key |

Inter có đủ dấu tiếng Việt và dáng gần SF Pro, nên Android và iOS trông giống nhau. Bỏ Archivo và IBM Plex.

| Style | Cỡ/dòng (sp) | Đậm | Chữ giãn | Ánh xạ |
|---|---|---|---|---|
| largeTitle | 34/40 | 700 | −0.4 | headlineLarge, tiêu đề màn gốc |
| title1 | 28/34 | 700 | −0.3 | headlineMedium |
| title2 | 22/28 | 700 | −0.2 | titleLarge, tiêu đề sheet |
| title3 | 20/26 | 600 | −0.1 | tiêu đề nhóm (section) |
| headline | 17/22 | 600 | 0 | titleMedium: tiêu đề AppBar màn con, tiêu đề hàng, nhãn nút |
| body | 16/22 | 400 | 0 | bodyLarge (mặc định) |
| callout | 15/20 | 400 | 0 | bodyMedium |
| subhead | 14/20 | 500 | 0 | labelLarge: nhãn ô nhập, chip |
| footnote | 13/18 | 400 | 0 | bodySmall |
| caption | 12/16 | 500 | 0 | labelSmall: chữ dưới icon thanh tab, nhãn trạng thái |
| `SoText.metric` | 34/40 | 700, số đều | −0.6 | Số lớn: điểm, doanh thu |
| `SoText.metricSm` | 22/28 | 600, số đều | −0.2 | Số trên ô chỉ số |
| `SoText.money` | 16/22 | 600, số đều | 0 | Giá trong hàng danh sách |
| `SoText.code` | 13/18 | JetBrains Mono 500 | 0 | Mã đơn, SKU |

Ba style `metric`, `metricSm`, `money` và `code` đặt trong `ThemeExtension<SoText>`. Không dùng cỡ chữ ngoài thang này. Không viết hoa cả dòng. Tiêu đề nhóm dùng `title3` viết hoa chữ đầu (thay cho `overline` mono viết hoa của bản 1).

## 4. Khoảng cách, hình dáng, bóng, chuyển động

- **Lưới 4px.** `space` 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40.
- **Lề:** lề màn 16; trong thẻ 16; giữa các nhóm 28; giữa các thẻ cùng nhóm 12; giữa tiêu đề nhóm và thẻ 10.
- **Hình dáng:** dùng `RoundedSuperellipseBorder` (góc squircle kiểu Apple) cho thẻ, nút và sheet. Mức bo:
  - `capsule` (tròn hết): chip, nhãn trạng thái, nút, thanh tab nổi
  - `sm` 10: `SoCodeTag`, ảnh nhỏ
  - `md` 14: ô nhập, ô icon
  - `lg` 22: thẻ, nhóm danh sách
  - `xl` 28: hai góc trên của sheet
- **Kích thước:** vùng chạm ≥ 48; nút 50 (nút nhỏ 36); ô nhập 52; chip 34; AppBar màn con 52; thanh tab nổi cao 64.
- **Bóng** (màu `shadowTint`):
  - thẻ đặc: `0 1 2 α4%` + `0 6 20 α6%`
  - kính: `0 8 32 α12%`
  - Không dùng bóng nào khác.
- **Icon:** gói `lucide_icons_flutter`, nét 1.75, cỡ 24 (22 trên thanh tab). Không trộn icon đặc.
- **Chuyển động:** dạng lò xo, 250–350 ms (`Curves.easeOutCubic` hoặc spring). Khi nhấn, thẻ và nút thu nhỏ còn 0.97. Tiêu đề lớn thu về AppBar khi cuộn. Nếu `MediaQuery.disableAnimations` bật thì chỉ dùng mờ dần (fade).

### Vật liệu kính (`SoGlass`)

- Một tấm kính gồm: `ClipRSuperellipse` + `BackdropFilter(blur σ)` + màu `glass*` + viền trong `glassStroke` 1px + bóng kính.
- Độ mờ σ: thin 20 · regular 28 · thick 36.
- **Ở đâu:**
  - thanh tab nổi;
  - AppBar (trong suốt khi ở đầu trang, chuyển sang kính mỏng khi nội dung cuộn xuống dưới);
  - bottom sheet;
  - toast;
  - tối đa **một** thẻ nổi bật mỗi màn: thẻ hạng (C-20), ô doanh thu (M-10 Admin).
- **Hiệu năng:** tối đa 3 vùng blur cùng lúc trên màn. AppBar và thanh tab dùng chung một `BackdropGroup`, mỗi cái là `BackdropFilter.grouped`. Lớp nền đặt trong `RepaintBoundary`, không chạy hiệu ứng động.
- **Dự phòng:** `glassEnabledProvider` (Riverpod) trả `false` khi `MediaQuery.highContrastOf(context)` bật, hoặc khi người dùng tắt ở cài đặt (sau này). Khi `false`, `SoGlass` vẽ nền `surface` đặc, giữ nguyên bóng và bo góc. Màn gallery bản dev có công tắc để thử cả hai.
- **Android:** vẫn giữ nút Back hệ thống và predictive back, tràn màn (edge-to-edge) với inset đúng. Hai nền tảng dùng chung một giao diện.

## 5. Thành phần (mỗi cái là một widget `So…` trong `lib/core/design/`)

Giữ nguyên tên và tham số của bản 1 để màn hình không phải sửa nhiều; chỉ đổi cách vẽ.

| Widget | Mô tả |
|---|---|
| `SoAmbientBackground` | **Mới.** Nền `ground` + 3 mảng màu loang làm mờ (teal góc trên trái, sky góc trên phải, sand phía dưới). Cố định, không cuộn theo nội dung. Khu Customer có thể thay mảng teal bằng màu thương hiệu của cửa hàng |
| `SoGlass` | **Mới.** Tấm kính (thin / regular / thick), xem mục 4 |
| `SoButton` | primary (nền brand, chữ trắng, capsule 50) / secondary (nền `fill`, chữ ink) / ghost (chữ brand) / danger (nền danger). Vô hiệu: nền `fillStrong`, chữ muted. Khi nhấn: thu nhỏ 0.97 |
| `SoTextField` | Nhãn `subhead` ở trên; ô nền `surface`, bo `md`, viền 1px `fillStrong`; focus: viền 2px brand; lỗi: viền 2px danger + dòng help đỏ. Có biến thể mono (JetBrains Mono) |
| `SoFilterChip` | Capsule 34. Chưa chọn: nền `fill`, chữ ink2. Đang chọn: nền ink, chữ trắng. Số đếm cùng dòng, độ đậm 400 |
| `SoSegmented` | Rãnh capsule nền `fill`; mục đang chọn là viên trắng có bóng thẻ, chuyển bằng lò xo |
| `SoStatusTag` | Capsule cao 24, nền `*Tint`, chấm tròn 6px + chữ `caption` cùng màu trạng thái |
| `SoTierBadge` | Capsule cao 24 (bản lớn 32), chữ `caption` 600 viết hoa chữ đầu, màu theo hạng (mục 2) |
| `SoChannelTag` | Chấm tròn 8px màu sàn + chữ "Shopee"/"TikTok Shop" `footnote` màu ink2 |
| `SoCodeTag` | Nền `fill`, bo `sm`, chữ `code`, không viền |
| `SoAiLabel` | Capsule nền brandTint, chữ "AI" `caption` 600 màu brand |
| `SoStatTile` | Thẻ đặc bo `lg`: nhãn `footnote` ink2 + số `metricSm` + ghi chú (warning khi cần chú ý). Ô nổi bật dùng `SoGlass` regular |
| `SoStockMeter` | Thanh capsule cao 8: phần giữ chỗ `held` + phần có thể bán brand trên rãnh `fill`; chú giải 3 cột số `money` |
| `SoOrderRow` | Hàng trong nhóm thẻ trắng: dòng 1 [kênh + mã đơn · giá `money`]; dòng 2 [sản phẩm (cắt …) · StatusTag]; dòng 3 [khách · giờ `footnote` muted]. Giữa các hàng là đường chia `fillStrong` thụt vào 16 |
| `SoAppBar` | Màn gốc: tiêu đề lớn `largeTitle` + dòng phụ `footnote`, khi cuộn thu thành thanh kính mỏng 52 với tiêu đề `headline` ở giữa. Màn con: nút back tròn 36 nền `fill` + tiêu đề `headline` |
| `SoScaffold` | Khung mọi màn: `SoAmbientBackground` + `CustomScrollView`, `SoAppBar` ghim ở đầu (sliver), nội dung luôn bắt đầu dưới thanh. Tự chừa lề cuối: trên thanh tab = 64 + 12 + vùng an toàn + 16; trên `SoActionBar` = 16. Màn mới **không** tự dựng Scaffold/ListView |
| `SoBottomNav` | Thanh kính regular **nổi**, capsule, cách mép trái/phải 16 và mép dưới 12 (cộng thêm safe area). 5 mục (Merchant) hoặc 4 mục (Customer). Mục đang chọn: viên `brandTint` phía sau icon, icon + chữ màu brand; mục khác màu ink2 |
| `SoBottomSheet` | Kính thick, bo trên `xl`, tay kéo 36×5 `fillStrong`, tiêu đề `title2`. Nút dưới: phụ 1 phần + chính 2 phần. Phía sau là scrim có làm mờ |
| `SoBanner` | Thẻ bo `lg` nền `*Tint`: icon + tiêu đề `headline` + mô tả `callout` ink + liên kết hành động màu trạng thái |
| `SoToast` | Kính thin capsule nổi phía trên thanh tab, chữ ink, nút hành động màu brand |
| `SoEmptyState` | Ô icon 64 bo `md` nền `fill` + tiêu đề `title3` + mô tả `callout` ink2 + nút. Biến thể lỗi: ô icon nền dangerTint |
| `SoSkeleton` | Khối `fill` cùng hình với nội dung, ánh sáng quét chậm 1,2 s (tắt khi giảm chuyển động). Không dùng vòng xoay giữa màn |
| `SoMockBanner` | Capsule nền brandTint dưới AppBar: nhãn "Dữ liệu mẫu" 600 + một câu |
| `SoTimeline` | Chấm tròn 12px: xong = brand đặc, hiện tại = vòng brand 2px, chưa = vòng `fillStrong`; đường nối 2px |

## 6. Ánh xạ nghiệp vụ → giao diện

**Trạng thái đơn → `SoStatus`:**

| Backend | Chữ | SoStatus |
|---|---|---|
| PENDING | Chờ xử lý | warning |
| TO_SHIP | Chờ giao | brand |
| SHIPPED | Đã giao cho ĐVVC | info |
| DELIVERING | Đang giao | info |
| COMPLETED | Hoàn tất | success |
| CANCELLED | Đã hủy | neutral (nền `fill`, chữ ink2) |
| RETURNED | Trả hàng | danger |

`SoStatus.kraft` của bản 1 đổi thành `SoStatus.brand`.

**Hạng khách:** Standard < 500 · Silver ≥ 500 · Platinum ≥ 1.000 · Diamond ≥ 1.500 (màu ở mục 2).

**Tồn kho:** có thể bán = tồn − giữ chỗ. Hết hàng (≤ 0) → danger "Hết hàng"; sắp hết (≤ 5) → warning "Sắp hết".

**Tiền:** viết `318.000 ₫` bằng `SoText.money`. Số lớn trên ô chỉ số rút gọn thành `3,87 tr`.

## 7. Bố cục

- Khung chính 428×926 (iPhone 14 Plus). Phải ổn ở bề rộng **360dp**: không cắt chữ, không tràn ngang.
- Mọi màn đặt trên `SoAmbientBackground`. Nội dung cuộn bên dưới AppBar kính và thanh tab nổi. Cuối danh sách chừa khoảng trống bằng chiều cao thanh tab + 24 để mục cuối không bị che.
- **Màn gốc** có thanh tab:
  - Merchant: **Tổng quan · Đơn hàng · Sản phẩm · Tồn kho · Thêm**
  - Customer: **Sản phẩm · Điểm & hạng · Claim đơn · Tài khoản**
- **Màn con** không có thanh tab. Nút chính nằm ở **thanh hành động kính** dưới đáy, tối đa 2 nút: phụ 1 phần, chính 2 phần.
- Thao tác nhanh (hoàn/trả, đặt lại tồn, thêm cửa hàng) dùng **bottom sheet**, không dùng dialog giữa màn.
- Nút thêm sản phẩm là icon "+" trên AppBar (không dùng FAB).
- Mỗi màn có dữ liệu đi theo thứ tự: skeleton → có dữ liệu / rỗng / lỗi + nút "Thử lại".

## 8. Màn đợt 1 (Merchant): nội dung giữ như bản 1

Nội dung, thứ tự và chữ của mỗi màn giữ nguyên. Cách vẽ theo mục 4–5: số lớn dùng `metric`/`metricSm` thay cho Archivo; tiêu đề nhóm dùng `title3` thay cho overline.

| Mã | Nội dung chính |
|---|---|
| A-02 | Logo ngang (mark + "Smart" ink + "Omni" brand), tiêu đề "Đăng nhập", phụ đề "Một tài khoản cho khách hàng, nhân viên và chủ cửa hàng.". Có ô Email, ô Mật khẩu (nút hiện/ẩn), "Quên mật khẩu?" căn phải, nút "Đăng nhập" full. Form đặt trong thẻ đặc trên nền loang. Bản dev: thẻ tài khoản demo (CodeTag). |
| A-02 lỗi | Sai mật khẩu: viền đỏ + "Email hoặc mật khẩu không đúng.". Khóa 15 phút: Banner warning + link "Đặt lại mật khẩu", nút vô hiệu. Tenant khóa: Banner danger. Super Admin: Banner info "Tài khoản này dùng trên web" + nút phụ "Dùng tài khoản khác". |
| A-03 | AppBar con "Quên mật khẩu", mô tả, ô Email. Sau khi gửi: Banner info "Kiểm tra hộp thư" + link "Tôi đã có mã". Nút dưới "Gửi mã đặt lại". |
| A-04 | Mã đặt lại (mono), Mật khẩu mới (≥ 8), Nhập lại. Banner danger khi mã hết hạn + "Gửi lại mã". Nút dưới "Lưu mật khẩu mới". |
| M-10 Staff | Tiêu đề "Việc hôm nay" + dòng phụ "Shop Demo · Nhân viên". 4 ô: Đơn hôm nay, Chờ xử lý, Chờ giao, SKU sắp hết (**không có doanh thu**). Nhóm "Đơn cần xử lý" (3 OrderRow + "Xem tất cả"). Nhóm "Cảnh báo AI". |
| M-10 Admin | "Tổng quan cửa hàng". Ô Doanh thu hôm nay thay ô Chờ giao; đây là thẻ kính nổi bật duy nhất của màn. Thẻ "Doanh thu theo kênh" (thanh capsule brand + %). Thẻ "Doanh thu 7 ngày" (7 cột bo tròn: hôm nay brand, các ngày khác brandTint). Cảnh báo AI. |
| M-20 | Tiêu đề lớn "Đơn hàng" + nút tìm. Hàng chip 8 lọc (Tất cả + 7 trạng thái, có số đếm) cuộn ngang, dính dưới AppBar khi cuộn. Danh sách OrderRow chia nhóm theo ngày, mỗi nhóm một thẻ trắng. |
| M-21 | AppBar con "Chi tiết đơn" + mã đơn mono. Banner warning khi PENDING. Thẻ đầu: kênh, CodeTag, StatusTag, thời gian, tổng tiền `metric`. Thẻ Sản phẩm: ảnh 48, tên, biến thể, CodeTag SKU, số lượng × giá. Thẻ Khách hàng: lưới 2 cột. Thẻ Tiến trình: Timeline; bước do sàn cập nhật ghi "Sàn tự cập nhật". Hàng "In vận đơn" → M-22 (mờ khi PENDING, ẩn khi Hoàn tất / Đã hủy / Trả hàng). Thanh dưới: "Hoàn/trả" + "Chuẩn bị hàng" (chỉ khi PENDING). |
| M-21 sheet | "Ghi nhận hoàn/trả": kênh + mã + trạng thái; 4 chip lý do (Khách từ chối nhận, Khách yêu cầu trả, Hàng lỗi/hư hỏng, Giao sai hàng); ghi chú bắt buộc; Banner info "Đây là ghi nhận nội bộ…"; nút Hủy / Ghi nhận. Gửi `reason` = "<lý do chip>: <ghi chú>". |
| M-30 | Tiêu đề + tìm + "+". Dải Dữ liệu mẫu. Segmented "Đang bán · n / Đã ẩn · n". Mỗi hàng: ảnh 56×70 bo `sm`, tên, "n SKU · mã-*", ChannelTag, giá "từ", StatusTag hết/sắp hết. |
| M-40 | Dải Dữ liệu mẫu. Thẻ StockMeter toàn kho. Chip Tất cả / Cần chú ý / Hết hàng. Mỗi hàng: tên · biến thể, CodeTag SKU, thanh mini, số có thể bán (màu theo mức) + StatusTag. |
| M-40 sheet | "Đặt lại số tồn": tên + CodeTag; StockMeter hiện tại; ô số mono có nút −/+; help "Nhập số đếm được trong kho, không phải số cộng thêm. Sau khi lưu: có thể bán N"; Banner info đồng bộ sàn; nút Hủy / Lưu số tồn. |
| M-50 | Thẻ hồ sơ (ô chữ cái brand, email, vai trò · cửa hàng, CodeTag tenant). Nhóm "Công cụ". Nhóm "Quản trị cửa hàng" (chỉ Admin): Kết nối sàn (trạng thái 2 sàn) + các mục "Sắp có". Đăng xuất chữ danger. |

Bổ sung ngày 20/10: A-02 có thêm dòng "Khách mua hàng chưa có tài khoản? **Đăng ký**" dưới nút Đăng nhập, dẫn tới A-05.

## 8b. Các màn còn lại (mockup glass 20/10/2026)

Mockup đầy đủ 41 màn: https://claude.ai/artifact/WE5CeBwvbjgsRvMcrewpCQ (6 hàng theo luồng). Bảng dưới là **nội dung chốt**; chỉ làm đúng những gì ghi ở đây, không thêm tính năng ngoài `docs/USER_FLOWS.md`. Màn chưa có API hiện `SoMockBanner`.

**Quy ước chung:** màn con dùng AppBar con (nút back tròn + tiêu đề `headline`, dòng phụ mono nếu có mã); nút chính ở thanh hành động kính dưới đáy; sheet dùng `SoBottomSheet` kính dày.

| Mã | Nội dung chính |
|---|---|
| A-01 | Logo trong ô kính bo tròn giữa màn + chữ "SmartOmni"; dưới đáy thanh tải mảnh + "Đang kiểm tra phiên đăng nhập…". |
| A-03 | Banner info sau khi gửi: "Nếu email tồn tại, hướng dẫn đã được gửi. Mã có hiệu lực 30 phút." (không tiết lộ email có tồn tại). |
| A-04 | Banner danger mã hết hạn ghi **30 phút**. |
| M-22 | AppBar con "In vận đơn" + mã đơn. Thẻ trắng xem trước tem PDF do sàn tạo. Thanh dưới: **Chia sẻ PDF** + **In**. Không chọn khổ giấy. |
| M-31 | Như bản đã code (thẻ đầu, nhóm SKU kèm nhãn tồn và lối vào AI, nhóm liên kết sàn + nút chép). |
| M-32 | AppBar con "Sản phẩm mới" (nút đóng). Thẻ 1: Tên*, Mô tả. Nhóm "SKU" (nhãn "Nhiều SKU, ảnh, link sàn · Sắp có"): Mã SKU* (mono), Phân loại, Giá bán*. Thanh dưới: Hủy / **Lưu sản phẩm**. **Không** có ảnh, tồn ban đầu, công tắc sàn. |
| M-50 | Thẻ hồ sơ. Nhóm "Công cụ": Hộp thư CSKH (số chưa đọc), Dự báo nhu cầu (nhãn AI). Nhóm "Quản trị cửa hàng" (chỉ Admin): Kết nối sàn (trạng thái 2 sàn), Nhân viên, Phát voucher, Gói dịch vụ, Yêu cầu hỗ trợ. Đăng xuất (chữ danger). |
| M-51 | AppBar con "Dự báo nhu cầu" + nhãn AI. Thẻ chọn SKU ("Đổi SKU"). Thẻ kính: **Dự kiến bán 7 ngày** và **Nên nhập thêm** (metricSm), "Có thể bán hiện tại". Nhóm "Theo ngày": 7 hàng ngày + số cái. Chú thích "Dự báo chỉ để tham khảo". Không có biểu đồ (để sau). |
| M-60 | Màn con từ M-50 (không có thanh tab). Chip: Tất cả / Khiếu nại / Chưa trả lời / theo sàn. Hàng: chấm chưa đọc, tên khách, giờ, tin cuối (đậm nếu chưa đọc), kênh + nhãn (Khiếu nại danger, Chưa trả lời neutral, Cần kiểm tra warning, Đã giải quyết success). |
| M-61 khiếu nại | AppBar: tên khách + kênh, nút "Đã giải quyết". Banner danger khóa (hạn phản hồi). Thẻ đơn liên quan (mã, trạng thái, sản phẩm) + "Đổi". Tin nhắn: khách trái (thẻ trắng), shop phải (brand); trạng thái tin: "Đã gửi" / "Chưa rõ đã gửi chưa · đối soát trước khi gửi lại". Ô soạn kính + nút ảnh + gửi. |
| M-61 thường | Như trên, không banner. Chưa gắn đơn: thẻ viền nét đứt + nút "Tìm đơn". Nội dung không hỗ trợ: "Không xem được nội dung này". **Không** có trả lời nhanh. |
| M-61 sheet | "Gắn đơn vào hội thoại": ô mã đơn (mono), danh sách `SoOrderRow` cùng sàn, chọn một → Hủy / Gắn đơn. |
| T-10 | Hai thẻ sàn: tên shop, trạng thái, Shop ID, đồng bộ gần nhất, công tắc "Tự nhập sản phẩm & đơn", nút "Ngắt kết nối". Thẻ lỗi: banner danger + **Kết nối lại**. Hàng "Nâng cao: nhập App Key". |
| T-10 OAuth | Sheet: 3 bước, danh sách quyền sẽ được đọc (Đơn hàng, Sản phẩm, Tồn kho, Tin nhắn), công tắc tự nhập, nút "Mở TikTok Shop", link "Nhập App Key thủ công". Chỉ dùng khi backend có OAuth. |
| T-10 xong | Thẻ kính: dấu tích, "Đã kết nối …", Shop ID, tiến độ nhập sản phẩm (x / y), nút Xong. |
| T-10 App Key | Sheet: chọn sàn (segmented), App Key (mono), App Secret (ẩn/hiện), công tắc tự nhập, Hủy / Kết nối. |
| T-20 | Danh sách: chủ cửa hàng (bạn) + Staff (tên, email, trạng thái Đang hoạt động / Đã khóa). Chạm để vô hiệu hóa / kích hoạt lại. Thanh dưới: **Thêm nhân viên** (email + mật khẩu tạm). |
| T-30 | Thẻ form: Phát cho (chip hạng có số khách + "Chọn từng khách"), Sàn (segmented), Giá trị giảm, Đơn tối thiểu, Hạn dùng; ghi chú "chỉ gửi email khi sàn xác nhận tạo thành công". Nhóm "Đợt phát gần đây" với trạng thái Đang tạo / Thành công / Lỗi / Chưa rõ · đối soát. Thanh dưới: "Phát cho N khách …" (chống bấm lặp). |
| T-40 | Thẻ kính gói hiện tại (tên gói, hạn) + mức đã dùng: Số SKU, Kết nối sàn, Dung lượng ảnh (thanh capsule). Nhóm "Hóa đơn" (mã mono, số tiền, Đã/Chưa thanh toán). Hai nút: Đổi gói / Thanh toán. Tên gói, giá, hạn mức chờ backend. |
| T-50 | Segmented "Chưa xong / Đã giải quyết". Hàng ticket: mã mono, thời gian, tiêu đề, dòng cuối; nhãn Mở / Đang xử lý / Đã giải quyết. Thanh dưới: **Tạo yêu cầu** (tiêu đề, mô tả). |
| A-05 | AppBar con "Tạo tài khoản khách". Thẻ 1: Mã cửa hàng (mono) + nút quét QR, kết quả "Đã tìm thấy" (logo tròn + tên). Thẻ 2: Họ tên, Email, SĐT, Mật khẩu (≥ 8). Ô đồng ý điều khoản. Thanh dưới: **Tạo tài khoản** + "Đã có tài khoản? Đăng nhập". |
| A-05 OTP | 6 ô số (mono), "Gửi lại sau 00:45", lỗi "Mã không đúng. Bạn còn N lần thử.", thẻ kính "Bạn sẽ tham gia Shop Demo · Standard". Nút **Xác minh** → C-10. |
| C-00 | Màn con "Cửa hàng của bạn": danh sách cửa hàng (logo tròn, tên, hạng, điểm), mục đang xem viền brand + nhãn "Đang xem"; nút phụ "Thêm cửa hàng". |
| C-00 sheet | "Thêm cửa hàng": mã (mono) + quét QR, thẻ kết quả, lỗi dưới ô; Hủy / Tham gia cửa hàng. |
| SoShopSwitcher | Viên kính mỏng trên đầu C-10/C-20/C-30: logo tròn 32 + tên cửa hàng + mũi tên xuống → C-00. |
| C-10 | Đầu màn: SoShopSwitcher, nút "Hỏi AI" (viên, icon chat) → C-12. Tiêu đề lớn "Sản phẩm". Lưới 2 cột thẻ sản phẩm (ảnh 4:5, tên, giá "từ", kênh). Không FAB, không tìm kiếm/lọc (để sau). |
| C-11 | Ảnh lớn tràn trên + nút back kính; thẻ trắng bo trên 28: tên, khoảng giá, ghi chú giá sàn, chip phân loại, mô tả, banner info điểm dự kiến. Thanh dưới: Mua trên Shopee (primary) / Mua trên TikTok Shop (secondary), chỉ hiện sàn có URL. |
| C-12 | AppBar con "Trợ lý <cửa hàng>" + dòng phụ "Tư vấn sản phẩm · không đặt hàng" + nhãn AI. Bong bóng chat, thẻ sản phẩm bấm được → C-11, câu trả lời dự phòng nền warningTint. Ô soạn kính. Không có câu hỏi gợi ý. |
| C-20 | Như mockup 4 màn mẫu (thẻ hạng kính, voucher, lịch sử điểm). |
| C-30 | SoShopSwitcher, tiêu đề lớn "Claim đơn", thẻ form: Sàn (segmented), Mã đơn (mono) + quét, help; nút **Claim điểm**. Nhóm "Điều kiện" 3 bước. |
| C-30 kết quả | Thẻ kính thành công: +điểm, mã đơn, đã thanh toán, điểm cũ → mới, lên hạng (nếu có); Claim đơn khác / Xem hạng. Lỗi dạng banner: chưa đủ 15 ngày (kèm ngày được claim), đã claim, không tìm thấy, chưa hoàn tất, thử sai quá nhiều lần. |
| C-40 | Thẻ hồ sơ; nhóm "Cửa hàng đã tham gia" (+ Thêm); nhóm "Cài đặt": Sửa thông tin, Đổi mật khẩu (Sắp có), Điều khoản; Đăng xuất. |

## 9. Giọng văn

Ngắn, rõ việc cần làm. Nút nói đúng hành động ("Chuẩn bị hàng", "Lưu số tồn"). Lỗi nói chuyện gì xảy ra và cách sửa. Không dùng dấu chấm than, không "Oops". Tránh thuật ngữ kỹ thuật (webhook, outbox) trên giao diện.

## 10. Chuyển code từ bản 1 sang bản 2 (cho Claude Code)

Làm trong một nhánh riêng `feature/ui-glass-foundation`, **trước** các nhánh màn hình:

1. `so_colors.dart`, `so_tokens.dart`: token mục 2 và mục 4. Bỏ `kraft*`, `line`, `lineControl`, `surfaceSunken`; sửa mọi chỗ đang dùng các token này.
2. `so_text.dart`: Inter + JetBrains Mono theo mục 3. Bỏ Archivo và IBM Plex.
3. `so_theme.dart`: `ColorScheme` mới, `RoundedSuperellipseBorder` cho nút, thẻ và sheet.
4. Thêm `so_glass.dart` (`SoGlass`, `glassEnabledProvider`) và `so_ambient_background.dart`.
5. Vẽ lại các widget ở mục 5, giữ nguyên tên và tham số. `SoBottomNav` chuyển sang dạng nổi; `SoAppBar` thêm tiêu đề lớn thu lại khi cuộn.
6. Màn gallery bản dev: thêm công tắc bật/tắt kính.
7. Test: cập nhật finder/key nếu cần, **không xóa test**. Chạy `dart format lib test` → `flutter analyze` → `flutter test`.
